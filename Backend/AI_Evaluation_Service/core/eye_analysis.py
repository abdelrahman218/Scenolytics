# -*- coding: utf-8 -*-
"""
Eye Analysis Wrapper — Bridges Eye.py functionality with ml_pipeline.py

This module provides a clean interface to the eye movement analysis pipeline,
orchestrating the workflow from quality reports and iris series through to
final scoring and results.
"""

import logging
import json
from typing import Dict, List, Optional, Tuple
import numpy as np
import cv2

logger = logging.getLogger(__name__)

# Import the core Eye.py functions
try:
    from core.Eye import (
        run_ear_and_iris_extraction,
        run_baseline_establishment,
        run_normalization,
        run_eye_openness_scoring,
        calibrate_gaze_centre,
        classify_gaze,
        find_emotion_transitions,
        measure_gaze_shifts,
        normalize_emotion_timeline,
        export_final_analysis_json,
        visualize_gaze_transitions,
    )
except ImportError:
    # Fallback for relative imports
    from Eye import (
        run_ear_and_iris_extraction,
        run_baseline_establishment,
        run_normalization,
        run_eye_openness_scoring,
        calibrate_gaze_centre,
        classify_gaze,
        find_emotion_transitions,
        measure_gaze_shifts,
        normalize_emotion_timeline,
        export_final_analysis_json,
        visualize_gaze_transitions,
    )


def build_emotion_timeline_from_sentences(
    sentences_aligned: List[Dict],
) -> List[Dict]:
    """
    Convert sentence alignment data to emotion timeline format.

    Parameters
    ----------
    sentences_aligned : list of dicts with keys:
        - content: sentence text
        - emotion: expected emotion
        - t_start, t_end: time in seconds
        - coverage: alignment quality

    Returns
    -------
    emotion_timeline : list of dicts with keys:
        - start_sec, end_sec, emotion, sentence
    """
    if not sentences_aligned:
        return []

    timeline = []
    for sent in sentences_aligned:
        if sent.get("status") == "missing" or sent.get("t_start") is None:
            continue

        timeline.append({
            "start_sec": float(sent["t_start"]),
            "end_sec":   float(sent["t_end"]),
            "emotion":   sent.get("emotion", "neutral").lower(),
            "sentence":  sent.get("content", ""),
        })

    return timeline


def analyze_eye_expression(
    quality_report: Dict,
    iris_series: List[Dict],
    video_path: str,
    sentences_aligned: Optional[List[Dict]] = None,
    evaluation_id: Optional[str] = None,
) -> Dict:
    """
    Comprehensive eye expression analysis pipeline.

    Orchestrates the workflow:
    1. Calibrate gaze centre from iris series
    2. Detect emotion transitions (if sentences provided)
    3. Generate before/after images for each transition
    4. Merge image paths into transitions
    5. Score overall eye expression

    Parameters
    ----------
    quality_report : dict
        Video quality report from _extract_mediapipe_landmarks
        with keys: video_is_usable, usable_ratio, frame_height, frame_width, etc.
    iris_series : list of dicts
        Iris movement data with keys: timestamp_ms, h_ratio, v_ratio, landmarks
    video_path : str
        Path to the video file
    sentences_aligned : list of dicts, optional
        Sentence-level alignment data from script transcription
        Each dict has: content, emotion, t_start, t_end, coverage, status
    evaluation_id : str, optional
        Identifier for this evaluation (for logging/tracking)

    Returns
    -------
    dict with keys:
        - score: float 0-100
        - result: str (NEUTRAL, SUBTLE, MODERATELY_EXPRESSIVE, EXPRESSIVE)
        - message: human-readable explanation
        - transitions: list of detected gaze/emotion transitions
    """
    logger.info("Starting eye expression analysis (eval_id=%s)", evaluation_id or "unknown")

    # Initialize defaults before try block so except can always reference them
    transitions_result = []
    gaze_shift_score   = 0.0
    center_h           = 0.5
    center_v           = 0.5
    h_tol              = 0.02
    v_tol              = 0.02

    try:
        # Validate inputs
        if not quality_report or not iris_series:
            logger.warning("Missing quality_report or iris_series")
            return _fallback_result("NEUTRAL", 0.0, "Insufficient eye tracking data")

        if not quality_report.get("video_is_usable"):
            logger.warning(
                "Video quality too low for reliable analysis (%.1f%% usable)",
                quality_report.get("usable_ratio", 0) * 100,
            )

        # Step 1: Calibrate gaze centre
        center_h, center_v, h_tol, v_tol = calibrate_gaze_centre(iris_series)
        logger.debug(
            "Gaze centre: H=%.3f±%.3f, V=%.3f±%.3f",
            center_h, h_tol, center_v, v_tol,
        )

        # Step 2: Detect emotion transitions and measure gaze shifts
        if sentences_aligned:
            emotion_timeline = build_emotion_timeline_from_sentences(sentences_aligned)
            if emotion_timeline:
                logger.debug("Built emotion timeline from %d sentences", len(emotion_timeline))

                emotion_transitions = find_emotion_transitions(emotion_timeline)
                if emotion_transitions:
                    transitions_result, gaze_shift_score = measure_gaze_shifts(
                        iris_series,
                        emotion_transitions,
                        center_h, center_v, h_tol, v_tol,
                        window_sec=2.0,
                    )
                    logger.info(
                        "Detected %d emotion transitions, gaze shift score=%.2f",
                        len(transitions_result), gaze_shift_score,
                    )

        # Fall back to general gaze variability if no sentence-level data
        if not transitions_result:
            transitions_result = _analyze_gaze_variability(
                iris_series, center_h, center_v, h_tol, v_tol, video_path
            )

        # Step 3: Generate before/after images for each transition
        # (must happen AFTER transitions_result is fully populated)
        image_map = _generate_transition_images(
            quality_report=quality_report,
            iris_series=iris_series,
            transitions=transitions_result,
            center_h=center_h,
            center_v=center_v,
            h_tol=h_tol,
            v_tol=v_tol,
            video_path=video_path,
        )

        # Step 4: Merge image paths into each transition dict
        for t in transitions_result:
            images = image_map.get(t.get("time_ms"), {})
            t["before_image"]       = images.get("before_image")
            t["after_image"]        = images.get("after_image")
            t["image_aspect_ratio"] = images.get("image_aspect_ratio")

        # Step 5: Score overall expressiveness
        score, result, message = _score_eye_expression(
            iris_series, transitions_result, gaze_shift_score, quality_report
        )

        # Step 6: Clean transitions for UI (removes internal fields)
        transitions_for_ui = _clean_transitions_for_ui(transitions_result)

        final_result = {
            "score":       round(score, 2),
            "result":      result,
            "message":     message,
            "transitions": transitions_for_ui,
        }

        logger.info(
            "Eye analysis complete: score=%.2f, result=%s, transitions=%d (eval_id=%s)",
            score, result, len(transitions_result), evaluation_id or "unknown",
        )

        return final_result

    except Exception as e:
        logger.error("Eye expression analysis failed: %s", e, exc_info=True)
        return _fallback_result("ERROR", 0.0, f"Analysis failed: {str(e)}")


def _clean_transitions_for_ui(transitions: List[Dict]) -> List[Dict]:
    """
    Filter transition objects to only include UI-required fields.
    Removes internal analysis fields like h_before, v_before, vol_before, vol_after, etc.
    """
    required_fields = {
        "time_sec", "time_ms",
        "from_emotion", "to_emotion",
        "from_sentence", "to_sentence",
        "label", "score", "displacement",
        "dir_before", "dir_after",
        "message", "before_image", "after_image", "image_aspect_ratio",
    }

    cleaned = []
    for t in transitions:
        cleaned_transition = {k: v for k, v in t.items() if k in required_fields}

        # Ensure at least time_sec or time_ms exists
        if "time_sec" not in cleaned_transition and "time_ms" not in cleaned_transition:
            continue

        cleaned.append(cleaned_transition)

    return cleaned


def _generate_transition_images(
    quality_report: Dict,
    iris_series: List[Dict],
    transitions: List[Dict],
    center_h: float,
    center_v: float,
    h_tol: float,
    v_tol: float,
    video_path: str,
) -> Dict:
    """
    Generate before/after images for transitions and return image_map.
    Returns dict mapping time_ms to {before_image, after_image, image_aspect_ratio}.
    """
    try:
        # Compute aspect ratio from quality report
        fw = quality_report.get("frame_width",  1)
        fh = quality_report.get("frame_height", 1)
        image_aspect_ratio = round(fw / fh, 4) if fh > 0 else 1.0

        raw_image_map = visualize_gaze_transitions(
            report=quality_report,
            iris_series=iris_series,
            results=transitions,
            center_h=center_h,
            center_v=center_v,
            h_tol=h_tol,
            v_tol=v_tol,
            video_path=video_path,
            window_sec=2.0,
        )

        # Attach aspect ratio to every entry
        image_map = {
            time_ms: {
                "before_image":       paths.get("before_image"),
                "after_image":        paths.get("after_image"),
                "image_aspect_ratio": image_aspect_ratio,
            }
            for time_ms, paths in raw_image_map.items()
        }

        logger.debug("Generated transition images for %d transitions", len(image_map))
        return image_map

    except Exception as e:
        logger.warning("Failed to generate transition images: %s", e)
        return {}


def _analyze_gaze_variability(
    iris_series: List[Dict],
    center_h: float,
    center_v: float,
    h_tol: float,
    v_tol: float,
    video_path: str,
) -> List[Dict]:
    """
    Fallback analysis based on gaze variability when no emotion timeline is provided.
    """
    transitions = []
    prev_gaze    = None
    prev_time_ms = None

    for iris_data in iris_series:
        ts_ms = iris_data["timestamp_ms"]
        gaze  = classify_gaze(
            iris_data["h_ratio"],
            iris_data["v_ratio"],
            center_h, center_v, h_tol, v_tol,
        )

        if prev_gaze is not None and gaze != prev_gaze:
            time_sec = round(ts_ms / 1000.0, 2)
            transitions.append({
                "time_sec":     time_sec,
                "time_ms":      int(ts_ms),
                "from_emotion": prev_gaze,
                "to_emotion":   gaze,
                "from_sentence": None,
                "to_sentence":   None,
                "label":        "GAZE_CHANGE",
                "score":        50.0,
                "displacement": 0.01,
                "dir_before":   prev_gaze,
                "dir_after":    gaze,
                "message":      f"Gaze shift from {prev_gaze} to {gaze}",
                "before_image": None,
                "after_image":  None,
                "image_aspect_ratio": None,
            })

        prev_gaze    = gaze
        prev_time_ms = ts_ms

    return transitions


def _score_eye_expression(
    iris_series: List[Dict],
    transitions: List[Dict],
    gaze_shift_score: float,
    quality_report: Dict,
) -> Tuple[float, str, str]:
    """
    Compute overall eye expression score and classification.
    """
    h_vals = np.array([f["h_ratio"] for f in iris_series])
    v_vals = np.array([f["v_ratio"] for f in iris_series])

    h_variability     = float(np.std(h_vals))
    v_variability     = float(np.std(v_vals))
    total_variability = np.sqrt(h_variability**2 + v_variability**2)

    num_transitions = len(transitions)

    # Base score from variability
    base_score = max(0.0, (total_variability - 0.02) * 100)

    # Adjust based on transitions
    if gaze_shift_score > 0:
        score = (base_score * 0.3) + (gaze_shift_score * 0.7)
    elif num_transitions == 0:
        score = base_score * 0.5
    else:
        score = base_score + (num_transitions * 3)

    score = float(np.clip(score, 0.0, 100.0))

    # Classify result
    if num_transitions == 0:
        result  = "NEUTRAL"
        message = "Eyes maintained consistent gaze — minimal expression"
    elif num_transitions <= 2:
        result  = "SUBTLE"
        message = "Subtle gaze movements detected — understated expression"
    elif num_transitions <= 5:
        result  = "MODERATELY_EXPRESSIVE"
        message = f"Multiple gaze movements ({num_transitions}) — moderate expression"
    else:
        result  = "EXPRESSIVE"
        message = f"Frequent gaze shifts ({num_transitions}) — strong physical expression"

    return score, result, message


def _generate_overall_message(
    score: float,
    result: str,
    quality_report: Dict,
) -> str:
    """Generate a comprehensive human-readable message."""
    quality_str  = ""
    usable_ratio = quality_report.get("usable_ratio", 0)

    if usable_ratio < 0.5:
        quality_str = " (Note: Low video quality may affect accuracy)"
    elif usable_ratio < 0.7:
        quality_str = " (Note: Moderate video quality)"

    messages = {
        "NEUTRAL":               f"Eyes showed minimal movement, indicating restrained expression.{quality_str}",
        "SUBTLE":                f"Eyes showed subtle shifts, suggesting reserved but present expressiveness.{quality_str}",
        "MODERATELY_EXPRESSIVE": f"Eyes demonstrated moderate movement and engagement.{quality_str}",
        "EXPRESSIVE":            f"Eyes were highly expressive with frequent shifts, showing strong engagement.{quality_str}",
        "ERROR":                 "Eye analysis could not be completed due to technical issues.",
    }

    return messages.get(result, f"Eye expression score: {score}/100{quality_str}")


def _fallback_result(
    result: str,
    score: float,
    message: str,
) -> Dict:
    """Return a fallback analysis result."""
    return {
        "score":       round(score, 2),
        "result":      result,
        "message":     message,
        "transitions": [],
        "gaze_shift_score": None,
        "quality_info": {
            "usable_ratio":  0.0,
            "total_frames":  0,
            "usable_frames": 0,
        },
        "overall_message": message,
    }