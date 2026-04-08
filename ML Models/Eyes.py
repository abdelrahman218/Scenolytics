# -*- coding: utf-8 -*-
"""
Eye Movement Analysis — VS Code version
Originally from Google Colab (eye_movement_8_4.ipynb)

HOW TO RUN:
  1. Install dependencies:
       pip install mediapipe==0.10.20 opencv-python numpy matplotlib
  2. Run the script:
       python eye_movement_vscode.py
     A file-picker dialog will open. Select your video file.
  3. Optionally pass a video path directly:
       python eye_movement_vscode.py path/to/video.mp4

EMOTION TIMELINE:
  Edit the EMOTION_TIMELINE list near the bottom of this file
  to match your video's emotion segments before running.
"""

import sys
import os
import cv2
import mediapipe as mp
import numpy as np
import matplotlib
matplotlib.use("Agg")          # non-interactive backend — works everywhere
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec


# ============================================================
# VIDEO FILE SELECTION
# ============================================================

def select_video_file():
    """
    Opens a file-picker dialog (GUI) to select a video.
    Falls back to sys.argv[1] if a path was passed on the command line.
    """
    if len(sys.argv) > 1:
        path = sys.argv[1]
        if not os.path.isfile(path):
            print(f"ERROR: File not found → {path}")
            sys.exit(1)
        return path

    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        path = filedialog.askopenfilename(
            title="Select audition video",
            filetypes=[
                ("Video files", "*.mp4 *.avi *.mov *.mkv *.webm"),
                ("All files",   "*.*"),
            ]
        )
        root.destroy()
        if not path:
            print("No file selected. Exiting.")
            sys.exit(0)
        return path
    except Exception:
        print("Tkinter not available. Pass the video path as a command-line argument:")
        print("  python eye_movement_vscode.py path/to/video.mp4")
        sys.exit(1)


# ============================================================
# GLOBAL CONFIGURATION
# ============================================================

CONFIG = {
    "min_face_size_ratio":      0.10,   # face must be ≥10% of frame height
    "min_detection_confidence": 0.5,
    "min_usable_frame_ratio":   0.70,   # at least 70% of frames must be usable
    "max_head_angle_degrees":   30,     # flag if head turns more than 30°
}

THRESHOLDS = {
    "strong": 1.5,   # 1.5 × IQR → clearly expressive
    "weak":   0.5,   # 0.5 × IQR → subtle movement
}

SHIFT_WINDOW_SEC       = 2.0
SHIFT_THRESHOLD_STRONG = 0.015   # clear gaze shift
SHIFT_THRESHOLD_SUBTLE = 0.005   # subtle but measurable

# ── MediaPipe eye landmarks ───────────────────────────────────
EYE_LANDMARKS = {
    "left": {
        "horizontal": [33,  133],
        "vertical_1": [160, 144],
        "vertical_2": [158, 153],
    },
    "right": {
        "horizontal": [362, 263],
        "vertical_1": [387, 373],
        "vertical_2": [385, 380],
    }
}

# ── Iris landmark indices ─────────────────────────────────────
# 468 = left iris centre, 473 = right iris centre
IRIS_IDX      = {"left": 468, "right": 473}
EYE_CORNERS   = {
    "left":  {"inner": 33,  "outer": 133, "top": 159, "bot": 145},
    "right": {"inner": 362, "outer": 263, "top": 386, "bot": 374},
}

SHIFT_COLORS = {
    "STRONG_SHIFT": "#22c55e",
    "SUBTLE_SHIFT": "#f59e0b",
    "NO_SHIFT":     "#ef4444",
    "NO_DATA":      "#64748b",
}

SHIFT_LABELS = {
    "STRONG_SHIFT": "✓ EYES MOVED",
    "SUBTLE_SHIFT": "~ SUBTLE SHIFT",
    "NO_SHIFT":     "✗ EYES FROZEN",
    "NO_DATA":      "— NO DATA",
}


# ============================================================
# INITIALIZE MEDIAPIPE
# ============================================================

mp_face_mesh = mp.solutions.face_mesh

face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=CONFIG["min_detection_confidence"],
    min_tracking_confidence=0.5,
)


# ============================================================
# STEP 1 — VIDEO QUALITY CHECK
# ============================================================

def get_face_size(landmarks, frame_height, frame_width):
    forehead = landmarks[10]
    chin     = landmarks[152]
    face_height_pixels = abs(forehead.y - chin.y) * frame_height
    return face_height_pixels / frame_height


def get_head_angle(landmarks):
    nose      = landmarks[1]
    left_ear  = landmarks[234]
    right_ear = landmarks[454]

    dist_left  = abs(nose.x - left_ear.x)
    dist_right = abs(nose.x - right_ear.x)
    total_h    = dist_left + dist_right
    yaw_ratio  = abs(dist_left - dist_right) / total_h if total_h > 0 else 0
    yaw_angle  = yaw_ratio * 90

    forehead   = landmarks[10]
    chin       = landmarks[152]
    dist_up    = abs(nose.y - forehead.y)
    dist_down  = abs(chin.y - nose.y)
    total_v    = dist_up + dist_down
    pitch_ratio = abs(dist_up - dist_down) / total_v if total_v > 0 else 0
    pitch_angle = pitch_ratio * 90

    return max(yaw_angle, pitch_angle)


def check_lighting(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    avg  = np.mean(gray)
    return 40 <= avg <= 220


def classify_skip_reason(face_detected, face_large_enough, lighting_ok, angle_ok):
    if not face_detected:    return "no_face_detected"
    if not face_large_enough: return "face_too_small"
    if not lighting_ok:      return "poor_lighting"
    if not angle_ok:         return "head_angle_too_large"
    return None


def run_quality_check(video_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("ERROR: Could not open video file.")
        return None

    total_frames  = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps           = cap.get(cv2.CAP_PROP_FPS)
    frame_width   = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height  = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    duration_sec  = total_frames / fps

    print(f"\nVideo info:")
    print(f"  Resolution   : {frame_width} x {frame_height}")
    print(f"  FPS          : {fps:.1f}")
    print(f"  Total frames : {total_frames}")
    print(f"  Duration     : {duration_sec:.1f} seconds")
    print(f"\nRunning quality check...")

    usable_frames = []
    skipped_frames = []
    skip_reasons = {
        "no_face_detected": 0,
        "face_too_small":   0,
        "poor_lighting":    0,
        "head_angle_too_large": 0,
    }
    frame_index = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        timestamp_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
        lighting_ok  = check_lighting(frame)

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results   = face_mesh.process(rgb_frame)

        face_detected     = results.multi_face_landmarks is not None
        face_large_enough = False
        angle_ok          = False

        if face_detected:
            landmarks         = results.multi_face_landmarks[0].landmark
            face_ratio        = get_face_size(landmarks, frame_height, frame_width)
            face_large_enough = face_ratio >= CONFIG["min_face_size_ratio"]
            head_angle        = get_head_angle(landmarks)
            angle_ok          = head_angle <= CONFIG["max_head_angle_degrees"]

        all_ok = face_detected and face_large_enough and lighting_ok and angle_ok

        if all_ok:
            usable_frames.append({
                "frame_index":  frame_index,
                "timestamp_ms": timestamp_ms,
                "landmarks":    results.multi_face_landmarks[0].landmark,
            })
        else:
            reason = classify_skip_reason(
                face_detected, face_large_enough, lighting_ok, angle_ok
            )
            skip_reasons[reason] += 1
            skipped_frames.append({
                "frame_index":  frame_index,
                "timestamp_ms": timestamp_ms,
                "reason":       reason,
            })

        frame_index += 1

    cap.release()

    total_processed = len(usable_frames) + len(skipped_frames)
    usable_ratio    = len(usable_frames) / total_processed if total_processed > 0 else 0
    video_is_usable = usable_ratio >= CONFIG["min_usable_frame_ratio"]

    report = {
        "video_path":       video_path,
        "fps":              fps,
        "frame_width":      frame_width,
        "frame_height":     frame_height,
        "duration_seconds": duration_sec,
        "total_frames":     total_processed,
        "usable_frames":    len(usable_frames),
        "skipped_frames":   len(skipped_frames),
        "usable_ratio":     usable_ratio,
        "skip_reasons":     skip_reasons,
        "video_is_usable":  video_is_usable,
        "usable_frame_data": usable_frames,
    }

    print(f"\n{'='*45}")
    print(f"  QUALITY CHECK REPORT")
    print(f"{'='*45}")
    print(f"  Usable frames    : {len(usable_frames)} / {total_processed} ({usable_ratio*100:.1f}%)")
    print(f"  Skipped frames   : {len(skipped_frames)}")

    if skipped_frames:
        print(f"\n  Skip reasons:")
        for reason, count in skip_reasons.items():
            if count > 0:
                print(f"    - {reason}: {count} frames")

    status = "PASS - Video is usable" if video_is_usable else "FAIL - Video quality too low"
    print(f"\n  {status}")

    if not video_is_usable:
        print(f"\n  WARNING: Only {usable_ratio*100:.1f}% of frames are usable.")
        print(f"  Eye metrics will not be reliable for this submission.")

    print(f"{'='*45}\n")
    return report


# ============================================================
# STEP 2 — LANDMARK EXTRACTION, EAR & IRIS RATIOS
# ============================================================

def get_landmark_coords(landmarks, index, frame_width, frame_height):
    lm = landmarks[index]
    return np.array([lm.x * frame_width, lm.y * frame_height])


def compute_ear(landmarks, eye, frame_width, frame_height):
    """Eye Aspect Ratio for one eye."""
    idx = EYE_LANDMARKS[eye]

    h_left  = get_landmark_coords(landmarks, idx["horizontal"][0], frame_width, frame_height)
    h_right = get_landmark_coords(landmarks, idx["horizontal"][1], frame_width, frame_height)
    horizontal = np.linalg.norm(h_left - h_right)

    v1 = np.linalg.norm(
        get_landmark_coords(landmarks, idx["vertical_1"][0], frame_width, frame_height) -
        get_landmark_coords(landmarks, idx["vertical_1"][1], frame_width, frame_height)
    )
    v2 = np.linalg.norm(
        get_landmark_coords(landmarks, idx["vertical_2"][0], frame_width, frame_height) -
        get_landmark_coords(landmarks, idx["vertical_2"][1], frame_width, frame_height)
    )

    return 0.0 if horizontal == 0 else (v1 + v2) / (2.0 * horizontal)


def compute_average_ear(landmarks, frame_width, frame_height):
    return (compute_ear(landmarks, "left",  frame_width, frame_height) +
            compute_ear(landmarks, "right", frame_width, frame_height)) / 2.0


def compute_iris_ratios(landmarks, frame_width, frame_height):
    """
    Compute normalized iris position within each eye socket.
    h_ratio: 0 = far left, 0.5 = centre, 1 = far right
    v_ratio: 0 = top,       0.5 = centre, 1 = bottom
    """
    def px(idx):
        return np.array([landmarks[idx].x * frame_width,
                         landmarks[idx].y * frame_height])

    def safe_ratio(val, lo, hi):
        span = hi - lo
        return (val - lo) / span if span != 0 else 0.5

    h_ratios, v_ratios = [], []
    for side, c in EYE_CORNERS.items():
        iris   = px(IRIS_IDX[side])
        inner  = px(c["inner"])
        outer  = px(c["outer"])
        top    = px(c["top"])
        bot    = px(c["bot"])

        # Horizontal: left eye → inner is left, outer is right
        if side == "left":
            hr = safe_ratio(iris[0], inner[0], outer[0])
        else:
            hr = safe_ratio(iris[0], outer[0], inner[0])

        vr = safe_ratio(iris[1], top[1], bot[1])
        h_ratios.append(hr)
        v_ratios.append(vr)

    return float(np.mean(h_ratios)), float(np.mean(v_ratios))


def run_ear_and_iris_extraction(quality_report):
    """
    Produces two time-series:
      ear_time_series  — shape [N, 2]  cols: [timestamp_ms, avg_ear]
      iris_series      — list of dicts: {timestamp_ms, h_ratio, v_ratio, landmarks}
    """
    if not quality_report["video_is_usable"]:
        print("WARNING: Video failed quality check. Results are LOW CONFIDENCE.")

    usable_frames = quality_report["usable_frame_data"]
    fw = quality_report["frame_width"]
    fh = quality_report["frame_height"]

    if not usable_frames:
        print("ERROR: No usable frames. Cannot extract features.")
        return None, None

    print(f"Extracting EAR & iris ratios from {len(usable_frames)} usable frames...")

    ear_rows    = []
    iris_series = []

    for fd in usable_frames:
        ts  = fd["timestamp_ms"]
        lm  = fd["landmarks"]

        avg_ear    = compute_average_ear(lm, fw, fh)
        h_ratio, v_ratio = compute_iris_ratios(lm, fw, fh)

        ear_rows.append([ts, avg_ear])
        iris_series.append({
            "timestamp_ms": ts,
            "h_ratio":      h_ratio,
            "v_ratio":      v_ratio,
            "landmarks":    lm,
        })

    ear_time_series = np.array(ear_rows, dtype=np.float64)

    ear_vals = ear_time_series[:, 1]
    print(f"\n{'='*45}")
    print(f"  EAR EXTRACTION REPORT")
    print(f"{'='*45}")
    print(f"  Frames processed : {len(ear_time_series)}")
    print(f"  EAR min          : {np.min(ear_vals):.4f}")
    print(f"  EAR max          : {np.max(ear_vals):.4f}")
    print(f"  EAR mean         : {np.mean(ear_vals):.4f}")
    print(f"  Time range       : {ear_time_series[0,0]:.0f}ms → {ear_time_series[-1,0]:.0f}ms")
    print(f"{'='*45}\n")

    return ear_time_series, iris_series


# ============================================================
# STEP 3 — BASELINE ESTABLISHMENT
# ============================================================

def run_baseline_establishment(ear_time_series):
    if ear_time_series is None or len(ear_time_series) == 0:
        print("ERROR: No EAR data. Cannot establish baseline.")
        return None

    ear_values = ear_time_series[:, 1]

    BLINK_THRESHOLD  = 0.15
    blink_mask       = ear_values >= BLINK_THRESHOLD
    ear_values_clean = ear_values[blink_mask]

    if len(ear_values_clean) == 0:
        print("ERROR: No non-blink frames. Cannot establish baseline.")
        return None

    baseline    = np.median(ear_values_clean)
    lower_range = np.percentile(ear_values_clean, 25)
    upper_range = np.percentile(ear_values_clean, 75)

    eye_profile = {
        "baseline":        baseline,
        "lower_range":     lower_range,
        "upper_range":     upper_range,
        "iqr":             upper_range - lower_range,
        "blink_threshold": BLINK_THRESHOLD,
        "total_frames":    len(ear_values),
        "clean_frames":    len(ear_values_clean),
        "blink_frames":    int(np.sum(~blink_mask)),
    }

    print(f"\n{'='*45}")
    print(f"  BASELINE ESTABLISHMENT REPORT")
    print(f"{'='*45}")
    print(f"  Total frames     : {len(ear_values)}")
    print(f"  Blink frames     : {eye_profile['blink_frames']} removed")
    print(f"  Clean frames     : {len(ear_values_clean)} used for baseline")
    print(f"  Baseline (median): {baseline:.4f}")
    print(f"  Lower range (p25): {lower_range:.4f}")
    print(f"  Upper range (p75): {upper_range:.4f}")
    print(f"  Natural spread   : {eye_profile['iqr']:.4f}")
    print(f"{'='*45}\n")

    return eye_profile


# ============================================================
# STEP 4 — NORMALIZE THE EAR CURVE
# ============================================================

def run_normalization(ear_time_series, eye_profile):
    if ear_time_series is None or eye_profile is None:
        print("ERROR: Missing input from Step 2 or Step 3.")
        return None

    timestamps = ear_time_series[:, 0]
    ear_values = ear_time_series[:, 1]
    baseline   = eye_profile["baseline"]

    BLINK_THRESHOLD = 0.15
    blink_mask  = ear_values >= BLINK_THRESHOLD
    timestamps  = timestamps[blink_mask]
    ear_values  = ear_values[blink_mask]

    print(f"  Blink frames filtered : {np.sum(~blink_mask)} frames removed")
    print(f"  Frames remaining      : {np.sum(blink_mask)}")

    normalized  = ((ear_values - baseline) / baseline) * 100

    window_size = 15
    kernel      = np.ones(window_size) / window_size
    pad_width   = window_size // 2
    padded      = np.pad(normalized, pad_width, mode="edge")
    smoothed    = np.convolve(padded, kernel, mode="valid")[:len(normalized)]

    normalized_series = np.column_stack((timestamps, smoothed))

    print(f"\n{'='*45}")
    print(f"  NORMALIZATION REPORT")
    print(f"{'='*45}")
    print(f"  Frames processed   : {len(smoothed)}")
    print(f"  Baseline used      : {baseline:.4f}")
    print(f"  Smoothing window   : {window_size} frames")
    print(f"  Raw range          : {normalized.min():.1f}% → {normalized.max():.1f}%")
    print(f"  Smoothed range     : {smoothed.min():.1f}% → {smoothed.max():.1f}%")
    print(f"  Smoothed mean      : {smoothed.mean():.2f}%")
    print(f"{'='*45}\n")

    return normalized_series


# ============================================================
# STEP 5 — EYE OPENNESS SCORING
# ============================================================

def run_eye_openness_scoring(normalized_series, eye_profile):
    if normalized_series is None or eye_profile is None:
        print("ERROR: Missing input from Step 3 or Step 4.")
        return None

    ear_values    = normalized_series[:, 1]
    start_ms      = normalized_series[0,  0]
    end_ms        = normalized_series[-1, 0]
    iqr           = eye_profile["iqr"]

    peak_above    = float(np.percentile(ear_values, 90))
    peak_below    = float(abs(np.percentile(ear_values, 10)))
    avg_deviation = (peak_above + peak_below) / 2

    strong_threshold = max(THRESHOLDS["strong"] * iqr * 100, 8.0)
    weak_threshold   = max(THRESHOLDS["weak"]   * iqr * 100, 4.0)

    if avg_deviation >= strong_threshold:
        excess  = avg_deviation - strong_threshold
        score   = min(100, 75 + (excess / strong_threshold) * 25)
        result  = "expressive"
        message = (f"Eyes moved strongly ({avg_deviation:.2f}% avg deviation) "
                   f"— strong physical expression")
    elif avg_deviation >= weak_threshold:
        position = ((avg_deviation - weak_threshold) /
                    (strong_threshold - weak_threshold))
        score    = 25 + position * 50
        result   = "subtle"
        message  = (f"Eyes moved subtly ({avg_deviation:.2f}% avg deviation) "
                    f"— present but could be stronger")
    else:
        position = avg_deviation / weak_threshold if weak_threshold > 0 else 0
        score    = position * 25
        result   = "flat"
        message  = (f"Eyes stayed flat ({avg_deviation:.2f}% avg deviation) "
                    f"— no meaningful physical change")

    score = round(score, 1)

    print(f"\n{'='*52}")
    print(f"  PART A — EXPRESSIVE SCORING")
    print(f"{'='*52}")
    print(f"  Video window       : {start_ms/1000:.1f}s → {end_ms/1000:.1f}s")
    print(f"  Peak opening       : {peak_above:+.2f}%")
    print(f"  Peak narrowing     : -{peak_below:.2f}%")
    print(f"  Avg deviation      : {avg_deviation:.2f}%")
    print(f"  Strong threshold   : {strong_threshold:.2f}%")
    print(f"  Weak threshold     : {weak_threshold:.2f}%")
    print(f"  Result             : {result.upper()}")
    print(f"  Expressive score   : {score} / 100")
    print(f"  {message}")
    print(f"{'='*52}\n")

    return {
        "peak_above":       round(peak_above, 2),
        "peak_below":       round(peak_below, 2),
        "avg_deviation":    round(avg_deviation, 2),
        "strong_threshold": round(strong_threshold, 2),
        "weak_threshold":   round(weak_threshold, 2),
        "result":           result,
        "score":            score,
        "message":          message,
    }


# ============================================================
# IRIS GAZE CENTRE CALIBRATION
# ============================================================

def calibrate_gaze_centre(iris_series):
    """
    Compute neutral gaze centre (center_h, center_v) and tolerance bands
    from the full iris time series. Uses median + IQR to be blink-robust.
    """
    h_vals = np.array([f["h_ratio"] for f in iris_series])
    v_vals = np.array([f["v_ratio"] for f in iris_series])

    center_h = float(np.median(h_vals))
    center_v = float(np.median(v_vals))

    h_tol = float(np.percentile(np.abs(h_vals - center_h), 75))
    v_tol = float(np.percentile(np.abs(v_vals - center_v), 75))

    # Clamp tolerances to sensible minimum
    h_tol = max(h_tol, 0.02)
    v_tol = max(v_tol, 0.02)

    print(f"\n  Gaze centre  : H={center_h:.3f}  V={center_v:.3f}")
    print(f"  Gaze tolerance: H±{h_tol:.3f}  V±{v_tol:.3f}")

    return center_h, center_v, h_tol, v_tol


def classify_gaze(h, v, center_h, center_v, h_tol, v_tol):
    """Return a human-readable gaze direction label."""
    h_off = h - center_h
    v_off = v - center_v

    h_dir = ("RIGHT" if h_off >  h_tol else
             "LEFT"  if h_off < -h_tol else "")
    v_dir = ("DOWN"  if v_off >  v_tol else
             "UP"    if v_off < -v_tol else "")

    if h_dir and v_dir:
        return f"{v_dir}-{h_dir}"
    return h_dir or v_dir or "CENTER"


# ============================================================
# GAZE SHIFT AT EMOTION TRANSITIONS
# ============================================================

def find_emotion_transitions(emotion_timeline):
    transitions = []
    for i in range(1, len(emotion_timeline)):
        prev_start, prev_end, prev_emotion = emotion_timeline[i - 1]
        curr_start, curr_end, curr_emotion = emotion_timeline[i]
        if prev_emotion.lower().strip() != curr_emotion.lower().strip():
            transitions.append({
                "time_sec":     curr_start,
                "time_ms":      curr_start * 1000,
                "from_emotion": prev_emotion,
                "to_emotion":   curr_emotion,
            })

    print(f"\n{'='*55}")
    print(f"  EMOTION TRANSITIONS DETECTED")
    print(f"{'='*55}")
    print(f"  Total transitions : {len(transitions)}")
    for t in transitions:
        print(f"    {t['time_sec']:.0f}s  :  {t['from_emotion']} → {t['to_emotion']}")
    print(f"{'='*55}\n")
    return transitions


def measure_gaze_shifts(iris_series, transitions,
                         center_h, center_v, h_tol, v_tol,
                         window_sec=SHIFT_WINDOW_SEC):
    timestamps = np.array([f["timestamp_ms"] for f in iris_series])
    h_vals     = np.array([f["h_ratio"]      for f in iris_series])
    v_vals     = np.array([f["v_ratio"]      for f in iris_series])
    window_ms  = window_sec * 1000
    results    = []

    for t in transitions:
        t_ms = t["time_ms"]

        before_mask = (timestamps >= t_ms - window_ms) & (timestamps < t_ms)
        after_mask  = (timestamps >= t_ms) & (timestamps <= t_ms + window_ms)

        if np.sum(before_mask) < 3 or np.sum(after_mask) < 3:
            results.append({**t, "displacement": None,
                            "score": None, "label": "NO_DATA",
                            "message": "Not enough frames in window"})
            continue

        h_before = np.mean(h_vals[before_mask])
        v_before = np.mean(v_vals[before_mask])
        h_after  = np.mean(h_vals[after_mask])
        v_after  = np.mean(v_vals[after_mask])

        displacement = np.sqrt((h_after - h_before)**2 + (v_after - v_before)**2)

        vol_before = np.mean(np.sqrt(
            np.diff(h_vals[before_mask])**2 + np.diff(v_vals[before_mask])**2
        ))
        vol_after = np.mean(np.sqrt(
            np.diff(h_vals[after_mask])**2 + np.diff(v_vals[after_mask])**2
        ))

        dir_before = classify_gaze(h_before, v_before, center_h, center_v, h_tol, v_tol)
        dir_after  = classify_gaze(h_after,  v_after,  center_h, center_v, h_tol, v_tol)

        if displacement >= SHIFT_THRESHOLD_STRONG:
            score, label = 100.0, "STRONG_SHIFT"
        elif displacement >= SHIFT_THRESHOLD_SUBTLE:
            score, label = 50.0, "SUBTLE_SHIFT"
        else:
            score, label = 0.0, "NO_SHIFT"

        results.append({
            **t,
            "displacement": round(displacement, 5),
            "h_before":     round(h_before, 4),
            "v_before":     round(v_before, 4),
            "h_after":      round(h_after,  4),
            "v_after":      round(v_after,  4),
            "dir_before":   dir_before,
            "dir_after":    dir_after,
            "vol_before":   round(vol_before, 5),
            "vol_after":    round(vol_after,  5),
            "score":        score,
            "label":        label,
        })

    ICONS = {"STRONG_SHIFT": "✓✓", "SUBTLE_SHIFT": "✓ ",
             "NO_SHIFT": "✗ ", "NO_DATA": "— "}
    scored      = [r for r in results if r["score"] is not None]
    final_score = np.mean([r["score"] for r in scored]) if scored else 0.0

    print(f"\n{'='*60}")
    print(f"  EYE GAZE SHIFT AT EMOTION TRANSITIONS")
    print(f"{'='*60}")
    for r in results:
        icon = ICONS.get(r["label"], "?")
        if r["displacement"] is not None:
            print(f"\n  [{icon}] {r['time_sec']:.0f}s  "
                  f"{r['from_emotion']:>10} → {r['to_emotion']:<10}")
            print(f"        Gaze: {r['dir_before']} → {r['dir_after']}  |  "
                  f"shift: {r['displacement']:.5f}")
            print(f"        Volatility: {r['vol_before']:.5f} → {r['vol_after']:.5f}")
            print(f"        Score: {r['score']:.0f}  ({r['label']})")
        else:
            print(f"\n  [{icon}] {r['time_sec']:.0f}s  "
                  f"{r['from_emotion']:>10} → {r['to_emotion']:<10}")
            print(f"        {r['message']}")
    print(f"\n  {'─'*40}")
    print(f"  Gaze Shift Score : {final_score:.1f} / 100")
    print(f"{'='*60}\n")

    return results, round(final_score, 2)


# ============================================================
# VISUALIZATION — GAZE TRANSITIONS
# ============================================================

def _draw_transition_frame(ax, cap, iris_series,
                            usable_ts_map, frame_idx,
                            color, title, direction):
    ts = iris_series[frame_idx]["timestamp_ms"]
    fd = usable_ts_map.get(ts)

    if fd is None:
        ax.set_facecolor("#1e293b")
        ax.text(0.5, 0.5, "No frame", ha="center", va="center",
                color="white", fontsize=12, transform=ax.transAxes)
        ax.axis("off")
        return

    cap.set(cv2.CAP_PROP_POS_MSEC, fd["timestamp_ms"])
    ret, frame = cap.read()

    if not ret:
        ax.set_facecolor("#1e293b")
        ax.text(0.5, 0.5, "Read error", ha="center", va="center",
                color="white", fontsize=12, transform=ax.transAxes)
        ax.axis("off")
        return

    frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    h, w  = frame.shape[:2]
    lm    = fd["landmarks"]

    c_hex = color.lstrip("#")
    c_rgb = (int(c_hex[0:2], 16), int(c_hex[2:4], 16), int(c_hex[4:6], 16))

    for iris_idx in [468, 473]:
        px = int(lm[iris_idx].x * w)
        py = int(lm[iris_idx].y * h)
        radius = max(int(h * 0.02), 7)
        cv2.circle(frame, (px, py), radius, c_rgb, 2)
        cv2.circle(frame, (px, py), 3,      c_rgb, -1)

    for corner_idx in [33, 133, 362, 263]:
        px = int(lm[corner_idx].x * w)
        py = int(lm[corner_idx].y * h)
        cv2.circle(frame, (px, py), 3, (180, 180, 180), -1)

    h_r = iris_series[frame_idx]["h_ratio"]
    v_r = iris_series[frame_idx]["v_ratio"]
    cv2.putText(frame, f"Gaze: {direction}",
                (8, h - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
    cv2.putText(frame, f"H:{h_r:.3f} V:{v_r:.3f}",
                (8, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (200, 200, 200), 1)

    ax.imshow(frame)
    ax.set_title(title, color=color, fontsize=9, fontweight="bold", pad=4)
    ax.axis("off")


def visualize_gaze_transitions(report, iris_series, results,
                                center_h, center_v, h_tol, v_tol,
                                video_path, window_sec=SHIFT_WINDOW_SEC):
    valid = [r for r in results if r["displacement"] is not None]
    if not valid:
        print("No valid transitions to visualize.")
        return

    n_cols       = len(valid)
    usable_ts_map = {fd["timestamp_ms"]: fd for fd in report["usable_frame_data"]}
    timestamps   = np.array([f["timestamp_ms"] for f in iris_series])
    h_vals       = np.array([f["h_ratio"]      for f in iris_series])
    window_ms    = window_sec * 1000
    cap          = cv2.VideoCapture(video_path)

    fig = plt.figure(figsize=(max(16, n_cols * 5.5), 20))
    fig.patch.set_facecolor("#0f172a")
    gs  = gridspec.GridSpec(3, n_cols, figure=fig,
                            height_ratios=[1.5, 1.5, 1.0],
                            hspace=0.40, wspace=0.20)

    for col, r in enumerate(valid):
        t_ms  = r["time_ms"]
        color = SHIFT_COLORS[r["label"]]

        before_idx = np.where((timestamps >= t_ms - window_ms) & (timestamps < t_ms))[0]
        after_idx  = np.where((timestamps >= t_ms) & (timestamps <= t_ms + window_ms))[0]

        if not len(before_idx) or not len(after_idx):
            continue

        best_before = before_idx[np.argmin(np.abs(timestamps[before_idx] - (t_ms - 1000)))]
        best_after  = after_idx [np.argmin(np.abs(timestamps[after_idx]  - (t_ms + 1000)))]

        ax_before = fig.add_subplot(gs[0, col])
        _draw_transition_frame(ax_before, cap, iris_series, usable_ts_map, best_before, color,
                               f"BEFORE  ({r['from_emotion']})\n{timestamps[best_before]/1000:.1f}s",
                               r["dir_before"])

        ax_after = fig.add_subplot(gs[1, col])
        _draw_transition_frame(ax_after, cap, iris_series, usable_ts_map, best_after, color,
                               f"AFTER  ({r['to_emotion']})\n{timestamps[best_after]/1000:.1f}s",
                               r["dir_after"])

        # Iris trace
        ax_trace = fig.add_subplot(gs[2, col])
        ax_trace.set_facecolor("#1e293b")

        full_mask = (timestamps >= t_ms - window_ms) & (timestamps <= t_ms + window_ms)
        t_sec     = timestamps[full_mask] / 1000
        h_win     = h_vals[full_mask]

        for i_pt in range(len(t_sec)):
            c = "#3b82f6" if t_sec[i_pt] < r["time_sec"] else "#a855f7"
            ax_trace.scatter(t_sec[i_pt], h_win[i_pt], c=c, s=5, alpha=0.7, zorder=3)

        ax_trace.axvline(r["time_sec"], color="white", linewidth=1.5,
                         linestyle="--", alpha=0.9, zorder=4)
        ax_trace.axhline(center_h, color="#22c55e", linewidth=0.8,
                         linestyle="--", alpha=0.5)
        ax_trace.fill_between([t_sec.min(), t_sec.max()],
                              center_h - h_tol, center_h + h_tol,
                              color="#22c55e", alpha=0.06)
        ax_trace.axhline(r["h_before"], color="#3b82f6", linewidth=1.2, alpha=0.8,
                         label=f'Before: {r["h_before"]:.3f}')
        ax_trace.axhline(r["h_after"], color="#a855f7",  linewidth=1.2, alpha=0.8,
                         label=f'After: {r["h_after"]:.3f}')

        mid_t = r["time_sec"]
        ax_trace.annotate("", xy=(mid_t + 0.3, r["h_after"]),
                          xytext=(mid_t - 0.3, r["h_before"]),
                          arrowprops=dict(arrowstyle="->", color=color, lw=2.5))

        ax_trace.set_xlabel("Time (s)", color="#94a3b8", fontsize=9)
        ax_trace.set_ylabel("H ratio",  color="#94a3b8", fontsize=9)
        ax_trace.tick_params(colors="#94a3b8", labelsize=8)
        for sp in ax_trace.spines.values():
            sp.set_edgecolor("#334155")

        badge = SHIFT_LABELS[r["label"]]
        ax_trace.set_title(f"{badge}\nshift={r['displacement']:.4f}  score={r['score']:.0f}",
                           color=color, fontsize=10, fontweight="bold", pad=6)
        ax_trace.legend(loc="upper right", fontsize=7,
                        facecolor="#1e293b", labelcolor="white")

    fig.suptitle("EYE GAZE SHIFT AT EMOTION TRANSITIONS\n"
                 "Did the actor's eyes move when the emotion changed?",
                 color="white", fontsize=14, fontweight="bold", y=0.99)
    cap.release()

    out_path = "metric_gaze_shift_transitions.png"
    plt.savefig(out_path, dpi=130, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"Saved → {out_path}")


# ============================================================
# BLINK RATE & PATTERN
# ============================================================

def compute_blink_metrics(ear_time_series, emotion_segments, blink_threshold=0.15):
    timestamps = ear_time_series[:, 0]
    ear_vals   = ear_time_series[:, 1]

    is_blinking = ear_vals < blink_threshold
    edges       = np.diff(is_blinking.astype(int))
    starts      = np.where(edges == 1)[0] + 1
    if is_blinking[0]:
        starts = np.insert(starts, 0, 0)
    ends = np.where(edges == -1)[0]
    if is_blinking[-1]:
        ends = np.append(ends, len(is_blinking) - 1)

    blink_events = []
    for s, e in zip(starts, ends):
        duration = timestamps[e] - timestamps[s]
        if duration >= 30:
            blink_events.append({
                "start_ms":   timestamps[s],
                "end_ms":     timestamps[e],
                "duration_ms": duration,
            })

    print(f"\n{'='*65}")
    print(f"  METRIC — BLINK RATE & PATTERN")
    print(f"{'='*65}")
    print(f"  Total blinks detected in video: {len(blink_events)}")
    print(f"{'-'*65}")

    for beat in emotion_segments:
        start_sec, end_sec, emotion = beat
        start_ms, end_ms = start_sec * 1000, end_sec * 1000
        seg_dur_min = (end_sec - start_sec) / 60.0

        seg_blinks = [b for b in blink_events
                      if b["start_ms"] >= start_ms and b["end_ms"] <= end_ms]
        blinks_count = len(seg_blinks)
        bpm  = blinks_count / seg_dur_min if seg_dur_min > 0 else 0.0
        avg_dur = np.mean([b["duration_ms"] for b in seg_blinks]) if blinks_count > 0 else 0

        print(f"  Segment: {start_sec:.1f}s → {end_sec:.1f}s ({emotion})")
        print(f"    Total Blinks : {blinks_count}")

        bpm_label = ("Fast / Anxious"     if bpm > 25 else
                     "Slow / Suppressed"  if bpm < 8  else "Normal")
        print(f"    Blink Rate   : {bpm:.1f} BPM ({bpm_label})")
        if blinks_count > 0:
            print(f"    Avg Duration : {avg_dur:.0f}ms")
        print()

    print(f"{'='*65}\n")
    return blink_events




# ============================================================
# EMOTION TIMELINE  ← EDIT THIS TO MATCH YOUR VIDEO
# ============================================================
#
# Format: list of (start_sec, end_sec, "emotion_label")
#
# Example for a 60-second audition:
#   (0,   20, "neutral")   — actor starts composed
#   (20,  40, "sad")       — emotion shifts
#   (40,  60, "angry")     — climax
#
# If you have no specific breakdown, leave the default
# below (one segment covering the full video duration).
# The script will run without gaze-shift analysis.

EMOTION_TIMELINE = [
    (0,   10,  "neutral"),
    (10,   20, "happy"),
    (20,  30, "angry"),
    (30,  32, "sad"),
]



# ============================================================
# MAIN PIPELINE
# ============================================================

def main():
    print("=" * 55)
    print("  EYE MOVEMENT ANALYSIS — VS Code")
    print("=" * 55)

    video_filename = select_video_file()
    print(f"\nVideo selected: {video_filename}")

    # ── Step 1 ──────────────────────────────────────────────
    report = run_quality_check(video_filename)
    if report is None:
        print("Aborting: could not open video.")
        return

    # ── Step 2 ──────────────────────────────────────────────
    ear_time_series, iris_series = run_ear_and_iris_extraction(report)
    if ear_time_series is None:
        print("Aborting: EAR extraction failed.")
        return

    # ── Step 3 ──────────────────────────────────────────────
    eye_profile = run_baseline_establishment(ear_time_series)
    if eye_profile is None:
        print("Aborting: baseline establishment failed.")
        return

    # ── Step 4 ──────────────────────────────────────────────
    normalized_series = run_normalization(ear_time_series, eye_profile)
    if normalized_series is None:
        print("Aborting: normalization failed.")
        return

    # ── Step 5 Part A ────────────────────────────────────────
    expressive_result = run_eye_openness_scoring(normalized_series, eye_profile)

    if expressive_result is not None:
        print(f"EYE OPENNESS FINAL SCORE : {expressive_result['score']} / 100")
        print(f"RESULT LABEL             : {expressive_result['result'].upper()}")
    else:
        print("EYE OPENNESS FINAL SCORE : N/A")

    # ── Gaze calibration ────────────────────────────────────
    print("\nCalibrating gaze centre from iris data...")
    center_h, center_v, h_tol, v_tol = calibrate_gaze_centre(iris_series)

    # ── Gaze shift at emotion transitions ───────────────────
    transitions = find_emotion_transitions(EMOTION_TIMELINE)

    if transitions:
        shift_results, shift_score = measure_gaze_shifts(
            iris_series, transitions,
            center_h, center_v, h_tol, v_tol,
            window_sec=SHIFT_WINDOW_SEC
        )

        visualize_gaze_transitions(
            report       = report,
            iris_series  = iris_series,
            results      = shift_results,
            center_h     = center_h,
            center_v     = center_v,
            h_tol        = h_tol,
            v_tol        = v_tol,
            video_path   = video_filename,
            window_sec   = SHIFT_WINDOW_SEC,
        )

        print(f"\nGAZE SHIFT SCORE : {shift_score} / 100")
    else:
        print("\nNo emotion transitions found. Skipping gaze-shift analysis.")
        print("Edit EMOTION_TIMELINE at the bottom of this file and re-run.")

    # ── Blink metrics ────────────────────────────────────────
    emotion_segments = EMOTION_TIMELINE
    compute_blink_metrics(ear_time_series, emotion_segments, blink_threshold=0.15)

    print("\nAll done! Check the current folder for any saved .png outputs.")


if __name__ == "__main__":
    main()
