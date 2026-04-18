# ════════════════════════════════════════════════════════
# 🎙️  TONE ANALYSIS — Pitch, Loudness & Expressiveness
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
AUDIO_FILE = "D:\\Downloads 2\\Desktop\\Tone Analysis\\Breaking Bad - I Am The Danger..mp3"

# ── STEP 2: Hardcode your emotions ───────────────────────────────────────────
# One entry per 10-second segment.
# Run the script once first — it will print how many segments your audio has.
# Valid values: neutral | calm | happy | sad | angry | fearful | disgust | surprised
SEGMENT_EMOTIONS = [
    'neutral',   # 0 s – 10 s
    'calm',      # 10 s – 20 s
    'happy',     # 20 s – 30 s
    'sad',       # 30 s – 40 s
    'sad',       # 30 s – 40 s
    # add / remove lines to match your audio length
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
n_seg    = int(np.ceil(duration / 10))
audio_file = os.path.basename(AUDIO_FILE)

print(f"    Duration    : {duration:.2f} s")
print(f"    Sample rate : {sr} Hz")
print(f"    Segments (10 s each): {n_seg}")

# ── Validate emotions list ────────────────────────────────────────────────────
if len(SEGMENT_EMOTIONS) != n_seg:
    print(f"\n⚠️   SEGMENT_EMOTIONS has {len(SEGMENT_EMOTIONS)} entries "
          f"but audio has {n_seg} segments.")
    print("    Please fix the SEGMENT_EMOTIONS list at the top of this script.")
    sys.exit(1)

segment_emotions = SEGMENT_EMOTIONS
print(f"\n✅  Emotions set for {n_seg} segment(s):")
for i, e in enumerate(segment_emotions):
    t0, t1 = i * 10, min((i + 1) * 10, int(duration))
    print(f"    {t0:3d}s–{t1:3d}s  →  {e}")

# ── Constants ─────────────────────────────────────────────────────────────────
FRAME_LEN = 2048
HOP       = 512
SEG_SAM   = int(10 * sr)

EMOTION_COLOR = {
    'neutral'  : '#9e9e9e', 'calm'      : '#64b5f6',
    'happy'    : '#ffee58', 'sad'       : '#5c6bc0',
    'angry'    : '#ef5350', 'fearful'   : '#ab47bc',
    'disgust'  : '#66bb6a', 'surprised' : '#ff7043',
}
EMOTION_LABEL = {
    'neutral'  : '😐 Neutral', 'calm'      : '😌 Calm',
    'happy'    : '😊 Happy',   'sad'       : '😢 Sad',
    'angry'    : '😠 Angry',   'fearful'   : '😨 Fearful',
    'disgust'  : '🤢 Disgust', 'surprised' : '😲 Surprised',
}

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

seg_labels     = []
seg_f0_std     = []
seg_energy_std = []

for i in range(n_seg):
    seg   = y[i * SEG_SAM : min((i + 1) * SEG_SAM, len(y))]
    start = i * 10
    end   = min((i + 1) * 10, int(len(y) / sr))
    seg_labels.append(f"{start}s\u2013{end}s")

    rms      = librosa.feature.rms(y=seg, frame_length=FRAME_LEN, hop_length=HOP)[0]
    rms_norm = rms / (rms.max() + 1e-9)

    f0 = librosa.yin(seg,
                     fmin=librosa.note_to_hz('C2'),
                     fmax=librosa.note_to_hz('C7'),
                     frame_length=FRAME_LEN,
                     hop_length=HOP)
    voiced = (f0 > 60) & (rms_norm > 0.05)
    f0v    = f0[voiced]

    seg_f0_std.append(float(np.std(f0v))    if len(f0v) > 1 else 0.0)
    seg_energy_std.append(float(np.std(librosa.amplitude_to_db(rms, ref=np.max))))

print("✅  Feature extraction complete.")

x          = np.arange(n_seg)
emo_colors = [EMOTION_COLOR.get(e, '#ffffff') for e in segment_emotions]


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
    ylim_top = max(values) * 1.3
    ax.set_ylim(0, ylim_top)
    for i, emo in enumerate(segment_emotions):
        ax.text(i, ylim_top * 0.97, emo.upper(),
                ha='center', fontsize=7.5, color=emo_colors[i],
                rotation=30, fontweight='bold')


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

ax1.plot(x, seg_f0_std, color='#64ffda', lw=2.5, marker='o',
         markersize=8, label='Pitch Variation (F0 std)', zorder=3)
ax1.fill_between(x, seg_f0_std, alpha=0.12, color='#64ffda')
for i, v in enumerate(seg_f0_std):
    ax1.text(i, v + max(seg_f0_std) * 0.05, f'{v:.1f} Hz',
             ha='center', color='#64ffda', fontsize=8, fontweight='bold')

ax1.legend(fontsize=9, facecolor='#1a1a2e', labelcolor='white', loc='upper right')
style_ax(ax1, 'F0 Standard Deviation (Hz)', seg_f0_std)
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

ax2.plot(x, seg_energy_std, color='#ff6e40', lw=2.5, marker='s',
         markersize=8, label='Loudness Variation (Energy std)', zorder=3)
ax2.fill_between(x, seg_energy_std, alpha=0.12, color='#ff6e40')
for i, v in enumerate(seg_energy_std):
    ax2.text(i, v + max(seg_energy_std) * 0.05, f'{v:.1f} dB',
             ha='center', color='#ff6e40', fontsize=8, fontweight='bold')

ax2.legend(fontsize=9, facecolor='#1a1a2e', labelcolor='white', loc='upper right')
style_ax(ax2, 'Energy Standard Deviation (dB)', seg_energy_std)
add_explanation(fig2, LOUDNESS_EXPLANATION)
plt.tight_layout()

out2 = os.path.join(OUTPUT_DIR, 'loudness_variation.png')
plt.savefig(out2, dpi=150, bbox_inches='tight', facecolor='#1a1a2e')
plt.show()
print(f"✅  Graph 2 saved → {out2}")


# ══════════════════════════════════════════════════════════════════════════════
# GRAPH 3 — Expressiveness Score (Director's View)
# ══════════════════════════════════════════════════════════════════════════════
print("\n📊  Drawing Graph 3 — Expressiveness Score...")


def norm01(arr):
    mn, mx = min(arr), max(arr)
    return [(v - mn) / (mx - mn + 1e-9) for v in arr]


pitch_n     = norm01(seg_f0_std)
energy_n    = norm01(seg_energy_std)
score       = [round((p * 0.6 + e * 0.4) * 100) for p, e in zip(pitch_n, energy_n)]
final_score = round(sum(score) / len(score))


def bar_color(v):
    if v >= 65: return '#69f0ae'
    if v >= 35: return '#ffd740'
    return '#ff5252'


bar_colors  = [bar_color(v) for v in score]
score_color = '#69f0ae' if final_score >= 65 else '#ffd740' if final_score >= 35 else '#ff5252'
score_label = 'EXPRESSIVE' if final_score >= 65 else 'BORDERLINE' if final_score >= 35 else 'MONOTONIC'

fig3, ax3 = plt.subplots(figsize=(max(12, n_seg * 1.4), 6), facecolor='#1a1a2e')
fig3.suptitle(
    f"🎬  Actor Expressiveness — Director's View  |  {audio_file}\n"
    "Score 0–100  |  Green = Expressive  |  Yellow = Borderline  |  Red = Monotonic",
    fontsize=12, color='white', y=1.02
)
ax3.set_facecolor('#0f0f23')

bars = ax3.bar(x, score, color=bar_colors, width=0.6,
               edgecolor='#1a1a2e', linewidth=1.2, zorder=3)

for i, (bar, v) in enumerate(zip(bars, score)):
    ax3.text(i, v + 1.5, str(v), ha='center', va='bottom',
             color='white', fontsize=11, fontweight='bold')

for i, emo in enumerate(segment_emotions):
    ax3.text(i, -7, EMOTION_LABEL.get(emo, emo),
             ha='center', fontsize=8, color=emo_colors[i], fontweight='bold')

ax3.axhline(65, color='#69f0ae', lw=1.2, ls='--', alpha=0.5, label='Expressive (65)')
ax3.axhline(35, color='#ffd740', lw=1.2, ls='--', alpha=0.5, label='Monotonic (35)')

ax3.text(0.01, 0.97,
         f"OVERALL SCORE\n{final_score} / 100\n{score_label}",
         transform=ax3.transAxes,
         fontsize=11, color=score_color, fontweight='bold',
         verticalalignment='top',
         bbox=dict(boxstyle='round,pad=0.6', facecolor='#0d0d1f',
                   edgecolor=score_color, alpha=0.9))

ax3.set_xticks(x)
ax3.set_xticklabels(seg_labels, rotation=20, ha='right', fontsize=9, color='#aaaaaa')
ax3.set_ylim(-14, 115)
ax3.set_ylabel('Expressiveness Score (0–100)', color='#aaaaaa', fontsize=9)
ax3.tick_params(colors='#aaaaaa')
ax3.legend(fontsize=9, facecolor='#1a1a2e', labelcolor='white',
           loc='upper right', framealpha=0.7)
ax3.grid(axis='y', color='#444466', lw=0.5, alpha=0.4)
for sp in ax3.spines.values():
    sp.set_edgecolor('#444466')

plt.tight_layout()

out3 = os.path.join(OUTPUT_DIR, 'expressiveness_score.png')
plt.savefig(out3, dpi=150, bbox_inches='tight', facecolor='#1a1a2e')
plt.show()
print(f"✅  Graph 3 saved → {out3}")

