"""
ML Pipeline for AI Evaluation Service
======================================
Integrates 3 trained models to evaluate audition videos:

  1. Video Emotion Model  -> emotional_expression_score (40%)
     - Architecture : ResNet50 + 2-layer Bidirectional LSTM + Attention
     - File         : ./models/best_video_emotion_model.h5
     - Framework    : TensorFlow / Keras
     - Input        : (1, 16, 224, 224, 3)  <- 16 frames @ 224x224, ImageNet-normalised
     - Face detector: OpenCV Haar cascade   <- matches training

  2. Audio Emotion Model  -> vocal_tone_score (35%)
     - Architecture : facebook/wav2vec2-base fine-tuned on RAVDESS
     - Folder       : ./emotion-recognition-final/
     - Framework    : PyTorch / HuggingFace Transformers
     - NEW: Supports sentence-level emotion detection with script alignment

  3. Script Alignment     -> script_alignment_score (25%)
     - Architecture : facebook/seamless-m4t-v2-large (ASR) + difflib
     - Framework    : transformers (SeamlessM4Tv2Model + AutoProcessor)
     - NEW: Optional - if no script provided, uses transcription only

  Eye contact score (informational only -- not in overall_performance_score)
     - Method : dlib 68-point face landmark EAR (Eye Aspect Ratio)
     - Replaces MediaPipe FaceMesh which broke on mediapipe >= 0.10

Overall score = emotional_expression * 0.40
              + vocal_tone            * 0.35
              + script_alignment      * 0.25

Changelog
---------
- Added sentence-level emotion detection for audio
- Made script alignment optional (returns 0 if no script provided)
- Added detailed emotion breakdown per sentence when script is provided
- Enhanced vocal emotion detection to return full emotion analysis
- Fixed SeamlessM4T tokenizer Metaspace bug (patch tokenizer.json in place)
- Fixed memory issues with 8-bit quantization and offloading
- Fixed logging errors and task parameter issues
"""

# ---------------------------------------------------------------------------
# Numpy 2.x compatibility shim -- must be before ALL other imports
# ---------------------------------------------------------------------------
import numpy as np

_numpy_compat = {"NaN": np.nan, "Inf": np.inf}
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
import cv2
import tensorflow as tf

from pathlib import Path
from typing import Dict, List, Optional, Tuple
from collections import Counter

from core.eye_analysis import analyze_eye_expression

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Emotion label mapping -- shared by both video and audio models
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
EMOTION_NAMES: List[str] = list(EMOTIONS.values())
NUM_CLASSES = len(EMOTION_NAMES)  # 8

# ---------------------------------------------------------------------------
# Video model hyper-parameters -- must match training notebook exactly
# ---------------------------------------------------------------------------
FRAMES_PER_VIDEO = 10        # training: num_frames=16
IMG_SIZE         = 160       # training: target_size=(224, 224)
IMAGENET_MEAN    = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD     = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# ---------------------------------------------------------------------------
# Model file locations
# ---------------------------------------------------------------------------
VIDEO_MODEL_CANDIDATES = [
    "./models/best_video_emotion_model.h5",
    "/app/models/best_video_emotion_model.h5",
    "models/best_video_emotion_model.h5",
]

AUDIO_MODEL_CANDIDATES = [
    "./emotion-recognition-final",
    "./models/emotion-recognition-final",
    "/app/models/emotion-recognition-final",
    "models/emotion-recognition-final",
]

# dlib shape predictor -- download from:
# http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2
DLIB_PREDICTOR_CANDIDATES = [
    "./models/shape_predictor_68_face_landmarks.dat",
    "/app/models/shape_predictor_68_face_landmarks.dat",
    "shape_predictor_68_face_landmarks.dat",
]

# SeamlessM4T local model folder
# Prioritize fp32 converted model to avoid quantization issues on CPU
SEAMLESS_MODEL_CANDIDATES = [
    "./models/seamless-m4t-v2-large-fp32",
    "/app/models/seamless-m4t-v2-large-fp32",
    "models/seamless-m4t-v2-large-fp32",
    "./seamless-m4t-v2-large-clean",
    "./models/seamless-m4t-v2-large-clean",
    "/app/models/seamless-m4t-v2-large-clean",
    "models/seamless-m4t-v2-large-clean",
]

SEAMLESS_SRC_LANG    = "eng"
SEAMLESS_SAMPLE_RATE = 16_000


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
    Use ffmpeg to extract the audio track as a 16 kHz mono WAV.
    Required by both SeamlessM4T and the wav2vec2 audio emotion model.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", str(video_path),
        "-vn",
        "-acodec", "pcm_s16le",
        "-ar", "16000",
        "-ac", "1",
        str(output_wav),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg failed while extracting audio.\n"
            f"stderr: {result.stderr}\nstdout: {result.stdout}"
        )
    if not Path(output_wav).exists():
        raise ValueError("ffmpeg produced no output file -- video may have no audio track.")
    return output_wav


def _normalize_text(text: str) -> str:
    """Lower-case and strip punctuation for fair script vs transcript comparison."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


@tf.keras.utils.register_keras_serializable(package="Custom")
class SumPooling(tf.keras.layers.Layer):
    def __init__(self, axis=1, **kwargs):
        super().__init__(**kwargs)
        self.axis = axis

    def call(self, inputs):
        return tf.reduce_sum(inputs, axis=self.axis)

    def get_config(self):
        config = super().get_config()
        config.update({"axis": self.axis})
        return config


# ===========================================================================
# MLPipeline
# ===========================================================================

class MLPipeline:
    """
    Load models once at startup, then call evaluate_video() per audition.

    Usage
    -----
    pipeline = MLPipeline()
    await pipeline.initialize()
    result = await pipeline.evaluate_video(video_path, script_text=script)
    """

    def __init__(self):
        # ---- Video model (TensorFlow / Keras) ----
        self.emotion_model = None

        # ---- Audio model (PyTorch / HuggingFace) ----
        self.audio_feature_extractor = None
        self.audio_model             = None
        self.audio_label_mapping     = None

        # ---- Script alignment (SeamlessM4T) ----
        self.script_processor = None   # AutoProcessor
        self.script_model     = None   # SeamlessM4Tv2Model

        # ---- dlib eye-contact scorer (lazy-loaded on first use) ----
        self._dlib_detector  = None
        self._dlib_predictor = None
        self._dlib_loaded    = False   # True once load has been attempted

        # ---- OpenCV Haar cascade for frame extraction (lazy-loaded) ----
        self._face_cascade = None

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
        """Load all three models. Call this once at service startup."""
        logger.info("Initializing ML pipeline -- loading models...")

        logger.info("Step 1/3: Loading video emotion model...")
        await self._load_emotion_model()
        logger.info("Step 1/3: Done.")

        logger.info("Step 2/3: Loading audio emotion model...")
        await self._load_audio_model()
        logger.info("Step 2/3: Done.")

        logger.info("Step 3/3: Loading SeamlessM4T script model...")
        await self._load_script_model()
        logger.info("Step 3/3: Done.")

        logger.info("ML pipeline ready.")

    async def _load_emotion_model(self):
        try:
            model_path = _find_path(VIDEO_MODEL_CANDIDATES)
            if model_path is None:
                logger.warning(
                    "Video emotion model not found. Tried: %s", VIDEO_MODEL_CANDIDATES
                )
                return

            custom_objects = {"SumPooling": SumPooling}
            try:
                import tf_keras
                self.emotion_model = tf_keras.models.load_model(
                    str(model_path), custom_objects=custom_objects, compile=False
                )
                logger.info("Video emotion model loaded via tf_keras from %s", model_path)
            except (ImportError, Exception):
                try:
                    self.emotion_model = tf.keras.models.load_model(
                        str(model_path),
                        custom_objects=custom_objects,
                        compile=False,
                        safe_mode=False,
                    )
                except TypeError:
                    self.emotion_model = tf.keras.models.load_model(
                        str(model_path), custom_objects=custom_objects, compile=False
                    )
                logger.info("Video emotion model loaded via tf.keras from %s", model_path)

        except Exception as e:
            logger.error("Could not load video emotion model: %s", e)

    async def _load_audio_model(self):
        """Load the fine-tuned wav2vec2 audio-emotion model."""
        try:
            from transformers import AutoFeatureExtractor, AutoModelForAudioClassification

            model_path = _find_path(AUDIO_MODEL_CANDIDATES)
            if model_path is None:
                logger.warning(
                    "Audio emotion model not found. Tried: %s", AUDIO_MODEL_CANDIDATES
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
                self.audio_label_mapping = {
                    "id2label": {str(i): name for i, name in enumerate(EMOTION_NAMES)},
                    "label2id": {name: str(i) for i, name in enumerate(EMOTION_NAMES)},
                }

            logger.info("Audio emotion model loaded from %s", model_path)

        except Exception as e:
            logger.error("Could not load audio emotion model: %s", e)

    async def _load_script_model(self):
        """Use remote Colab SeamlessM4T GPU API."""
        api_url ="https://dolly-reckless-celibacy.ngrok-free.dev/transcribe"
        if api_url:
            self.script_model     = api_url
            self.script_processor = "remote"
            logger.info("✓ Using remote SeamlessM4T API at %s", api_url)
        else:
            logger.warning("SEAMLESS_API_URL not set -- script alignment disabled")
            self.script_model     = None
            self.script_processor = None
    # -----------------------------------------------------------------------
    # Eye contact scoring -- dlib 68-point EAR
    # -----------------------------------------------------------------------
    def _ensure_dlib_loaded(self) -> bool:
        """
        Lazy-load dlib detector + shape predictor on first call.
        Returns True if both are ready, False otherwise.
        """
        if self._dlib_loaded:
            return self._dlib_detector is not None and self._dlib_predictor is not None

        self._dlib_loaded = True

        try:
            import dlib
        except ImportError:
            logger.warning(
                "dlib not installed -- eye contact scoring will return 0. "
                "Install with: pip install dlib"
            )
            return False

        predictor_path = _find_path(DLIB_PREDICTOR_CANDIDATES)
        if predictor_path is None:
            logger.warning(
                "dlib shape predictor not found. Tried: %s. "
                "Download from http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2 "
                "and place it at one of the above paths. "
                "Eye contact scoring will return 0 until it is available.",
                DLIB_PREDICTOR_CANDIDATES,
            )
            return False

        try:
            self._dlib_detector  = dlib.get_frontal_face_detector()
            self._dlib_predictor = dlib.shape_predictor(str(predictor_path))
            logger.info("dlib shape predictor loaded from %s", predictor_path)
            return True
        except Exception as e:
            logger.error("Failed to initialise dlib: %s", e)
            return False

    def _get_head_direction(self, shape) -> str:
        """
        Determine head direction (UP, DOWN, LEFT, RIGHT, NEUTRAL)
        based on dlib 68-point landmarks.
        """
        # Get key landmarks: nose tip (30), chin (8)
        nose = np.array([shape.part(30).x, shape.part(30).y], dtype=np.float32)
        chin = np.array([shape.part(8).x, shape.part(8).y], dtype=np.float32)
        left_eye = np.array([shape.part(36).x, shape.part(36).y], dtype=np.float32)
        right_eye = np.array([shape.part(45).x, shape.part(45).y], dtype=np.float32)

        # Calculate angles
        vertical_vec = chin - nose
        horizontal_vec = right_eye - left_eye

        vert_angle = np.arctan2(vertical_vec[1], vertical_vec[0])
        horiz_angle = np.arctan2(horizontal_vec[1], horizontal_vec[0])

        # Determine direction
        vert_deg = np.degrees(vert_angle)
        horiz_deg = np.degrees(horiz_angle)

        # Vertical direction (UP/DOWN)
        if vert_deg < -60:
            vert_dir = "UP"
        elif vert_deg > 60:
            vert_dir = "DOWN"
        else:
            vert_dir = "NEUTRAL"

        # Horizontal direction (LEFT/RIGHT)
        if horiz_deg > 20:
            horiz_dir = "LEFT"
        elif horiz_deg < -20:
            horiz_dir = "RIGHT"
        else:
            horiz_dir = "NEUTRAL"

        # Combine (prefer vertical for simplicity)
        if vert_dir != "NEUTRAL":
            return vert_dir
        return horiz_dir if horiz_dir != "NEUTRAL" else "NEUTRAL"

    def _extract_mediapipe_landmarks(self, video_path: str) -> Tuple[Optional[Dict], Optional[List]]:
        """
        Extract landmarks using MediaPipe for all frames.
        Returns (quality_report, iris_series) following Colab approach.
        """
        try:
            import mediapipe as mp
            mp_face_mesh = mp.solutions.face_mesh
        except (ImportError, AttributeError):
            logger.warning("MediaPipe not available, will use dlib fallback")
            return None, None

        try:
            face_mesh = mp_face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5,
            )

            cap = cv2.VideoCapture(str(video_path))
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            fps = cap.get(cv2.CAP_PROP_FPS)
            frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

            usable_frames = []
            frame_index = 0

            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break

                timestamp_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = face_mesh.process(rgb_frame)

                if results.multi_face_landmarks:
                    usable_frames.append({
                        "frame_index": frame_index,
                        "timestamp_ms": timestamp_ms,
                        "landmarks": results.multi_face_landmarks[0].landmark,
                    })

                frame_index += 1

            cap.release()
            face_mesh.close()

            total_processed = frame_index
            usable_ratio = len(usable_frames) / total_processed if total_processed > 0 else 0
            video_is_usable = usable_ratio >= 0.70

            report = {
                "video_path": video_path,
                "fps": fps,
                "frame_width": frame_width,
                "frame_height": frame_height,
                "duration_seconds": total_frames / fps if fps > 0 else 0,
                "total_frames": total_processed,
                "usable_frames": len(usable_frames),
                "skipped_frames": total_processed - len(usable_frames),
                "usable_ratio": usable_ratio,
                "video_is_usable": video_is_usable,
                "usable_frame_data": usable_frames,
            }

            # Extract iris ratios
            iris_series = []
            for fd in usable_frames:
                ts = fd["timestamp_ms"]
                lm = fd["landmarks"]

                # Iris indices: 468=left, 473=right
                iris_left = np.array([lm[468].x, lm[468].y])
                iris_right = np.array([lm[473].x, lm[473].y])

                # Eye corner indices
                left_inner = np.array([lm[33].x, lm[33].y])
                left_outer = np.array([lm[133].x, lm[133].y])
                right_inner = np.array([lm[362].x, lm[362].y])
                right_outer = np.array([lm[263].x, lm[263].y])
                left_top = np.array([lm[159].x, lm[159].y])
                left_bot = np.array([lm[145].x, lm[145].y])
                right_top = np.array([lm[386].x, lm[386].y])
                right_bot = np.array([lm[374].x, lm[374].y])

                def safe_ratio(val, lo, hi):
                    span = hi - lo
                    return (val - lo) / span if span != 0 else 0.5

                # Horizontal: left eye → inner is left, outer is right
                h_left = safe_ratio(iris_left[0], left_inner[0], left_outer[0])
                h_right = safe_ratio(iris_right[0], right_outer[0], right_inner[0])
                h_ratio = float(np.mean([h_left, h_right]))

                # Vertical
                v_left = safe_ratio(iris_left[1], left_top[1], left_bot[1])
                v_right = safe_ratio(iris_right[1], right_top[1], right_bot[1])
                v_ratio = float(np.mean([v_left, v_right]))

                iris_series.append({
                    "timestamp_ms": ts,
                    "h_ratio": h_ratio,
                    "v_ratio": v_ratio,
                    "landmarks": lm,
                })

            logger.info(
                "MediaPipe extraction: %d usable frames from %d total (%.1f%%)",
                len(usable_frames), total_processed, usable_ratio * 100
            )

            return report, iris_series

        except Exception as e:
            logger.error("MediaPipe extraction failed: %s", e)
            return None, None

    def _calibrate_gaze_centre(self, iris_series: List[Dict]) -> Tuple[float, float, float, float]:
        """
        Calibrate neutral gaze centre from iris series.
        Returns (center_h, center_v, h_tol, v_tol).
        """
        h_vals = np.array([f["h_ratio"] for f in iris_series])
        v_vals = np.array([f["v_ratio"] for f in iris_series])

        center_h = float(np.median(h_vals))
        center_v = float(np.median(v_vals))

        h_tol = float(np.percentile(np.abs(h_vals - center_h), 75))
        v_tol = float(np.percentile(np.abs(v_vals - center_v), 75))

        # Clamp to sensible minimum
        h_tol = max(h_tol, 0.02)
        v_tol = max(v_tol, 0.02)

        logger.debug(
            "Gaze centre calibrated: H=%.3f±%.3f, V=%.3f±%.3f",
            center_h, h_tol, center_v, v_tol
        )

        return center_h, center_v, h_tol, v_tol

    def _classify_gaze(self, h: float, v: float, center_h: float, center_v: float,
                       h_tol: float, v_tol: float) -> str:
        """Classify gaze direction as string label."""
        h_off = h - center_h
        v_off = v - center_v

        h_dir = ("RIGHT" if h_off > h_tol else
                "LEFT" if h_off < -h_tol else "")
        v_dir = ("DOWN" if v_off > v_tol else
                "UP" if v_off < -v_tol else "")

        if h_dir and v_dir:
            return f"{v_dir}-{h_dir}"
        return h_dir or v_dir or "CENTER"

    async def _analyze_emotion_transitions(
        self,
        frames: np.ndarray,
        video_path: str,
        sentences_aligned: Optional[List[Dict]] = None,
        evaluation_id: Optional[str] = None,
    ) -> Dict:
        """
        Analyze emotion transitions using MediaPipe-based gaze tracking via eye_analysis module.
        Falls back to dlib if MediaPipe extraction fails.
        """
        if self.emotion_model is None:
            return {
                "score": 0.0,
                "result": "NEUTRAL",
                "message": "No emotion model available",
                "transitions": [],
            }

        # Try MediaPipe extraction
        quality_report, iris_series = self._extract_mediapipe_landmarks(video_path)
        
        if quality_report is None or iris_series is None:
            logger.warning("MediaPipe extraction failed, using dlib fallback")
            return await self._analyze_emotion_transitions_dlib(frames, video_path)

        try:
            # Use eye_analysis module for comprehensive eye expression analysis
            result = analyze_eye_expression(
                quality_report=quality_report,
                iris_series=iris_series,
                video_path=video_path,
                sentences_aligned=sentences_aligned,
                evaluation_id=evaluation_id,
            )
            return result

        except Exception as e:
            logger.error("Eye expression analysis failed: %s", e, exc_info=True)
            return await self._analyze_emotion_transitions_dlib(frames, video_path)

    async def _analyze_emotion_transitions_dlib(
        self, frames: np.ndarray, video_path: str
    ) -> Dict:
        """
        Fallback dlib-based eye movement analysis.
        Simple approach using head direction tracking.
        """
        try:
            cap = cv2.VideoCapture(str(video_path))
            fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
            frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            cap.release()

            aspect_ratio = frame_width / frame_height if frame_height > 0 else 1.0

            # Extract head directions from frames
            frame_directions = []

            for i, frame in enumerate(frames):
                direction = "CENTER"
                if self._ensure_dlib_loaded():
                    try:
                        img_uint8 = (frame * 255).astype(np.uint8)
                        gray = cv2.cvtColor(img_uint8, cv2.COLOR_RGB2GRAY)
                        faces = self._dlib_detector(gray, 0)
                        if len(faces) > 0:
                            face = max(faces, key=lambda r: r.width() * r.height())
                            shape = self._dlib_predictor(gray, face)
                            direction = self._get_head_direction(shape)
                    except Exception:
                        pass
                
                frame_directions.append(direction)

            # Track direction changes
            transitions = []
            prev_direction = None

            for i, direction in enumerate(frame_directions):
                if prev_direction is not None and direction != prev_direction:
                    time_ms = int((i / fps) * 1000) if fps > 0 else i * 33
                    time_sec = round(time_ms / 1000.0, 2)

                    transition = {
                        "time_sec": time_sec,
                        "time_ms": time_ms,
                        "from_emotion": prev_direction,
                        "to_emotion": direction,
                        "from_sentence": None,
                        "to_sentence": None,
                        "label": "HEAD_MOVEMENT",
                        "score": 50.0,
                        "displacement": 0.01,
                        "dir_before": prev_direction,
                        "dir_after": direction,
                        "message": f"Head movement from {prev_direction} to {direction}",
                        "before_image": None,
                        "after_image": None,
                        "image_aspect_ratio": aspect_ratio,
                    }
                    transitions.append(transition)

                prev_direction = direction

            # Determine result based on movement frequency
            if len(transitions) == 0:
                result = "NEUTRAL"
                message = "Minimal head movement detected"
                score = 10.0
            elif len(transitions) > 10:
                result = "EXPRESSIVE"
                message = "Frequent head movements—strong physical expression"
                score = min(100.0, 50 + len(transitions))
            elif len(transitions) > 5:
                result = "MODERATELY_EXPRESSIVE"
                message = "Moderate head movement detected"
                score = min(100.0, 30 + len(transitions) * 3)
            else:
                result = "SUBTLE"
                message = "Subtle head movements detected"
                score = min(100.0, 15 + len(transitions) * 5)

            logger.info(
                "Dlib fallback analysis: %s (score=%.1f, movements=%d)",
                result, score, len(transitions)
            )

            return {
                "score": round(score, 2),
                "result": result,
                "message": message,
                "transitions": transitions,
            }

        except Exception as e:
            logger.error("Dlib analysis failed: %s", e, exc_info=True)
            return {
                "score": 0.0,
                "result": "ERROR",
                "message": f"Analysis failed: {str(e)}",
                "transitions": [],
            }

    def _score_eye_contact(self, frames: np.ndarray) -> float:
        """
        Compute Eye Aspect Ratio (EAR) per frame using dlib 68-point landmarks
        and return a 0-100 score. Kept for backward compatibility.
        """
        if not self._ensure_dlib_loaded():
            return 0.0

        EAR_OPEN_THRESHOLD = 0.20
        EAR_FULL_OPEN      = 0.35

        def _ear(shape, start: int, end: int) -> float:
            pts = np.array(
                [[shape.part(i).x, shape.part(i).y] for i in range(start, end + 1)],
                dtype=np.float32,
            )
            v1 = np.linalg.norm(pts[1] - pts[5])
            v2 = np.linalg.norm(pts[2] - pts[4])
            h  = np.linalg.norm(pts[0] - pts[3])
            return float((v1 + v2) / (2.0 * h + 1e-6))

        ear_scores = []

        for frame in frames:
            img_uint8 = (frame * 255).astype(np.uint8)
            gray      = cv2.cvtColor(img_uint8, cv2.COLOR_RGB2GRAY)

            faces = self._dlib_detector(gray, 0)
            if len(faces) == 0:
                ear_scores.append(0.0)
                continue

            face  = max(faces, key=lambda r: r.width() * r.height())
            shape = self._dlib_predictor(gray, face)

            left_ear  = _ear(shape, 36, 41)
            right_ear = _ear(shape, 42, 47)
            avg_ear   = (left_ear + right_ear) / 2.0

            score = float(
                np.clip(
                    (avg_ear - EAR_OPEN_THRESHOLD) / (EAR_FULL_OPEN - EAR_OPEN_THRESHOLD),
                    0.0,
                    1.0,
                )
            )
            ear_scores.append(score)

        if not ear_scores:
            return 0.0
        return round(float(np.mean(ear_scores)) * 100, 2)

    # -----------------------------------------------------------------------
    # Public entry point
    # -----------------------------------------------------------------------
    async def evaluate_video(
        self,
        video_path: str,
        script_text: Optional[str] = None,
        audio_only: bool = False,
    ) -> Dict:
        """
        Run the full evaluation pipeline on one audition video.

        Parameters
        ----------
        video_path  : path to the video file (mp4 / avi / mov / etc.)
        script_text : the expected script as a JSON string:
                      '[{"content": "...", "emotion": "angry"}, ...]'
                      If None, script_alignment_score is set to 0.

        Returns
        -------
        dict with keys:
            emotional_expression_score  float  0-100
            vocal_tone_score            float  0-100
            script_alignment_score      float  0-100
            overall_performance_score   float  0-100
            eye_expression_score        float  0-100
            detected_emotions           dict
            detected_emotions_vocal     dict
            ai_feedback                 str
        """
        logger.info("Starting evaluation. audio_only=%s, video=%s", audio_only, video_path)

        tmp_audio = None
        try:
            tmp_dir   = tempfile.mkdtemp()
            tmp_audio = os.path.join(tmp_dir, "extracted_audio.wav")
            _extract_audio_ffmpeg(video_path, tmp_audio)
            logger.info("Audio extracted to %s", tmp_audio)
        except Exception as e:
            logger.error("Audio extraction failed: %s", e)
            tmp_audio = None

        # ── Script alignment ──────────────────────────────────────────────────
        sentences_aligned = None
        script_score      = 0.0
        alignment_data    = None

        if script_text and tmp_audio:
            script_score, alignment_data = await self._score_script_alignment_with_sentences(
                tmp_audio, script_text,
            )
            sentences_aligned = alignment_data.get("sentences_aligned") if alignment_data else None
        elif not script_text:
            logger.info("No script_text for evaluation — script_alignment_score stays 0")
        elif not tmp_audio:
            logger.warning("No extracted audio — script_alignment_score stays 0")

        # ── Audio emotion ─────────────────────────────────────────────────────
        if sentences_aligned:
            audio_result = await self._score_audio_emotion_per_sentence(tmp_audio, sentences_aligned)
        else:
            audio_result = await self._score_audio_emotion(tmp_audio, expected_emotion=None)

        vocal_score = audio_result["score"]
        detected_emotions_vocal = {
            "primary":     audio_result["detected_emotion"],
            "confidence":  audio_result["confidence"],
            "all_emotions": audio_result.get("all_emotions", {}),
        }
        if "sentence_results" in audio_result:
            detected_emotions_vocal["sentence_results"] = audio_result["sentence_results"]
            detected_emotions_vocal["accuracy"]         = audio_result.get("accuracy", 0.0)

        # ── Tone analysis ─────────────────────────────────────────────────────
        tone_result = None
        if tmp_audio:
            try:
                from core.tone import analyze_tone
                tone_result = analyze_tone(
                    audio_path=tmp_audio,
                    sentences_aligned=sentences_aligned,
                ) 
            except Exception as e:
                logger.error("Tone analysis failed: %s", e)

        # ── Audio-only path ───────────────────────────────────────────────────
        if audio_only:
            # Weights: vocal 50%, script 30%, tone 20%
            tone_score = 0.0
            if tone_result:
                pitch_var    = min(tone_result.get("overall_pitch_variation", 0) / 100, 1.0)
                loud_var     = min(tone_result.get("overall_loudness_variation", 0) / 20,  1.0)
                tone_score   = round((pitch_var * 0.5 + loud_var * 0.5) * 100, 2)

            overall = round(
                vocal_score  * 0.50
                + script_score * 0.30
                + tone_score   * 0.20,
                2,
            )
            overall = max(0.0, min(100.0, overall))
            feedback = self._generate_feedback(overall, 0, vocal_score, script_score)

            if tmp_audio and Path(tmp_audio).exists():
                try:
                    Path(tmp_audio).unlink()
                except Exception:
                    pass

            return {
                "mode":                      "audio_only",
                "vocal_tone_score":          round(vocal_score, 2),
                "script_alignment_score":    round(script_score, 2),
                "tone_score":                tone_score,
                "overall_performance_score": overall,
                "tone_analysis":             tone_result,
                "detected_emotions_vocal":   detected_emotions_vocal,
                "script_alignment_data":     alignment_data,
                "ai_feedback":               feedback,
            }

        # ── Full video path ───────────────────────────────────────────────────
        frames = self._extract_video_frames(video_path)

        emotional_score, emotions_detail = await self._score_emotion_video(frames)

        detected_emotions_video = None
        if sentences_aligned:
            video_emotion_result = await self._score_video_emotion_per_sentence(
                video_path, sentences_aligned,
            )
            detected_emotions_video = {
                "primary":          video_emotion_result["detected_emotion"],
                "confidence":       video_emotion_result["confidence"],
                "score":            video_emotion_result["score"],
                "accuracy":         video_emotion_result["accuracy"],
                "sentence_results": video_emotion_result.get("sentence_results", []),
            }

        eye_expression_data = await self._analyze_emotion_transitions(
            frames, video_path, sentences_aligned=sentences_aligned
        )

        overall = round(
            emotional_score * self.weights["emotional_expression_score"]
            + vocal_score   * self.weights["vocal_tone_score"]
            + script_score  * self.weights["script_alignment_score"],
            2,
        )
        overall = max(0.0, min(100.0, overall))
        feedback = self._generate_feedback(overall, emotional_score, vocal_score, script_score)

        if tmp_audio and Path(tmp_audio).exists():
            try:
                Path(tmp_audio).unlink()
            except Exception:
                pass

        logger.info(
            "Evaluation complete -- overall=%.2f  emotion=%.2f  vocal=%.2f  script=%.2f",
            overall, emotional_score, vocal_score, script_score,
        )

        return {
            "mode":                          "video",
            "emotional_expression_score":    round(emotional_score, 2),
            "vocal_tone_score":              round(vocal_score, 2),
            "script_alignment_score":        round(script_score, 2),
            "overall_performance_score":     overall,
            "eye_expression":                eye_expression_data,
            "tone_analysis":                 tone_result,
            "detected_emotions":             emotions_detail,
            "detected_emotions_vocal":       detected_emotions_vocal,
            "detected_emotions_video":       detected_emotions_video,
            "script_alignment_data":         alignment_data,
            "ai_feedback":                   feedback,
        }
    # -----------------------------------------------------------------------
    # 1 -- Video emotion scoring
    # -----------------------------------------------------------------------
    async def _score_emotion_video(
        self,
        frames: np.ndarray,
    ) -> Tuple[float, Dict]:
        """Run the ResNet50 + BiLSTM model and return (score, emotions_dict)."""
        logger.info("_score_emotion_video called with %d frames", len(frames))

        if self.emotion_model is None:
            logger.warning("Video emotion model not loaded -- returning 0.")
            return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

        try:
            if len(frames) == 0:
                logger.warning("No frames provided to _score_emotion_video")
                return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

            from tensorflow.keras.applications.efficientnet import preprocess_input

            frames_norm = preprocess_input(frames * 255.0)

            if len(frames_norm) < FRAMES_PER_VIDEO:
                pad = np.zeros(
                    (FRAMES_PER_VIDEO - len(frames_norm), IMG_SIZE, IMG_SIZE, 3),
                    dtype=np.float32,
                )
                frames_norm = np.concatenate([frames_norm, pad], axis=0)
            else:
                frames_norm = frames_norm[:FRAMES_PER_VIDEO]

            input_batch   = frames_norm[np.newaxis, ...]
            probabilities = self.emotion_model.predict(input_batch, verbose=0)[0]
            probabilities = np.array(probabilities, dtype=np.float64)
            probabilities = probabilities / probabilities.sum()

            primary_idx   = int(np.argmax(probabilities))
            secondary_idx = int(np.argsort(probabilities)[-2])

            primary_emotion   = EMOTION_NAMES[primary_idx]
            secondary_emotion = EMOTION_NAMES[secondary_idx]
            confidence        = float(probabilities[primary_idx])
            score             = round(confidence * 100, 2)

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
                "Video emotion -- primary=%s  confidence=%.2f%%  score=%.2f",
                primary_emotion, confidence * 100, score,
            )
            return score, emotions_detail

        except Exception as e:
            logger.error("Video emotion scoring failed: %s", e, exc_info=True)
            return 0.0, {"primary": "unknown", "secondary": "unknown", "confidence": 0.0}

    # -----------------------------------------------------------------------
    # Frame extraction -- OpenCV Haar cascade (matches training)
    # -----------------------------------------------------------------------
    def _extract_video_frames(self, video_path: str) -> np.ndarray:
        """
        Extract FRAMES_PER_VIDEO evenly-spaced frames using the OpenCV
        Haar cascade face detector -- the same detector used during training.

        Returns float32 array shape (N, IMG_SIZE, IMG_SIZE, 3) in [0, 1].
        """
        if self._face_cascade is None:
            cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            self._face_cascade = cv2.CascadeClassifier(cascade_path)

        HAAR_PADDING = 20

        cap   = cv2.VideoCapture(str(video_path))
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total <= 0:
            cap.release()
            return np.array([])

        indices   = np.linspace(0, total - 1, FRAMES_PER_VIDEO, dtype=int)
        frames    = []
        last_good = None

        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
            ret, frame = cap.read()

            if not ret:
                frames.append(
                    last_good.copy() if last_good is not None
                    else np.zeros((IMG_SIZE, IMG_SIZE, 3), dtype=np.float32)
                )
                continue

            h, w  = frame.shape[:2]
            gray  = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self._face_cascade.detectMultiScale(
                gray, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30)
            )

            face_crop = None
            if len(faces) > 0:
                fx, fy, fw, fh = faces[0]
                x1 = max(0, fx - HAAR_PADDING)
                y1 = max(0, fy - HAAR_PADDING)
                x2 = min(w, fx + fw + HAAR_PADDING)
                y2 = min(h, fy + fh + HAAR_PADDING)
                if x2 > x1 and y2 > y1:
                    face_crop = frame[y1:y2, x1:x2]

            if face_crop is None or face_crop.size == 0:
                if last_good is not None:
                    logger.debug("Frame %d: no face -- reusing last good crop.", idx)
                    frames.append(last_good.copy())
                    continue
                else:
                    logger.debug("Frame %d: no face and no prior crop -- using full frame.", idx)
                    size      = min(h, w)
                    y_off     = (h - size) // 2
                    x_off     = (w - size) // 2
                    face_crop = frame[y_off: y_off + size, x_off: x_off + size]

            resized    = cv2.resize(face_crop, (IMG_SIZE, IMG_SIZE))
            resized    = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
            normalized = resized.astype(np.float32) / 255.0
            last_good  = normalized
            frames.append(normalized)

        cap.release()
        return np.array(frames, dtype=np.float32)

    def _extract_frames_for_time_range(
        self,
        video_path: str,
        t_start: float,
        t_end: float,
        num_frames: int = FRAMES_PER_VIDEO,
    ) -> np.ndarray:
        """
        Extract a fixed number of frames evenly sampled from a specific time range.
        
        Parameters
        ----------
        video_path : str
            Path to the video file
        t_start : float
            Start time in seconds
        t_end : float
            End time in seconds
        num_frames : int
            Number of frames to extract (default: FRAMES_PER_VIDEO)
        
        Returns
        -------
        np.ndarray
            Array of shape (num_frames, IMG_SIZE, IMG_SIZE, 3) with float32 values in [0, 1]
        """
        if self._face_cascade is None:
            cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            self._face_cascade = cv2.CascadeClassifier(cascade_path)

        HAAR_PADDING = 20

        cap = cv2.VideoCapture(str(video_path))
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        if fps <= 0 or total_frames <= 0:
            cap.release()
            return np.array([], dtype=np.float32)

        # Convert time range to frame indices
        start_frame = int(t_start * fps)
        end_frame = int(t_end * fps)
        
        # Clamp to valid range
        start_frame = max(0, start_frame)
        end_frame = min(total_frames - 1, end_frame)
        
        if start_frame >= end_frame:
            cap.release()
            return np.array([], dtype=np.float32)

        # Extract num_frames evenly spaced frames from this range
        indices = np.linspace(start_frame, end_frame, num_frames, dtype=int)
        
        frames = []
        last_good = None

        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
            ret, frame = cap.read()

            if not ret:
                frames.append(
                    last_good.copy() if last_good is not None
                    else np.zeros((IMG_SIZE, IMG_SIZE, 3), dtype=np.float32)
                )
                continue

            h, w = frame.shape[:2]
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self._face_cascade.detectMultiScale(
                gray, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30)
            )

            face_crop = None
            if len(faces) > 0:
                fx, fy, fw, fh = faces[0]
                x1 = max(0, fx - HAAR_PADDING)
                y1 = max(0, fy - HAAR_PADDING)
                x2 = min(w, fx + fw + HAAR_PADDING)
                y2 = min(h, fy + fh + HAAR_PADDING)
                if x2 > x1 and y2 > y1:
                    face_crop = frame[y1:y2, x1:x2]

            if face_crop is None or face_crop.size == 0:
                if last_good is not None:
                    logger.debug("Frame %d: no face -- reusing last good crop.", idx)
                    frames.append(last_good.copy())
                    continue
                else:
                    logger.debug("Frame %d: no face and no prior crop -- using full frame.", idx)
                    size = min(h, w)
                    y_off = (h - size) // 2
                    x_off = (w - size) // 2
                    face_crop = frame[y_off : y_off + size, x_off : x_off + size]

            resized = cv2.resize(face_crop, (IMG_SIZE, IMG_SIZE))
            resized = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
            normalized = resized.astype(np.float32) / 255.0
            last_good = normalized
            frames.append(normalized)

        cap.release()
        return np.array(frames, dtype=np.float32)

    # -----------------------------------------------------------------------
    # 2 -- Audio emotion scoring (vocal tone)
    # -----------------------------------------------------------------------
    async def _score_audio_emotion(
        self,
        audio_path: Optional[str],
        expected_emotion: Optional[str] = None,
    ) -> dict:
        """
        Feed the WAV file to the fine-tuned wav2vec2 model in segments,
        detect the dominant emotion, and return a comprehensive result.
        """
        if self.audio_model is None or audio_path is None:
            logger.warning("Audio model not loaded or no audio path -- returning 0.")
            return {
                "score": 0.0,
                "detected_emotion": "neutral",
                "confidence": 0.0,
                "all_emotions": {},
                "metrics": {},
            }

        if not Path(audio_path).exists():
            logger.warning("Audio file not found: %s", audio_path)
            return {
                "score": 0.0,
                "detected_emotion": "neutral",
                "confidence": 0.0,
                "all_emotions": {},
                "metrics": {},
            }

        try:
            import torch
            import soundfile as sf
            import librosa

            audio_array, sr = sf.read(audio_path)
            audio_array = np.array(audio_array, dtype=np.float32).flatten()
            if sr != 16000:
                audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=16000)
                sr = 16000

            max_samples = 16000 * 10
            segments = []
            for start in range(0, len(audio_array), max_samples):
                seg = audio_array[start: start + max_samples]
                if len(seg) < 1600:
                    continue
                segments.append(seg)

            if not segments:
                logger.warning("No valid segments found in audio")
                return {
                    "score": 0.0,
                    "detected_emotion": "neutral",
                    "confidence": 0.0,
                    "all_emotions": {},
                    "metrics": {},
                }

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

            all_probs    = np.array(all_probs, dtype=np.float32)
            avg_probs    = np.mean(all_probs, axis=0)
            id2label     = self.audio_model.config.id2label
            predicted_id = np.argmax(avg_probs)

            detected_emotion   = id2label[predicted_id]
            emotion_confidence = float(avg_probs[predicted_id])

            all_emotions = {
                id2label[idx]: float(prob)
                for idx, prob in enumerate(avg_probs)
            }

            dominance  = float(np.max(avg_probs))
            entropy    = -np.sum(all_probs * np.log(all_probs + 1e-8), axis=1)
            num_classes = all_probs.shape[1]
            stability  = 1.0 - np.mean(entropy) / np.log(num_classes)
            peaks      = np.argmax(all_probs, axis=1)
            peak_counts = Counter(peaks)
            most_common_count = peak_counts.most_common(1)[0][1]
            consistency = float(np.clip(most_common_count / len(peaks), 0, 1))
            stability   = float(np.clip(stability, 0, 1))

            if expected_emotion is not None:
                match = detected_emotion.lower() == expected_emotion.lower()
                if match:
                    score = emotion_confidence * 100
                else:
                    expected_prob = 0.0
                    for idx, label in id2label.items():
                        if label.lower() == expected_emotion.lower():
                            expected_prob = float(avg_probs[idx])
                            break
                    score = expected_prob * 100
            else:
                score = (dominance * 0.5) + (stability * 0.3) + (consistency * 0.2)
                score = float(np.clip(score * 100, 0, 100))

            metrics = {
                "dominance":   dominance,
                "stability":   stability,
                "consistency": consistency,
            }

            logger.info(
                "Audio emotion: %s (conf=%.2f%%), score=%.2f, metrics=%s",
                detected_emotion, emotion_confidence * 100, score, metrics,
            )

            return {
                "score":            float(score),
                "detected_emotion": detected_emotion,
                "confidence":       emotion_confidence,
                "all_emotions":     all_emotions,
                "metrics":          metrics,
            }

        except Exception as e:
            logger.error("Audio emotion scoring failed: %s", e, exc_info=True)
            return {
                "score":            0.0,
                "detected_emotion": "neutral",
                "confidence":       0.0,
                "all_emotions":     {},
                "metrics":          {},
                "error":            str(e),
            }

    async def _score_audio_emotion_per_sentence(
        self,
        audio_path: str,
        sentences_aligned: List[Dict],
    ) -> Dict:
        """
        Score audio emotion per sentence using alignment data.

        Returns same structure as _score_audio_emotion plus:
            - sentence_results: list of per-sentence emotion detections
            - accuracy: percentage of sentences matching expected emotion
        """
        try:
            import soundfile as sf
            import librosa

            audio_array, sr = sf.read(audio_path)
            audio_array = np.array(audio_array, dtype=np.float32).flatten()
            if sr != 16000:
                audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=16000)
                sr = 16000

            sentence_results = []

            for sent in sentences_aligned:
                if sent["status"] == "missing" or sent["t_start"] is None:
                    logger.debug("Skipping missing sentence: %s...", sent["script_sentence"][:50])
                    sentence_results.append({
                        "sentence":         sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence":       0.0,
                        "score":            0.0,
                        "time_range":       "N/A",
                        "coverage":         sent.get("coverage", 0.0),
                        "status":           "missing",
                    })
                    continue
                start_sample = int(sent["t_start"] * sr)
                end_sample   = int(sent["t_end"] * sr)
                
                # Check if sentence is completely beyond audio file
                start_sample = min(start_sample, len(audio_array) - 1)
                end_sample = min(end_sample, len(audio_array))
                segment = audio_array[start_sample:end_sample]

                segment_duration  = len(segment) / sr
                expected_duration = sent["t_end"] - sent["t_start"]
                is_mostly_complete = segment_duration >= (expected_duration * 0.5)

                if len(segment) < 8000 and not is_mostly_complete:
                    logger.warning(
                        "Sentence %d too short: %.2fs (%d samples) | '%s...'",
                        len(sentence_results) + 1,
                        segment_duration, len(segment),
                        sent["script_sentence"][:40],
                    )
                    sentence_results.append({
                        "sentence":         sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence":       0.0,
                        "score":            0.0,
                        "time_range":       f"{sent['t_start']:.4f}s-{sent['t_end']:.4f}s",
                        "coverage":         sent.get("coverage", 1.0),
                        "status":           "too_short",
                    })
                    continue
                
                # Calculate actual duration in seconds
                segment_duration = len(segment) / sr
                
                logger.debug(
                    "Sentence %d slice: start_sample=%d end_sample=%d audio_len=%d segment_len=%d duration=%.2fs",
                    len(sentence_results) + 1,
                    start_sample, end_sample, len(audio_array), len(segment), segment_duration,
                )
                
                # Minimum: 0.5 seconds of audio
                # If segment is at end of file but still substantial, process it
                expected_duration = sent["t_end"] - sent["t_start"]
                is_end_of_file = end_sample >= len(audio_array)
                is_minimum_duration = segment_duration >= 0.5
                is_mostly_complete = segment_duration >= (expected_duration * 0.5)
                
                should_skip = len(segment) < 8000 and not (is_end_of_file and is_mostly_complete)
                
                if should_skip:
                    logger.warning(
                        "Sentence %d skipped (too short): %.2fs (%d samples) | t=%.1f-%.1f | '%s...'",
                        len(sentence_results) + 1,
                        segment_duration, len(segment),
                        sent["t_start"], sent["t_end"],
                        sent["script_sentence"][:40],
                    )
                    sentence_results.append({
                        "sentence":         sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence":       0.0,
                        "score":            0.0,
                        "time_range":       f"{sent['t_start']:.4f}s-{sent['t_end']:.4f}s",
                        "coverage":         sent.get("coverage", 1.0),
                        "status":           "too_short",
                    })
                    continue

                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                    sf.write(tmp.name, segment, sr)
                    tmp_path = tmp.name

                result = await self._score_audio_emotion(
                    tmp_path,
                    expected_emotion=sent.get("emotion"),
                )

                sentence_results.append({
                    "sentence":         sent["script_sentence"],
                    "expected_emotion": sent["emotion"],
                    "detected_emotion": result["detected_emotion"],
                    "confidence":       result["confidence"],
                    "score":            result["score"],
                    "time_range":       f"{sent['t_start']:.1f}s-{sent['t_end']:.1f}s",
                    "coverage":         sent.get("coverage", 1.0),
                    "status":           sent["status"],
                    "all_scores":       result.get("all_emotions", {}),
                })

                try:
                    Path(tmp_path).unlink()
                except Exception:
                    pass
           
            if not sentence_results:
                logger.warning("No valid sentences for emotion analysis, using whole file")
                return await self._score_audio_emotion(audio_path)        
            valid_results = [r for r in sentence_results if r["detected_emotion"] is not None]
            if valid_results:
                avg_score = sum(r["score"] for r in valid_results) / len(valid_results)
                emotions         = [r["detected_emotion"] for r in valid_results]
                dominant_emotion = Counter(emotions).most_common(1)[0][0]
                avg_confidence   = sum(r["confidence"] for r in valid_results) / len(valid_results)
            else:
                avg_score        = 0.0
                dominant_emotion = "neutral"
                avg_confidence   = 0.0
            matches = sum(
                1 for r in sentence_results
                if r["detected_emotion"] is not None
                and r["detected_emotion"].lower() == (r["expected_emotion"] or "").lower()
            )
         
            accuracy = matches / len(sentence_results) if sentence_results else 0.0

            logger.info(
                "Sentence-level emotion analysis: %d sentences (%d valid), accuracy=%.1f%%, dominant=%s",
                len(sentence_results), len(valid_results), accuracy * 100, dominant_emotion,
            )

            return {
                "score":            avg_score,
                "detected_emotion": dominant_emotion,
                "confidence":       avg_confidence,
                "sentence_results": sentence_results,
                "accuracy":         accuracy,
                "all_emotions":     {},
            }
   
         
        except Exception as e:
            logger.error("Sentence-level emotion scoring failed: %s", e, exc_info=True)
            return await self._score_audio_emotion(audio_path)
    
    async def _score_video_emotion_per_sentence(
        self,
        video_path: str,
        sentences_aligned: List[Dict],
    ) -> Dict:
        """
        Score video emotion per sentence using alignment data.
        
        Parameters
        ----------
        video_path : str
            Path to the video file
        sentences_aligned : List[Dict]
            List of sentences with timing information from script alignment
            Each dict has: content, emotion, t_start, t_end, coverage, status
        
        Returns
        -------
        Dict with keys:
            - score: float (0-100) - average score across valid sentences
            - detected_emotion: str - dominant emotion across sentences
            - confidence: float - average confidence across valid sentences
            - sentence_results: list - per-sentence emotion detections
            - accuracy: float - percentage of sentences matching expected emotion
            - all_emotions: dict - placeholder for consistency with audio function
        """
        if self.emotion_model is None:
            logger.warning("Video emotion model not loaded -- cannot score per sentence")
            return {
                "score": 0.0,
                "detected_emotion": "unknown",
                "confidence": 0.0,
                "sentence_results": [],
                "accuracy": 0.0,
                "all_emotions": {},
            }
        
        try:
            from tensorflow.keras.applications.efficientnet import preprocess_input
            
            sentence_results = []
            
            logger.info(
                "Starting video emotion scoring for %d sentences", len(sentences_aligned)
            )
            
            for sent_idx, sent in enumerate(sentences_aligned):
                if sent["status"] == "missing" or sent["t_start"] is None:
                    logger.debug("Skipping missing sentence %d: %s...", sent_idx, sent["script_sentence"][:50])
                    sentence_results.append({
                        "sentence": sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence": 0.0,
                        "score": 0.0,
                        "time_range": "N/A",
                        "coverage": sent.get("coverage", 0.0),
                        "status": "missing",
                    })
                    continue
                
                # Extract frames for this sentence's time range
                t_start = sent["t_start"]
                t_end = sent["t_end"]
                duration = t_end - t_start
                
                if duration < 0.2:  # Too short (< 200ms)
                    logger.warning(
                        "Sentence %d too short (%.2fs): '%s...'",
                        sent_idx, duration, sent["script_sentence"][:40]
                    )
                    sentence_results.append({
                        "sentence": sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence": 0.0,
                        "score": 0.0,
                        "time_range": f"{t_start:.1f}s-{t_end:.1f}s",
                        "coverage": sent.get("coverage", 1.0),
                        "status": "too_short",
                    })
                    continue
                
                # Extract frames for this time range
                frames = self._extract_frames_for_time_range(
                    video_path, t_start, t_end, num_frames=FRAMES_PER_VIDEO
                )
                
                if len(frames) == 0:
                    logger.warning(
                        "Sentence %d: no frames extracted for time range %.1f-%.1f",
                        sent_idx, t_start, t_end
                    )
                    sentence_results.append({
                        "sentence": sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence": 0.0,
                        "score": 0.0,
                        "time_range": f"{t_start:.1f}s-{t_end:.1f}s",
                        "coverage": sent.get("coverage", 1.0),
                        "status": "no_frames",
                    })
                    continue
                
                # Run emotion model on extracted frames
                try:
                    frames_norm = preprocess_input(frames * 255.0)
                    
                    # Pad or trim to FRAMES_PER_VIDEO
                    if len(frames_norm) < FRAMES_PER_VIDEO:
                        pad = np.zeros(
                            (FRAMES_PER_VIDEO - len(frames_norm), IMG_SIZE, IMG_SIZE, 3),
                            dtype=np.float32,
                        )
                        frames_norm = np.concatenate([frames_norm, pad], axis=0)
                    else:
                        frames_norm = frames_norm[:FRAMES_PER_VIDEO]
                    
                    input_batch = frames_norm[np.newaxis, ...]
                    probabilities = self.emotion_model.predict(input_batch, verbose=0)[0]
                    probabilities = np.array(probabilities, dtype=np.float64)
                    probabilities = probabilities / probabilities.sum()
                    
                    primary_idx = int(np.argmax(probabilities))
                    detected_emotion = EMOTION_NAMES[primary_idx]
                    confidence = float(probabilities[primary_idx])
                    score = round(confidence * 100, 2)
                    
                    logger.debug(
                        "Sentence %d emotion: %s (conf=%.2f%%), time=%.1f-%.1f",
                        sent_idx, detected_emotion, confidence * 100, t_start, t_end
                    )
                    
                    sentence_results.append({
                        "sentence": sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": detected_emotion,
                        "confidence": round(confidence, 4),
                        "score": score,
                        "time_range": f"{t_start:.1f}s-{t_end:.1f}s",
                        "coverage": sent.get("coverage", 1.0),
                        "status": sent.get("status", "ok"),
                        "all_emotions":     {       # ← add this
                            EMOTION_NAMES[i]: round(float(probabilities[i]), 4)
                            for i in range(NUM_CLASSES)
                        },
                    })
                    
                except Exception as e:
                    logger.error(
                        "Failed to score video emotion for sentence %d: %s", sent_idx, e
                    )
                    sentence_results.append({
                        "sentence": sent["script_sentence"],
                        "expected_emotion": sent.get("emotion"),
                        "detected_emotion": None,
                        "confidence": 0.0,
                        "score": 0.0,
                        "time_range": f"{t_start:.1f}s-{t_end:.1f}s",
                        "coverage": sent.get("coverage", 1.0),
                        "status": "error",
                    })
                    continue
            
            # Compute aggregate metrics
            if not sentence_results:
                logger.warning("No valid sentences for video emotion analysis")
                return {
                    "score": 0.0,
                    "detected_emotion": "unknown",
                    "confidence": 0.0,
                    "sentence_results": [],
                    "accuracy": 0.0,
                    "all_emotions": {},
                }
            
            valid_results = [r for r in sentence_results if r["detected_emotion"] is not None]
            
            if valid_results:
                avg_score = sum(r["score"] for r in valid_results) / len(valid_results)
                emotions = [r["detected_emotion"] for r in valid_results]
                dominant_emotion = Counter(emotions).most_common(1)[0][0]
                avg_confidence = sum(r["confidence"] for r in valid_results) / len(valid_results)
            else:
                avg_score = 0.0
                dominant_emotion = "neutral"
                avg_confidence = 0.0
            
            # Calculate accuracy (percentage matching expected emotion)
            matches = sum(
                1 for r in sentence_results
                if r["detected_emotion"] is not None
                and r["detected_emotion"].lower() == (r["expected_emotion"] or "").lower()
            )
            accuracy = matches / len(sentence_results) if sentence_results else 0.0
            
            logger.info(
                "Video emotion per-sentence analysis complete: %d sentences (%d valid), "
                "accuracy=%.1f%%, dominant=%s, avg_score=%.2f",
                len(sentence_results), len(valid_results), accuracy * 100,
                dominant_emotion, avg_score,
            )
            
            return {
                "score": round(avg_score, 2),
                "detected_emotion": dominant_emotion,
                "confidence": round(avg_confidence, 4),
                "sentence_results": sentence_results,
                "accuracy": round(accuracy, 4),
                "all_emotions": {},
            }
        
        except Exception as e:
            logger.error("Video emotion per-sentence scoring failed: %s", e, exc_info=True)
            return {
                "score": 0.0,
                "detected_emotion": "unknown",
                "confidence": 0.0,
                "sentence_results": [],
                "accuracy": 0.0,
                "all_emotions": {},
                "error": str(e),
            }

    # -----------------------------------------------------------------------
    # 3 -- Script alignment scoring (SeamlessM4T)
    # -----------------------------------------------------------------------
    async def _score_script_alignment_with_sentences(
        self,
        audio_path: str,
        script_text: str,
    ) -> Tuple[float, Optional[Dict]]:
        """
        Transcribe with remote SeamlessM4T API, align with script, and return both:
        - alignment score (0-100)
        - sentence-level alignment data for emotion detection
        """
        if self.script_model is None or self.script_processor is None:
            logger.warning("SeamlessM4T not loaded -- script alignment score = 0.")
            return 0.0, None

        if not script_text or not audio_path:
            logger.info("No script text or audio provided -- script score = 0.")
            return 0.0, None

        if not Path(audio_path).exists():
            logger.warning("Audio file not found: %s", audio_path)
            return 0.0, None

        try:
            import aiohttp
            import soundfile as sf
            import librosa

            logger.info("Sending audio to remote SeamlessM4T API...")
            # Guard: reject tiny/empty files before sending
            audio_size = Path(audio_path).stat().st_size
            if audio_size < 8000:
                logger.warning("Audio file too small (%d bytes), skipping ASR", audio_size)
                return 0.0, None
            try:
                async with aiohttp.ClientSession() as health_session:
                    health_url = self.script_model.replace("/transcribe", "/health")
                    async with health_session.get(
                        health_url,
                        timeout=aiohttp.ClientTimeout(connect=10, sock_read=10)
                    ) as r:
                        logger.info("SeamlessM4T health check: %s", await r.text())
            except Exception as e:
                logger.error("SeamlessM4T API unreachable: %s", e)
                return 0.0, None
            async with aiohttp.ClientSession() as session:
                with open(audio_path, "rb") as f:
                    form = aiohttp.FormData()
                    form.add_field(
                        "audio", f,
                        filename="audio.wav",
                        content_type="audio/wav",
                    )
                    async with session.post(
                        self.script_model,
                        data=form,
                        timeout=aiohttp.ClientTimeout(
                            connect=30,
                            sock_read=1800,
                            ),
                    ) as resp:
                        if resp.status != 200:
                           logger.error("Remote ASR API error: %s", await resp.text())
                           return 0.0, None
                        api_result = await resp.json()

            full_transcript = api_result.get("text", "")
            aligned_words   = api_result.get("aligned_words", [])
            if not full_transcript:
                logger.warning("Empty transcript from remote API")
                return 0.0, None

            transcript_clean = _normalize_text(full_transcript).split()
            sentences        = self._parse_script(script_text)

            sentences = self._parse_script(script_text)

            script_words     = []
            word_to_sentence = []
            for sent_idx, sent in enumerate(sentences):
                words = _normalize_text(sent["script_sentence"]).split()
                script_words.extend(words)
                word_to_sentence.extend([sent_idx] * len(words))

            if not script_words:
                return 0.0, None

            matcher = difflib.SequenceMatcher(None, script_words, transcript_clean)

            sentence_word_counts = [
                len(_normalize_text(s["script_sentence"]).split()) for s in sentences
            ]
            sentence_coverage = [0] * len(sentences)

            # Per-sentence comparison rows: each entry is a word-level diff row
            # keyed by sentence index so they can be attached to sentences_aligned later
            sentence_comparison_rows: list[list[dict]] = [[] for _ in sentences]

            # Global word-level stats
            matched_words_count = 0
            changed_words_count = 0
            skipped_words_count = 0
            added_words_count   = 0
            matched_words_array=[]
            changed_words_array=[]
            skipped_words_array=[]
            added_words_array=[]
            

            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag == "equal":
                    for k in range(i2 - i1):
                        s_idx = word_to_sentence[i1 + k]
                        sentence_coverage[s_idx] += 1
                        sentence_comparison_rows[s_idx].append({
                            "status":          "match",
                            "script_word":     script_words[i1 + k],
                            "transcript_word": transcript_clean[j1 + k],
                        })
                        matched_words_count += 1
                        matched_words_array.append(script_words[i1 + k])
                elif tag == "replace":
                    for k in range(max(i2 - i1, j2 - j1)):
                        s_w = script_words[i1 + k]     if i1 + k < i2 else ""
                        t_w = transcript_clean[j1 + k] if j1 + k < j2 else ""
                        status = "changed" if s_w and t_w else ("skipped" if s_w else "added")
                        # Attribute to the script-side sentence when available,
                        # otherwise fall back to the last script sentence
                        if i1 + k < i2:
                            s_idx = word_to_sentence[i1 + k]
                        else:
                            s_idx = word_to_sentence[i2 - 1]
                        sentence_comparison_rows[s_idx].append({
                            "status":          status,
                            "script_word":     s_w or "-",
                            "transcript_word": t_w or "-",
                        })
                        changed_words_count += 1
                        changed_words_array.append(f"{s_w} -> {t_w}")
                elif tag == "delete":
                    for k in range(i2 - i1):
                        s_idx = word_to_sentence[i1 + k]
                        sentence_comparison_rows[s_idx].append({
                            "status":          "skipped",
                            "script_word":     script_words[i1 + k],
                            "transcript_word": "-",
                        })
                        skipped_words_count += 1
                        skipped_words_array.append(script_words[i1 + k])
                elif tag == "insert":
                    for k in range(j2 - j1):
                        # Inserted words have no script position; attach to the sentence
                        # that owns the script word just before this insertion point.
                        s_idx = word_to_sentence[i1 - 1] if i1 > 0 else 0
                        sentence_comparison_rows[s_idx].append({
                            "status":          "added",
                            "script_word":     "-",
                            "transcript_word": transcript_clean[j1 + k],
                        })
                        added_words_count += 1
                        added_words_array.append(transcript_clean[j1 + k])
            total_matched   = sum(size for _, _, size in matcher.get_matching_blocks())
            overall_coverage = total_matched / len(script_words) if script_words else 0
            score            = round(min(overall_coverage, 1.0) * 100, 2)
            total_duration   = sf.info(audio_path).duration
            
            # ------------------------------------------------------------------ #
            # Build sentence-level output: timestamps + per-sentence transcript  #
            # ------------------------------------------------------------------ #
            sentences_aligned = []
            word_idx = 0  # pointer into aligned_words

            for s_idx, sent in enumerate(sentences):
                sent_words    = _normalize_text(sent["script_sentence"]).split()
                word_count    = len(sent_words)
                matched_count = sentence_coverage[s_idx]
                coverage      = matched_count / word_count if word_count > 0 else 0.0
                sent_score    = round(min(coverage, 1.0) * 100, 2)

                # Reconstruct what the actor actually said for this sentence's span,
                # preserving word order from the diff rows
                rows = sentence_comparison_rows[s_idx]
                transcript_words_for_sentence = [
                    r["transcript_word"]
                    for r in rows
                    if r["transcript_word"] != "-"
                ]
                sentence_transcript = " ".join(transcript_words_for_sentence)

                # Collect the next `word_count` aligned word timestamps
                sent_aligned = aligned_words[word_idx : word_idx + word_count]
                word_idx    += word_count

                usable_times = [w["start"] for w in sent_aligned if "start" in w]

                if not usable_times:
                    sentences_aligned.append({
                        "sentence_index":      s_idx,
                        "script_sentence":     sent["script_sentence"],
                        "transcript_sentence": sentence_transcript,
                        "emotion":             sent["emotion"],
                        "t_start":             None,
                        "t_end":               None,
                        "coverage":            coverage,
                        "sentence_score":      sent_score,
                        "status":              "missing",
                        "word_diff":           rows,
                    })
                    continue

                t_start = min(usable_times)

                next_aligned = aligned_words[word_idx : word_idx + 1]
                if next_aligned and "start" in next_aligned[0]:
                    t_end = (max(usable_times) + next_aligned[0]["start"]) / 2.0
                else:
                    t_end = total_duration

                t_start = max(0.0, t_start)
                t_end   = min(total_duration, t_end)
                if t_end <= t_start:
                    t_end = min(t_start + 0.5, total_duration)

                sentences_aligned.append({
                    "sentence_index":      s_idx,
                    "script_sentence":     sent["script_sentence"],
                    "transcript_sentence": sentence_transcript,
                    "emotion":             sent["emotion"],
                    "t_start":             round(t_start, 4),
                    "t_end":               round(t_end,   4),
                    "coverage":            round(coverage, 3),
                    "sentence_score":      sent_score,
                    "status":              "ok" if coverage >= 0.5 else "partial",
                    "word_diff":           rows,
                })

            logger.info(
                "Script alignment -- matched=%d / total=%d -> score=%.2f, %d sentences",
                total_matched, len(script_words), score, len(sentences_aligned),
            )

            return score, {
                "sentences_aligned": sentences_aligned,   # primary output: one entry per sentence
                "transcript":        full_transcript,
                "coverage":          overall_coverage,
                "matched_words":     matched_words_array,
                "added_words":       added_words_array,
                "changed_words":     changed_words_array,
                "skipped_words":     skipped_words_array,
                "matched_count":     matched_words_count,
                "added_count":       added_words_count,
                "changed_count":     changed_words_count,
                "skipped_count":     skipped_words_count,
            }

        except Exception as e:
            logger.error("Script alignment scoring failed: %s", e, exc_info=True)
            return 0.0, None
    def _parse_script(self, script_text: str) -> List[Dict]:
        """
        Parse script into sentences with emotion labels.

        Accepts two formats:

        Format 1 (preferred) -- JSON array string:
            '[{"content": "sentence", "emotion": "angry"}, ...]'

        Format 2 (legacy) -- plain text with inline emotion tags:
            Sentence text "emotion"

        Returns list of {content: str, emotion: str}
        """
        script_text = script_text.strip()

        # ── Format 1: JSON array ─────────────────────────────────────────
        if script_text.startswith("["):
            try:
                data = json.loads(script_text)
                sentences = []
                for item in data:
                    content = str(item.get("content", "")).strip()
                    emotion = str(item.get("emotion", "neutral")).strip().lower()
                    if content:
                        sentences.append({"script_sentence": content, "emotion": emotion})
                if sentences:
                    logger.info("Parsed script as JSON array: %d sentences", len(sentences))
                    return sentences
            except json.JSONDecodeError as e:
                logger.warning("Script looked like JSON but failed to parse: %s", e)

        # ── Format 2: Legacy plain-text with inline "emotion" tags ───────
        sentences = []
        for line in script_text.split("\n"):
            if not line.strip():
                continue
            match = re.search(r'"([^"]+)"', line)
            if match:
                emotion = match.group(1).lower()
                content = line[: match.start()].strip()
            else:
                content = line.strip()
                emotion = "neutral"
            if content:
                sentences.append({"content": content, "emotion": emotion})

        logger.info("Parsed script as plain text: %d sentences", len(sentences))
        return sentences

    async def _score_script_alignment(
        self,
        audio_path: Optional[str],
        script_text: Optional[str],
    ) -> float:
        """Simple version that just returns the score (for backward compatibility)."""
        score, _ = await self._score_script_alignment_with_sentences(audio_path, script_text)
        return score

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
        """Build a human-readable feedback string based on real scores."""
        lines = []

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
        if 0 < script < 50:
            lines.append(
                "Script Alignment: Memorise the script more thoroughly. "
                "Several words or phrases were missed or changed."
            )

        return "  ".join(lines)