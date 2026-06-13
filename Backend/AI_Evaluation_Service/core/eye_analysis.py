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
            "sentence":  sent.get("script_sentence") or sent.get("content", ""),
        })

    return timeline


def analyze_eye_expression(
    quality_report: Dict,
    iris_series: List[Dict],
    video_path: str,
    sentences_aligned: Optional[List[Dict]] = None,
    evaluation_id: Optional[str] = None,
) -> Dict:
    logger.info("Starting eye expression analysis (eval_id=%s)", evaluation_id or "unknown")

    RESULT_MAP = {
        "expressive": "EXPRESSIVE",
        "subtle":     "SUBTLE",
        "flat":       "NEUTRAL",
    }

    try:
        if not quality_report or not iris_series:
            return _fallback_result("NEUTRAL", 0.0, "Insufficient eye tracking data")

        # ── Step 2: EAR + iris extraction ──────────────────────────────
        ear_time_series, _ = run_ear_and_iris_extraction(quality_report)
        if ear_time_series is None:
            return _fallback_result("NEUTRAL", 0.0, "EAR extraction failed")

        # ── Step 3: Baseline ────────────────────────────────────────────
        eye_profile = run_baseline_establishment(ear_time_series)
        if eye_profile is None:
            return _fallback_result("NEUTRAL", 0.0, "Baseline establishment failed")

        # ── Step 4: Normalization ───────────────────────────────────────
        normalized_series = run_normalization(ear_time_series, eye_profile)
        if normalized_series is None:
            return _fallback_result("NEUTRAL", 0.0, "Normalization failed")

        # ── Step 5A: Expressiveness score (THE score) ───────────────────
        expressive_result = run_eye_openness_scoring(normalized_series, eye_profile)
        if expressive_result is None:
            return _fallback_result("NEUTRAL", 0.0, "Openness scoring failed")

        score   = expressive_result["score"]
        result  = RESULT_MAP.get(expressive_result["result"].lower(), "NEUTRAL")
        message = expressive_result["message"]

        logger.debug(
            "Eye openness: score=%.1f, result=%s, avg_deviation=%.2f, "
            "strong_threshold=%.2f, weak_threshold=%.2f",
            score, result,
            expressive_result["avg_deviation"],
            expressive_result["strong_threshold"],
            expressive_result["weak_threshold"],
        )

        # ── Step 5B: Gaze calibration ───────────────────────────────────
        center_h, center_v, h_tol, v_tol = calibrate_gaze_centre(iris_series)

        # ── Step 5C: Emotion transitions ────────────────────────────────
        transitions_result = []
        gaze_shift_score   = 0.0

        if sentences_aligned:
            emotion_timeline = build_emotion_timeline_from_sentences(sentences_aligned)
            if emotion_timeline:
                emotion_transitions = find_emotion_transitions(emotion_timeline)

                if emotion_transitions:
                    # ── Step 5D: Measure gaze shifts ────────────────────
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

        # ── Step 5E: Before/after images ────────────────────────────────
        if transitions_result:
            image_map = visualize_gaze_transitions(
                report=quality_report,
                iris_series=iris_series,
                results=transitions_result,
                center_h=center_h,
                center_v=center_v,
                h_tol=h_tol,
                v_tol=v_tol,
                video_path=video_path,
                window_sec=2.0,
                evaluation_id=evaluation_id,
            )

            fw = quality_report.get("frame_width",  1)
            fh = quality_report.get("frame_height", 1)
            image_aspect_ratio = round(fw / fh, 4) if fh > 0 else 1.0

            for t in transitions_result:
                images = image_map.get(t.get("time_ms"), {})
                t["before_image"]       = images.get("before_image")
                t["after_image"]        = images.get("after_image")
                t["image_aspect_ratio"] = image_aspect_ratio

        # ── Final output ─────────────────────────────────────────────────
        transitions_for_ui = _clean_transitions_for_ui(transitions_result)

        logger.info(
            "Eye analysis complete: score=%.2f, result=%s, transitions=%d (eval_id=%s)",
            score, result, len(transitions_result), evaluation_id or "unknown",
        )

        return {
            "score":       round(score, 2),
            "result":      result,
            "message":     message,
            "transitions": transitions_for_ui,
        }

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