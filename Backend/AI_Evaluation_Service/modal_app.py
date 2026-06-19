# AI_Evaluation_Service/modal_app.py

import json
import os
import modal

app = modal.App("ai-evaluation-service")

MODEL_DIR = "/app/models"

# ── Image ────────────────────────────────────────────────────────────────────

def _download_models():
    import urllib.request, bz2

    dat_path = f"{MODEL_DIR}/shape_predictor_68_face_landmarks.dat"
    if not os.path.exists(dat_path):
        print("Downloading dlib shape predictor...")
        bz2_path = dat_path + ".bz2"
        urllib.request.urlretrieve(
            "http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2",
            bz2_path,
        )
        with bz2.open(bz2_path) as f_in, open(dat_path, "wb") as f_out:
            f_out.write(f_in.read())
        os.remove(bz2_path)
        print("dlib shape predictor downloaded.")


model_volume = modal.Volume.from_name("scenolytics-models")

image = (
    modal.Image.from_dockerfile("Dockerfile")
    .add_local_dir(
        ".",
        remote_path="/app",
        copy=True,
        ignore=["models", "__pycache__", "*.pyc", ".env",
                "modal_app.py", "*.egg-info"]
    )
    .pip_install(
        "aio-pika",
        "aiomysql",
        "python-dotenv"
    )
    .run_function(
        _download_models,
        volumes={MODEL_DIR: model_volume},
    )
)

# ── GPU Transcriber ─────────────────────────────────────────────────────────

SEAMLESS_MODEL_CANDIDATES = [
    "./models/seamless-m4t-v2-large",
    "/app/models/seamless-m4t-v2-large",
]

@app.cls(
    image=image,
    gpu="T4",
    timeout=300,
    scaledown_window=300,
    volumes={MODEL_DIR: model_volume},
)
class SeamlessTranscriber:

    @modal.enter()
    async def load_model(self):
        from pathlib import Path
        from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor

        model_path = None
        for p in SEAMLESS_MODEL_CANDIDATES:
            if Path(p).exists():
                model_path = p
                break

        if model_path is None:
            self.model = None
            self.processor = None
            return

        self.processor = AutoProcessor.from_pretrained(model_path)
        self.model = AutoModelForSpeechSeq2Seq.from_pretrained(model_path)
        self.model.eval()

        import torch
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model.to(self.device)

    @modal.method()
    async def transcribe(self, waveform_list: list, sampling_rate: int = 16000, tgt_lang: str = "eng"):
        import numpy as np
        import torch

        if self.model is None:
            return ""

        waveform = np.array(waveform_list, dtype=np.float32)

        inputs = self.processor(audio=waveform, sampling_rate=sampling_rate, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}

        with torch.no_grad():
            output = self.model.generate(**inputs, tgt_lang=tgt_lang)

        return self.processor.decode(output[0], skip_special_tokens=True)


# ── Evaluation Service ──────────────────────────────────────────────────────

@app.cls(
    image=image,
    timeout=600,
    memory=16384,
    volumes={MODEL_DIR: model_volume},
)
class AIEvaluationService:

    @modal.enter()
    async def startup(self):
        import asyncio
        import logging
        from dotenv import load_dotenv

        load_dotenv()

        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("modal-ai-eval")

        # DB
        from core.database import init_db
        await init_db()

        # ML
        from core.ml_pipeline import MLPipeline
        self.pipeline = MLPipeline()
        await self.pipeline.initialize()

        # RabbitMQ (publisher only)
        from core.rabbitmq_manager import RabbitMQManager
        self.rabbitmq = RabbitMQManager()

        for i in range(10):
            try:
                await self.rabbitmq.initialize()
                self.logger.info("RabbitMQ connected")
                break
            except Exception as e:
                self.logger.warning("RabbitMQ retry %s: %s", i + 1, e)
                await asyncio.sleep(3)
        else:
            self.rabbitmq = None

    async def _download_video(self, video_key: str):
        import tempfile
        from core.storage import get_s3_client

        s3 = get_s3_client()
        bucket = os.environ["S3_BUCKET_VIDEOS"]

        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
            s3.download_fileobj(bucket, video_key, tmp)
            return tmp.name

    async def _write_results(self, evaluation_id: str, result: dict):
        from core.database import execute_update

        await execute_update(
            """
            UPDATE evaluations
            SET evaluation_status=%s,
                emotional_expression_score=%s,
                vocal_tone_score=%s,
                script_alignment_score=%s,
                overall_performance_score=%s,
                eye_expression_score=%s,
                detected_emotions=%s,
                detected_emotions_vocal=%s,
                script_alignment_details=%s,
                ai_feedback=%s,
                completed_at=NOW()
            WHERE evaluation_id=%s
            """,
            (
                "completed",
                result["emotional_expression_score"],
                result["vocal_tone_score"],
                result["script_alignment_score"],
                result["overall_performance_score"],
                json.dumps(result["eye_expression"]),
                json.dumps(result["detected_emotions"]),
                json.dumps(result["detected_emotions_vocal"]),
                json.dumps(result.get("script_alignment_data")),
                result["ai_feedback"],
                evaluation_id,
            ),
        )

    async def _mark_failed(self, evaluation_id: str, error: str):
        from core.database import execute_update

        await execute_update(
            """
            UPDATE evaluations
            SET evaluation_status=%s, error_message=%s, completed_at=NOW()
            WHERE evaluation_id=%s
            """,
            ("failed", error, evaluation_id),
        )

    @modal.method()
    async def evaluate(self, evaluation_id: str, event_data: dict):
        video_key = event_data.get("video_key") or event_data.get("video_url")
        script_text = event_data.get("script_text") or event_data.get("script")

        if not video_key:
            await self._mark_failed(evaluation_id, "missing video_key")
            return {"status": "failed"}

        try:
            path = await self._download_video(video_key)

            result = await self.pipeline.evaluate_video(path, script_text=script_text)

            await self._write_results(evaluation_id, result)

            if self.rabbitmq:
                await self.rabbitmq.publish_evaluation_completed(
                    evaluation_id,
                    **result
                )

            return {"status": "ok"}

        except Exception as e:
            await self._mark_failed(evaluation_id, str(e))
            return {"status": "failed", "error": str(e)}

    @modal.fastapi_endpoint(method="GET")
    async def health(self):
        return {"status": "ok"}