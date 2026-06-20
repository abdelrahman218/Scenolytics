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

# ── Evaluation Service ──────────────────────────────────────────────────────
# Runs MLPipeline directly on a T4 GPU (SeamlessM4T, WavLM, and WhisperX all
# move to cuda inside MLPipeline -- see core/ml_pipeline.py script_device).
# The old separate SeamlessTranscriber class has been removed: MLPipeline
# loads and runs SeamlessM4T in-process now, so a second remote .method()
# hop is no longer needed.

@app.cls(
    image=image,
    gpu="T4",
    timeout=600,
    memory=16384,
    volumes={MODEL_DIR: model_volume},
    secrets=[modal.Secret.from_name("ai-evaluation-secrets")],
)
class AIEvaluationService:

    @modal.enter()
    async def startup(self):
        import asyncio
        import logging
        from dotenv import load_dotenv
        from core.service import EvaluationService 
        load_dotenv()
        self._EvaluationService = EvaluationService
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("modal-ai-eval")
        
        # DB
        from core.database import init_db
        await init_db()

        # ML
        from core.ml_pipeline import MLPipeline
        from api.routes.evaluation import run_ml_pipeline as run_evaluation_pipeline
        self.run_evaluation_pipeline = run_evaluation_pipeline
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
    async def evaluate(self, evaluation_id: str, event_data: dict[str, any]):
        media_id = event_data.get("media_id") 
        submission_id = event_data.get("id")
        audition = await self._EvaluationService.get_audition_by_id(
                    event_data.get("audition_id")
                )
        audio_only = bool(audition.get("audio_only"))
        pipeline = self.pipeline
        rabbitmq_manager = self.rabbitmq
        if not media_id:
            await self._mark_failed(evaluation_id, "missing video")
            return {"status": "failed"}
        script = await self._EvaluationService.resolve_script_for_submission(
            event_data
        )
        self.logger.info("Script for evaluation: %s", script)
        self.logger.info("audio_only: %s", audio_only)
        try:
            result = await self.run_evaluation_pipeline(
                evaluation_id, media_id, pipeline, script,
                rabbitmq_manager, submission_id, audio_only
            )

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