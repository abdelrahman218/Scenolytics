# tone_analysis_api.py
# Add this to your ml_pipeline.py or as a standalone module

import numpy as np
import librosa
from typing import List, Dict, Optional


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
        f0     = librosa.yin(
            seg_audio,
            fmin=librosa.note_to_hz('C2'),
            fmax=librosa.note_to_hz('C7'),
            frame_length=FRAME_LEN,
            hop_length=HOP,
        )
        voiced = (f0 > 60) & (rms_norm[:len(f0)] > 0.05)
        f0v    = f0[voiced]
        pitch_variation = float(np.std(f0v)) if len(f0v) > 1 else 0.0

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