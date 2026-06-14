# tone_analysis_api.py
# Add this to your ml_pipeline.py or as a standalone module

import numpy as np
import librosa
from typing import List, Dict, Optional

EMOTION_RANGES: Dict[str, Dict[str, tuple]] = {
    "calm":      {"pitch": (15,  45),  "loudness": (2,   8)},
    "happy":     {"pitch": (50, 100),  "loudness": (6,  16)},
    "sad":       {"pitch": (25,  70),  "loudness": (2,   9)},
    "angry":     {"pitch": (55, 100),  "loudness": (10, 20)},
    "surprised": {"pitch": (55, 110),  "loudness": (8,  20)},
}
 
# Fallback if an unknown emotion label arrives
_DEFAULT_RANGE = {"pitch": (20, 150), "loudness": (4, 18)}
 
 
def _range_score(value: float, low: float, high: float) -> float:
    """
    Score a single measured value against an expected [low, high] range.
 
    - Inside the range            → 1.0  (perfect)
    - Below low (too little)      → falls off linearly to 0 at value=0
    - Above high (too much / too erratic) → falls off linearly, capped at 0
      when value >= high * 2
 
    Returns a float in [0.0, 1.0].
    """
    if low <= value <= high:
        return 1.0
    if value < low:
        # linearly ramp from 0 (at value=0) to 1 (at value=low)
        return max(0.0, value / low) if low > 0 else 0.0
    # value > high: linearly decay from 1 (at value=high) to 0 (at value=high*2)
    ceiling = high * 2
    return max(0.0, 1.0 - (value - high) / (ceiling - high)) if ceiling > high else 0.0
 
 
def _score_segment(segment: Dict) -> float:
    """
    Score a single tone segment against its emotion's expected ranges.
 
    Pitch is weighted 60 % and loudness 40 % because pitch variation is a
    stronger carrier of emotional expression than loudness alone.
 
    Returns a float in [0.0, 1.0].
    """
    emotion = segment.get("emotion", "neutral").lower()
    ranges  = EMOTION_RANGES.get(emotion, _DEFAULT_RANGE)
 
    pitch_score    = _range_score(segment["pitch_variation"],    *ranges["pitch"])
    loudness_score = _range_score(segment["loudness_variation"], *ranges["loudness"])
 
    return pitch_score * 0.6 + loudness_score * 0.4
 
 
def compute_tone_score(tone_result: Optional[Dict]) -> float:
    """
    Compute an overall vocal tone score (0–100) from the output of
    analyze_tone(), using per-segment emotion-aware scoring.
 
    Each segment is scored against the expected pitch/loudness ranges for its
    emotion label.  Segments are weighted equally (can be extended to weight
    by duration if needed).
 
    Args:
        tone_result: dict returned by analyze_tone(), or None.
 
    Returns:
        float in [0.0, 100.0], rounded to 2 decimal places.
        Returns 0.0 if tone_result is None or has no segments.
    """
    if not tone_result:
        return 0.0
 
    segments = tone_result.get("segments", [])
    if not segments:
        return 0.0
 
    segment_scores = [_score_segment(seg) for seg in segments]
    overall = float(np.mean(segment_scores))
    return round(overall * 100, 2)
 
 
def analyze_tone(
    audio_path: str,
    sentences_aligned: Optional[List[Dict]] = None,
) -> Dict:
    """
    Analyze pitch and loudness variation per sentence.

    Parameters
    ----------
    audio_path : str
        Path to the audio file (WAV, MP3, etc.)
    sentences_aligned : list of dicts, optional
        Each dict has: content, t_start, t_end, emotion, status
        If None, analyzes the whole file as one segment.

    Returns
    -------
    dict with keys:
        - segments: list of ToneSegment dicts
        - overall_pitch_variation: float
        - overall_loudness_variation: float
    """
    FRAME_LEN = 2048
    HOP       = 512

    y, sr = librosa.load(audio_path, sr=None, mono=True)
    y        = np.array(y, dtype=np.float32)
    duration = len(y) / sr

    # Build segments from sentences_aligned or use full audio
    if sentences_aligned:
        segments_def = [
            {
                "start":   s["t_start"],
                "end":     s["t_end"],
                "content": s.get("content") or s.get("script_sentence", ""),
                "emotion": s.get("emotion", "neutral"),
            }
            for s in sentences_aligned
            if s.get("t_start") is not None and s.get("t_end") is not None
        ]
    else:
        segments_def = [{"start": 0.0, "end": duration, "content": "", "emotion": "neutral"}]

    results = []

    for i, seg_def in enumerate(segments_def):
        start = max(0.0,     float(seg_def["start"]))
        end   = min(duration, float(seg_def["end"]))

        if end <= start:
            results.append(_empty_segment(i, seg_def))
            continue

        start_idx = int(start * sr)
        end_idx   = int(end   * sr)
        seg_audio = y[start_idx:end_idx]

        # Loudness variation
        rms      = librosa.feature.rms(y=seg_audio, frame_length=FRAME_LEN, hop_length=HOP)[0]
        rms_norm = rms / (rms.max() + 1e-9)
        loudness_variation = float(np.std(librosa.amplitude_to_db(rms, ref=np.max)))

        # Pitch variation (voiced frames only)
        f0, voiced_flag, _ = librosa.pyin(
            seg_audio,
            fmin=librosa.note_to_hz('C2'),
            fmax=librosa.note_to_hz('C7'),
            frame_length=FRAME_LEN,
            hop_length=HOP,
        )
        f0v = f0[voiced_flag & ~np.isnan(f0)]
        q1, q3 = np.percentile(f0v, [10, 90])  
        f0_clipped = f0v[(f0v >= q1) & (f0v <= q3)]
        pitch_variation = float(np.std(f0_clipped)) if len(f0_clipped) > 1 else 0.0


        # Label
        content = str(seg_def.get("content", "")).strip()
        label   = (content[:28] + "...") if len(content) > 28 else content
        label   = f"S{i + 1}: {label}" if label else f"S{i + 1}: {start:.2f}-{end:.2f}s"

        results.append({
            "index":              i,
            "label":              label,
            "t_start":            round(start, 3),
            "t_end":              round(end,   3),
            "content":            content,
            "emotion":            seg_def.get("emotion", "neutral"),
            "pitch_variation":    round(pitch_variation,    2),   # Hz
            "loudness_variation": round(loudness_variation, 2),   # dB
        })

    # Overall stats
    pitch_vals    = [r["pitch_variation"]    for r in results]
    loudness_vals = [r["loudness_variation"] for r in results]

    return {
        "segments":                   results,
        "overall_pitch_variation":    round(float(np.mean(pitch_vals)),    2) if pitch_vals    else 0.0,
        "overall_loudness_variation": round(float(np.mean(loudness_vals)), 2) if loudness_vals else 0.0,
        "seg_labels":                 [r["label"]              for r in results],
        "pitch_variation":            [r["pitch_variation"]    for r in results],
        "loudness_variation":         [r["loudness_variation"] for r in results],
    }


def _empty_segment(index: int, seg_def: Dict) -> Dict:
    return {
        "index":              index,
        "label":              f"S{index + 1}",
        "t_start":            seg_def.get("start", 0.0),
        "t_end":              seg_def.get("end",   0.0),
        "content":            seg_def.get("content", ""),
        "emotion":            seg_def.get("emotion", "neutral"),
        "pitch_variation":    0.0,
        "loudness_variation": 0.0,
    }