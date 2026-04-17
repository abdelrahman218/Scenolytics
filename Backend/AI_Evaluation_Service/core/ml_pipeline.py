"""
ML Pipeline for AI Evaluation Service
======================================
Integrates 3 trained models to evaluate audition videos:

  1. Video Emotion Model  → emotional_expression_score (40%)
     - Architecture : ResNet50 + 2-layer Bidirectional LSTM + Attention
     - File         : ./models/best_video_emotion_model.h5
     - Framework    : TensorFlow / Keras

  2. Audio Emotion Model  → vocal_tone_score (35%)
     - Architecture : facebook/wav2vec2-base fine-tuned on RAVDESS
     - Folder       : ./emotion-recognition-final/
     - Framework    : PyTorch / HuggingFace Transformers

  3. Script Alignment     → script_alignment_score (25%)
     - Architecture : WhisperX (large-v2) + word-level difflib comparison
     - Framework    : whisperx

Overall score = emotional_expression * 0.40
              + vocal_tone            * 0.35
              + script_alignment      * 0.25
"""
# Numpy 2.x compatibility shim — must be before ALL other imports
# Numpy compatibility shim — must be before ALL other imports
import numpy as np

# Only patch attributes that are truly missing (numpy 2.x removed these)
_numpy_compat = {
    'NaN': np.nan,
    'Inf': np.inf,
}
for _attr, _val in _numpy_compat.items():
    if not hasattr(np, _attr):
        setattr(np, _attr, _val)

import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"
import re
import json
import logging
import difflib
import subprocess
import tempfile
import tensorflow as tf
from pathlib import Path
from typing import Dict, List, Optional, Tuple


logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Emotion label mapping — shared by both video and audio models
# ---------------------------------------------------------------------------
EMOTIONS = {
    "01": "neutral",
    "02": "calm",
    "03": "happy",
    "04": "sad",
    "05": "angry",
    "06": "fearful",
    "07": "disgust",
    "08": "surprised",
}
EMOTION_NAMES: List[str] = list(EMOTIONS.values())   # index → name
NUM_CLASSES = len(EMOTION_NAMES)                       # 8

# ---------------------------------------------------------------------------
# Video model hyper-parameters (must match training in the notebook)
# ---------------------------------------------------------------------------
FRAMES_PER_VIDEO = 10
IMG_SIZE = 160                                         # 160 × 160 RGB
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD  = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# ---------------------------------------------------------------------------
# Model file locations (edit these paths to match your deployment layout)
# ---------------------------------------------------------------------------
# Models should be placed in ./models/ subdirectory relative to this service
# When deployed in Docker, this resolves to /app/models/
VIDEO_MODEL_CANDIDATES = [
    "./models/best_video_emotion_model.h5",
    "/app/models/best_video_emotion_model.h5",
    "models/best_video_emotion_model.h5",
]

AUDIO_MODEL_CANDIDATES = [
    "./models/emotion-recognition-final",
    "/app/models/emotion-recognition-final",
    "models/emotion-recognition-final",
]

# WhisperX settings
WHISPERX_MODEL_SIZE = "large-v2"
WHISPERX_COMPUTE_TYPE = "int8"          # use "float16" on a powerful GPU


# ===========================================================================
# Helper utilities
# ===========================================================================

def _find_path(candidates: List[str]) -> Optional[Path]:
    """Return the first existing path from a list of candidates."""
    for p in candidates:
        path = Path(p)
        if path.exists():
            return path
    return None


def _extract_audio_ffmpeg(video_path: str, output_wav: str) -> str:
    """
    Use ffmpeg (already in the Docker image) to pull the audio track out of a
    video file and write it as a 16 kHz mono WAV — the format both Whisper and
    the wav2vec2 feature extractor expect.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", str(video_path),
        "-vn",                      # no video
        "-acodec", "pcm_s16le",     # uncompressed PCM
        "-ar", "16000",             # 16 kHz
        "-ac", "1",                 # mono
        str(output_wav),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg failed while extracting audio.\n"
            f"stderr: {result.stderr}\nstdout: {result.stdout}"
        )
    if not Path(output_wav).exists():
        raise ValueError("ffmpeg produced no output file — video may have no audio track.")
    return output_wav


def _normalize_text(text: str) -> str:
    """Lower-case and strip punctuation so script vs transcript comparison is fair."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)   # remove punctuation
    text = re.sub(r"\s+", " ", text).strip()
    return text
@tf.keras.utils.register_keras_serializable(package='Custom')
class SumPooling(tf.keras.layers.Layer):
    def __init__(self, axis=1, **kwargs):
        super().__init__(**kwargs)
        self.axis = axis          # ← store it

    def call(self, inputs):
        return tf.reduce_sum(inputs, axis=self.axis)

    def get_config(self):
        config = super().get_config()
        config.update({"axis": self.axis})   # ← serialize it
        return config
# ===========================================================================
# MLPipeline class
# ===========================================================================

class MLPipeline:
    """
    Main pipeline — load models once at startup, then call evaluate_video()
    for every audition.

    Usage
    -----
    pipeline = MLPipeline()
    await pipeline.initialize()          # loads models into memory
    result = await pipeline.evaluate_video(video_path, script_text=script)
    """

    def __init__(self):
        # ---- Video model (TensorFlow / Keras) ----
        self.emotion_model = None        # tf.keras Model

        # ---- Audio model (PyTorch / HuggingFace) ----
        self.audio_feature_extractor = None
        self.audio_model = None          # AutoModelForAudioClassification
        self.audio_label_mapping = None  # {"id2label": {...}, "label2id": {...}}

        # ---- Script alignment (WhisperX) ----
        self.script_model = None         # whisperx model object

        # ---- Metric weights (must sum to 1.0) ----
        self.weights = {
            "emotional_expression_score": 0.40,
            "vocal_tone_score":           0.35,
            "script_alignment_score":     0.25,
        }
        assert abs(sum(self.weights.values()) - 1.0) < 1e-6, "Weights must sum to 1.0"

    # -----------------------------------------------------------------------
    # Initialization
    # -----------------------------------------------------------------------
    async def initialize(self):
        import asyncio
        """Load all three models.  Call this once at service startup."""
        logger.info("Initializing ML pipeline — loading models...")
        logger.info("Step 1/3: Loading video emotion model...")
        await self._load_emotion_model()
        await self._load_audio_model()
        logger.info("Step 2/3: Done.")
        logger.info("ML pipeline ready.")

    async def _load_emotion_model(self):
        try:   # must be before any TF import

            model_path = _find_path(VIDEO_MODEL_CANDIDATES)
            if model_path is None:
                logger.warning(
                    "Video emotion model not found. Tried: %s",
                    VIDEO_MODEL_CANDIDATES,
                )
                return
            custom_objects = {"SumPooling": SumPooling}
            # Try tf_keras first (most compatible with the saved model)
            try:
                import tf_keras
                self.emotion_model = tf_keras.models.load_model(
                    str(model_path),custom_objects=custom_objects, compile=False
                )
                logger.info("Video emotion model loaded via tf_keras from %s", model_path)
            except (ImportError, Exception):
                import tensorflow as tf
                try:
                    self.emotion_model = tf.keras.models.load_model(
                        str(model_path),custom_objects=custom_objects, compile=False, safe_mode=False
                    )
                except TypeError:
                    self.emotion_model = tf.keras.models.load_model(
                        str(model_path),custom_objects=custom_objects, compile=False
                    )
                logger.info("Video emotion model loaded via tf.keras from %s", model_path)

        except Exception as e:
            logger.error("Could not load video emotion model: %s", e)

    async def _load_audio_model(self):
        """
        Load the fine-tuned wav2vec2 audio-emotion model.

        The notebook saved the full model folder with:
            trainer.save_model('./emotion-recognition-final')
            feature_extractor.save_pretrained('./emotion-recognition-final')
            # plus label_mapping.json inside the same folder
        """
        try:
            from transformers import AutoFeatureExtractor, AutoModelForAudioClassification

            model_path = _find_path(AUDIO_MODEL_CANDIDATES)
            if model_path is None:
                logger.warning(
                    "Audio emotion model not found. Tried: %s",
                    AUDIO_MODEL_CANDIDATES,
                )
                return

            self.audio_feature_extractor = AutoFeatureExtractor.from_pretrained(str(model_path))
            self.audio_model = AutoModelForAudioClassification.from_pretrained(str(model_path))
            self.audio_model.eval()

            label_file = model_path / "label_mapping.json"
            if label_file.exists():
                with open(label_file, "r") as f:
                    self.audio_label_mapping = json.load(f)
            else:
                # Build a default mapping that matches the RAVDESS order
                self.audio_label_mapping = {
                    "id2label": {str(i): name for i, name in enumerate(EMOTION_NAMES)},
                    "label2id": {name: str(i) for i, name in enumerate(EMOTION_NAMES)},
                }

            logger.info("Audio emotion model loaded from %s", model_path)

        except Exception as e:
            logger.error("Could not load audio emotion model: %s", e)

    
    # -----------------------------------------------------------------------
    # Public entry point
    # -----------------------------------------------------------------------

    async def evaluate_video(
        self,
        video_path: str,
        script_text: Optional[str] = None,
    ) -> Dict:
        """
        Run the full evaluation pipeline on one audition video.

        Parameters
        ----------
        video_path  : path to the video file (mp4 / avi / mov / etc.)
        script_text : the expected script the actor should have recited
                      (plain text, any language).  If None the
                      script_alignment_score is set to 0.

        Returns
        -------
        dict with keys:
            emotional_expression_score  float  0–100
            vocal_tone_score            float  0–100
            script_alignment_score      float  0–100
            overall_performance_score   float  0–100
            detected_emotions           dict   {primary, secondary, confidence, all_scores}
            ai_feedback                 str
        """
        logger.info("Starting evaluation for video: %s", video_path)

        # ---------- 1. Extract audio once — reused by audio + script models ----------
        tmp_audio = None
        try:
            tmp_dir = tempfile.mkdtemp()
            tmp_audio = os.path.join(tmp_dir, "extracted_audio.wav")
            _extract_audio_ffmpeg(video_path, tmp_audio)
            logger.info("Audio extracted to %s", tmp_audio)
        except Exception as e:
            logger.error("Audio extraction failed: %s", e)
            tmp_audio = None

        # ---------- 2. Score each dimension ----------
        emotional_score, emotions_detail = await self._score_emotion_video(video_path)
        vocal_score = await self._score_audio_emotion(tmp_audio)
        script_score = await self._score_script_alignment(tmp_audio, script_text)

        # ---------- 3. Weighted overall score ----------
        overall = round(
            emotional_score * self.weights["emotional_expression_score"]
            + vocal_score   * self.weights["vocal_tone_score"]
            + script_score  * self.weights["script_alignment_score"],
            2,
        )
        overall = max(0.0, min(100.0, overall))

        # ---------- 4. Build feedback text ----------
        feedback = self._generate_feedback(
            overall, emotional_score, vocal_score, script_score
        )

        # ---------- 5. Clean up temp audio ----------
        if tmp_audio and Path(tmp_audio).exists():
            try:
                Path(tmp_audio).unlink()
            except Exception:
                pass

        logger.info(
            "Evaluation complete — overall=%.2f  emotion=%.2f  vocal=%.2f  script=%.2f",
            overall, emotional_score, vocal_score, script_score,
        )

        return {
            "emotional_expression_score": round(emotional_score, 2),
            "vocal_tone_score":           round(vocal_score, 2),
            "script_alignment_score":     round(script_score, 2),
            "overall_performance_score":  overall,
            "detected_emotions":          emotions_detail,
            "ai_feedback":                feedback,
        }

    # -----------------------------------------------------------------------
    # 1 — Video emotion scoring
    # -----------------------------------------------------------------------

    async def _score_emotion_video(
        self, video_path: str
    ) -> Tuple[float, Dict]:
        """
        Returns (score_0_to_100, emotions_dict).

        Steps
        -----
        1. Extract FRAMES_PER_VIDEO evenly-spaced frames with OpenCV.
        2. Detect & crop face per frame using the Haar cascade
           (same approach as Vedio_Audio_integration.ipynb — avoids
           RetinaFace / MediaPipe installation issues).
        3. Resize to IMG_SIZE × IMG_SIZE, normalise with ImageNet stats.
        4. Run the ResNet50 + BiLSTM model to get per-frame probabilities.
        5. Average across frames → primary emotion + confidence score.

        Score formula
        -------------
        score = confidence_of_primary_emotion * 100
        (A higher confidence that the model detected *any* emotion consistently
        across the performance is used as the emotional expression score.)
        """
        if self.emotion_model is None:
            logger.warning("Video emotion model not loaded — returning 0.")
            return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

        try:
            import cv2

            # ---- Extract frames ----
            frames = self._extract_video_frames(video_path)    # (N, H, W, 3) float32 [0,1]
            if len(frames) == 0:
                logger.warning("No frames extracted from %s", video_path)
                return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

            # ---- ImageNet normalisation (same as training) ----
            frames_norm = (frames - IMAGENET_MEAN) / IMAGENET_STD   # (N, 160, 160, 3)

            # ---- Model expects (1, FRAMES_PER_VIDEO, 160, 160, 3) ----
            #  Pad or trim to exactly FRAMES_PER_VIDEO
            if len(frames_norm) < FRAMES_PER_VIDEO:
                pad = np.zeros(
                    (FRAMES_PER_VIDEO - len(frames_norm), IMG_SIZE, IMG_SIZE, 3),
                    dtype=np.float32,
                )
                frames_norm = np.concatenate([frames_norm, pad], axis=0)
            else:
                frames_norm = frames_norm[:FRAMES_PER_VIDEO]

            input_batch = frames_norm[np.newaxis, ...]   # (1, 10, 160, 160, 3)

            # ---- Predict ----
            probabilities = self.emotion_model.predict(input_batch, verbose=0)[0]  # (8,)
            probabilities = np.array(probabilities, dtype=np.float64)
            probabilities = probabilities / probabilities.sum()                     # normalise

            primary_idx   = int(np.argmax(probabilities))
            secondary_idx = int(np.argsort(probabilities)[-2])

            primary_emotion   = EMOTION_NAMES[primary_idx]
            secondary_emotion = EMOTION_NAMES[secondary_idx]
            confidence        = float(probabilities[primary_idx])

            # Score: confidence of recognised emotion → 0–100
            score = round(confidence * 100, 2)

            emotions_detail = {
                "primary":    primary_emotion,
                "secondary":  secondary_emotion,
                "confidence": round(confidence, 4),
                "all_scores": {
                    EMOTION_NAMES[i]: round(float(probabilities[i]), 4)
                    for i in range(NUM_CLASSES)
                },
            }

            logger.info(
                "Video emotion — primary=%s  confidence=%.2f%%  score=%.2f",
                primary_emotion, confidence * 100, score,
            )
            return score, emotions_detail

        except Exception as e:
            logger.error("Video emotion scoring failed: %s", e, exc_info=True)
            return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

    def _extract_video_frames(self, video_path: str) -> np.ndarray:
        """
        Open the video with OpenCV, extract FRAMES_PER_VIDEO evenly-spaced
        frames, detect & crop the face in each, then resize to IMG_SIZE.

        Returns float32 array of shape (N, IMG_SIZE, IMG_SIZE, 3) in [0, 1].
        """
        import cv2

        face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )

        cap = cv2.VideoCapture(str(video_path))
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total <= 0:
            cap.release()
            return np.array([])

        indices = np.linspace(0, total - 1, FRAMES_PER_VIDEO, dtype=int)
        frames = []

        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
            ret, frame = cap.read()
            if not ret:
                if frames:
                    frames.append(frames[-1].copy())
                else:
                    frames.append(np.zeros((IMG_SIZE, IMG_SIZE, 3), dtype=np.float32))
                continue

            # ---- Face detection & crop ----
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(30, 30))
            if len(faces) > 0:
                x, y, w, h = faces[0]
                pad = 20
                x1 = max(0, x - pad)
                y1 = max(0, y - pad)
                x2 = min(frame.shape[1], x + w + pad)
                y2 = min(frame.shape[0], y + h + pad)
                frame = frame[y1:y2, x1:x2]

            frame = cv2.resize(frame, (IMG_SIZE, IMG_SIZE))
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = frame.astype(np.float32) / 255.0
            frames.append(frame)

        cap.release()
        return np.array(frames, dtype=np.float32)

    # -----------------------------------------------------------------------
    # 2 — Audio emotion scoring (vocal tone)
    # -----------------------------------------------------------------------

    async def _score_audio_emotion(
        self, audio_path: Optional[str]
    ) -> float:
        """
        Feed the WAV file to the fine-tuned wav2vec2 model in overlapping
        10-second windows (matching the training max_length), average the
        softmax probabilities, and return confidence * 100 as the score.

        Score interpretation
        --------------------
        Higher confidence = the model is very sure about the emotion being
        expressed, which correlates with clear, consistent vocal delivery.
        """
        if self.audio_model is None or audio_path is None:
            logger.warning("Audio model not loaded or no audio path — returning 0.")
            return 0.0

        if not Path(audio_path).exists():
            logger.warning("Audio file not found: %s", audio_path)
            return 0.0

        try:
            import torch
            import soundfile as sf
            import librosa

            # ---- Load audio ----
            audio_array, sr = sf.read(audio_path)
            audio_array = np.array(audio_array, dtype=np.float32).flatten()
            if sr != 16000:
                audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=16000)
                sr = 16000

            # ---- Segment into 10-second windows ----
            max_samples = 16000 * 10
            segments = []
            for start in range(0, len(audio_array), max_samples):
                seg = audio_array[start: start + max_samples]
                if len(seg) < 1600:          # skip < 0.1 s slivers
                    continue
                segments.append(seg)

            if not segments:
                return 0.0

            # ---- Run model per segment ----
            all_probs = []
            for seg in segments:
                inputs = self.audio_feature_extractor(
                    seg,
                    sampling_rate=16000,
                    return_tensors="pt",
                    padding=True,
                    max_length=max_samples,
                    truncation=True,
                )
                with torch.no_grad():
                    logits = self.audio_model(**inputs).logits
                probs = torch.nn.functional.softmax(logits, dim=-1)[0].numpy()
                all_probs.append(probs)

            # ---- Average across segments ----
            avg_probs = np.mean(all_probs, axis=0)
            best_confidence = float(np.max(avg_probs))

            score = round(best_confidence * 100, 2)
            logger.info("Audio emotion score = %.2f (confidence=%.4f)", score, best_confidence)
            return score

        except Exception as e:
            logger.error("Audio emotion scoring failed: %s", e, exc_info=True)
            return 0.0

    # -----------------------------------------------------------------------
    # 3 — Script alignment scoring
    # -----------------------------------------------------------------------

    async def _score_script_alignment(
        self,
        audio_path: Optional[str],
        script_text: Optional[str],
    ) -> float:
        """
        Transcribe the audio with WhisperX, then compare every word of the
        transcription against the expected script using Python's difflib
        SequenceMatcher (same algorithm as Script_Alignment_Final.ipynb).

        Score = (matched_words / total_script_words) * 100

        If no script is provided the score is 0 because we have nothing to
        compare against.  If WhisperX is not loaded the score is also 0.
        """
        if self.script_model is None:
            logger.warning("WhisperX not loaded — script alignment score = 0.")
            return 0.0

        if not script_text or not audio_path:
            logger.info("No script text or audio provided — script score = 0.")
            return 0.0

        if not Path(audio_path).exists():
            logger.warning("Audio file not found: %s", audio_path)
            return 0.0

        try:
            import torch
            import whisperx

            device = "cuda" if torch.cuda.is_available() else "cpu"

            # ---- Transcribe ----
            logger.info("Running WhisperX transcription...")
            audio = whisperx.load_audio(audio_path)
            result = self.script_model.transcribe(
                audio,
                batch_size=10,
                language="en",      # change to "ar" for Arabic
            )

            # ---- Optional word-level alignment ----
            try:
                model_a, metadata = whisperx.load_align_model(
                    language_code=result.get("language", "en"),
                    device=device,
                )
                result = whisperx.align(
                    result["segments"], model_a, metadata, audio, device,
                    return_char_alignments=False,
                )
            except Exception as align_err:
                logger.warning("Word-level alignment skipped: %s", align_err)

            # ---- Collect transcription words ----
            transcript_words_raw = []
            for seg in result.get("segments", []):
                for word_obj in seg.get("words", []):
                    w = word_obj.get("word", "")
                    if w:
                        transcript_words_raw.append(w)
                # Fallback if no word-level data
                if not seg.get("words"):
                    transcript_words_raw.extend(seg.get("text", "").split())

            transcript_clean = _normalize_text(" ".join(transcript_words_raw)).split()
            script_clean     = _normalize_text(script_text).split()

            if not script_clean:
                return 0.0

            # ---- difflib comparison (same as the notebook) ----
            matcher = difflib.SequenceMatcher(None, script_clean, transcript_clean)
            matched_chars = sum(
                triple.size
                for triple in matcher.get_matching_blocks()
            )

            # matched_chars here is matched *words* because we tokenised
            score = round(
                min(matched_chars / len(script_clean), 1.0) * 100, 2
            )

            logger.info(
                "Script alignment — matched=%d / total=%d → score=%.2f",
                matched_chars, len(script_clean), score,
            )
            return score

        except Exception as e:
            logger.error("Script alignment scoring failed: %s", e, exc_info=True)
            return 0.0

    # -----------------------------------------------------------------------
    # Feedback generation
    # -----------------------------------------------------------------------

    def _generate_feedback(
        self,
        overall: float,
        emotional: float,
        vocal: float,
        script: float,
    ) -> str:
        """
        Build a human-readable feedback string that mirrors the tone used in
        the mock evaluations but is now based on the real scores.
        """
        lines = []

        # Overall verdict
        if overall >= 80:
            lines.append(
                "Excellent performance! You demonstrated strong emotional expression, "
                "clear vocal tone, and excellent script alignment."
            )
        elif overall >= 60:
            lines.append(
                "Good performance. You showed decent emotional range and vocal control."
            )
        elif overall >= 40:
            lines.append(
                "Average performance. There is clear potential, but several areas need work."
            )
        else:
            lines.append(
                "Needs improvement. Focus on emotional expression, vocal clarity, "
                "and script accuracy."
            )

        # Specific notes for weak dimensions
        if emotional < 50:
            lines.append(
                "Emotional Expression: Try to show more consistent and authentic emotions "
                "through your facial expressions throughout the performance."
            )
        if vocal < 50:
            lines.append(
                "Vocal Tone: Work on voice clarity and expressiveness. "
                "Ensure you are speaking at a consistent volume and pace."
            )
        if script < 50:
            lines.append(
                "Script Alignment: Memorise the script more thoroughly. "
                "Several words or phrases were missed or changed."
            )

        return "  ".join(lines)