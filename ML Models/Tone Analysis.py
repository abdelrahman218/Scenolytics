# ════════════════════════════════════════════════════════
# 🎙️  TONE ANALYSIS — Pitch & Loudness
#     Run in VS Code: python tone_analysis.py
#     Graphs are saved as PNG files next to this script
# ════════════════════════════════════════════════════════

import os
import sys
import numpy as np
import librosa
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # must be before pyplot

import matplotlib.pyplot as plt
# ── STEP 1: Set your audio file path ─────────────────────────────────────────
# Replace this with the full path to your audio file (WAV, MP3, FLAC, etc.)
AUDIO_FILE = r"D:\Downloads 2\Desktop\Tone Analysis\Dramatic Monologue _ Strong Female Drama Actor, Young Actress Celines Estevez (1).mp3"
# ── STEP 2: Hardcode sentence timestamps ─────────────────────────────────────
# Each entry represents one sentence with a start/end time in seconds.
# Add or remove items to match your script.
SENTENCE_SEGMENTS = [
    {"start": 0.0,  "end": 3.8,  "sentance": "Sentence one goes here."},
    {"start": 3.8,  "end": 7.5,  "sentance": "Sentence two goes here."},
    {"start": 7.5,  "end": 12.0, "sentance": "Sentence three goes here."},
]

# ── STEP 3: Set output folder (default: same folder as this script) ───────────
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))


# ═════════════════════════════════════════════════════════════════════════════
# DO NOT EDIT BELOW THIS LINE
# ═════════════════════════════════════════════════════════════════════════════

# ── Load audio ────────────────────────────────────────────────────────────────
if not os.path.isfile(AUDIO_FILE):
    print(f"\n❌  File not found: {AUDIO_FILE}")
    print("    Please set AUDIO_FILE at the top of this script to a valid path.")
    sys.exit(1)

print(f"\n✅  Loading: {AUDIO_FILE}")
y, sr = librosa.load(AUDIO_FILE, sr=None, mono=True)
y = np.array(y, dtype=np.float32)

duration = len(y) / sr
n_seg    = len(SENTENCE_SEGMENTS)
audio_file = os.path.basename(AUDIO_FILE)

print(f"    Duration    : {duration:.2f} s")
print(f"    Sample rate : {sr} Hz")
print(f"    Sentences : {n_seg}")

# ── Validate sentence timestamps ─────────────────────────────────────────────
if n_seg == 0:
    print("\n⚠️   SENTENCE_SEGMENTS is empty.")
    print("    Please add sentence timestamps at the top of this script.")
    sys.exit(1)

print("\n✅  Sentences loaded:")
for i, seg in enumerate(SENTENCE_SEGMENTS):
    if "start" not in seg or "end" not in seg:
        print(f"    ❌  Sentence {i + 1} is missing 'start' or 'end'.")
        sys.exit(1)
    start = float(seg["start"])
    end = float(seg["end"])
    if end <= start:
        print(f"    ❌  Sentence {i + 1} has end <= start ({start} -> {end}).")
        sys.exit(1)
    if start < 0 or end > duration:
        print(f"    ❌  Sentence {i + 1} is outside audio duration ({duration:.2f}s).")
        sys.exit(1)
    sentence = str(seg.get("sentance", "")).strip()
    label = sentence if sentence else f"{start:.2f}s-{end:.2f}s"
    print(f"    {i + 1:02d}. {start:.2f}s-{end:.2f}s  ->  {label}")

# ── Constants ─────────────────────────────────────────────────────────────────
FRAME_LEN = 2048
HOP       = 512
SEGMENT_PADDING = 0

PITCH_EXPLANATION = (
    "This line shows how much voice MOVES UP AND DOWN in pitch each segment.\n"
    "  HIGH value -> Voice is melodic and emotionally alive.\n"
    "  LOW value  -> Voice is flat and stuck on one note.\n"
    
)

LOUDNESS_EXPLANATION = (
    
    
    "This line shows how much Volume RISES AND FALLS within each segment.\n"
    "  HIGH value -> Strong dynamic contrast: some words are loud,\n"
    "               some are quiet. This makes a performance feel alive.\n"
    "  LOW value  -> Your volume is uniform throughout: no emphasis,\n"
    "               no whispers, no bursts. Every word sounds equally important,\n"
    "               which means no word feels important at all.\n\n"

)

# ── Feature extraction ────────────────────────────────────────────────────────
print("\n⏳  Extracting features...")

seg_labels         = []
pitch_variation    = []
loudness_variation = []

def make_label(i, seg):
    sentence = str(seg.get("sentance", "")).strip()
    if sentence:
        short = sentence if len(sentence) <= 28 else sentence[:25] + "..."
        return f"S{i + 1}: {short}"
    return f"S{i + 1}: {seg['start']:.2f}-{seg['end']:.2f}s"


for i, seg_def in enumerate(SENTENCE_SEGMENTS):
    start = float(seg_def["start"]) - SEGMENT_PADDING
    end = float(seg_def["end"]) + SEGMENT_PADDING
    start = max(0.0, start)
    end = min(duration, end)

    start_idx = int(start * sr)
    end_idx = int(end * sr)
    if end_idx <= start_idx:
        pitch_variation.append(0.0)
        loudness_variation.append(0.0)
        continue
    seg = y[start_idx:end_idx]

    seg_labels.append(make_label(i, seg_def))

    rms      = librosa.feature.rms(y=seg, frame_length=FRAME_LEN, hop_length=HOP)[0]
    rms_norm = rms / (rms.max() + 1e-9)

    f0 = librosa.yin(seg,
                     fmin=librosa.note_to_hz('C2'),
                     fmax=librosa.note_to_hz('C7'),
                     frame_length=FRAME_LEN,
                     hop_length=HOP)
    voiced = (f0 > 60) & (rms_norm > 0.05)
    f0v    = f0[voiced]

    pitch_variation.append(float(np.std(f0v)) if len(f0v) > 1 else 0.0)
    loudness_variation.append(float(np.std(librosa.amplitude_to_db(rms, ref=np.max))))

print("✅  Feature extraction complete.")

x = np.arange(n_seg)


# ── Shared helpers ────────────────────────────────────────────────────────────
def style_ax(ax, ylabel, values):
    ax.set_facecolor('#0f0f23')
    ax.set_xticks(x)
    ax.set_xticklabels(seg_labels, rotation=20, ha='right', fontsize=9, color='#aaaaaa')
    ax.set_ylabel(ylabel, color='#aaaaaa', fontsize=9)
    ax.tick_params(colors='#aaaaaa')
    ax.grid(axis='y', color='#444466', lw=0.5, alpha=0.5)
    for sp in ax.spines.values():
        sp.set_edgecolor('#444466')
    ylim_top = max(values) * 1.3 if values else 1.0
    ax.set_ylim(0, ylim_top)


def add_explanation(fig, text):
    fig.text(
        0.01, -0.02, text,
        transform=fig.transFigure,
        fontsize=8.5, color='#cccccc',
        family='monospace',
        verticalalignment='top',
        bbox=dict(boxstyle='round,pad=0.8', facecolor='#0d0d1f',
                  edgecolor='#444466', alpha=0.9)
    )


# ══════════════════════════════════════════════════════════════════════════════
# GRAPH 1 — Pitch Variation
# ══════════════════════════════════════════════════════════════════════════════
print("\n📊  Drawing Graph 1 — Pitch Variation...")

fig1, ax1 = plt.subplots(figsize=(max(12, n_seg * 1.4), 5), facecolor='#1a1a2e')
fig1.suptitle(f"🎵  Pitch Variation Over Time  |  {audio_file}",
              fontsize=13, color='white')
ax1.set_facecolor('#0f0f23')

ax1.plot(x, pitch_variation, color='#64ffda', lw=2.5, marker='o',
         markersize=8, label='Pitch Variation (F0 std)', zorder=3)
ax1.fill_between(x, pitch_variation, alpha=0.12, color='#64ffda')
for i, v in enumerate(pitch_variation):
    ax1.text(i, v + max(pitch_variation) * 0.05, f'{v:.1f} Hz',
             ha='center', color='#64ffda', fontsize=8, fontweight='bold')

ax1.legend(fontsize=9, facecolor='#1a1a2e', labelcolor='white', loc='upper right')
style_ax(ax1, 'F0 Standard Deviation (Hz)', pitch_variation)
add_explanation(fig1, PITCH_EXPLANATION)
plt.tight_layout()

out1 = os.path.join(OUTPUT_DIR, 'pitch_variation.png')
plt.savefig(out1, dpi=150, bbox_inches='tight', facecolor='#1a1a2e')
plt.show()
print(f"✅  Graph 1 saved → {out1}")


# ══════════════════════════════════════════════════════════════════════════════
# GRAPH 2 — Loudness Variation
# ══════════════════════════════════════════════════════════════════════════════
print("\n📊  Drawing Graph 2 — Loudness Variation...")

fig2, ax2 = plt.subplots(figsize=(max(12, n_seg * 1.4), 5), facecolor='#1a1a2e')
fig2.suptitle(f"🔊  Loudness Variation Over Time  |  {audio_file}",
              fontsize=13, color='white')
ax2.set_facecolor('#0f0f23')

ax2.plot(x, loudness_variation, color='#ff6e40', lw=2.5, marker='s',
         markersize=8, label='Loudness Variation (Energy std)', zorder=3)
ax2.fill_between(x, loudness_variation, alpha=0.12, color='#ff6e40')
for i, v in enumerate(loudness_variation):
    ax2.text(i, v + max(loudness_variation) * 0.05, f'{v:.1f} dB',
             ha='center', color='#ff6e40', fontsize=8, fontweight='bold')

ax2.legend(fontsize=9, facecolor='#1a1a2e', labelcolor='white', loc='upper right')
style_ax(ax2, 'Energy Standard Deviation (dB)', loudness_variation)
add_explanation(fig2, LOUDNESS_EXPLANATION)
plt.tight_layout()

out2 = os.path.join(OUTPUT_DIR, 'loudness_variation.png')
plt.savefig(out2, dpi=150, bbox_inches='tight', facecolor='#1a1a2e')
plt.show()
print(f"✅  Graph 2 saved → {out2}")



