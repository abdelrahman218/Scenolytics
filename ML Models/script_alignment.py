"""
Script Alignment Tool — VSCode / Local Python Version
======================================================
Transcribes a video's audio (Egyptian Arabic) using SeamlessM4T v2,
aligns the transcript with WhisperX, then compares it against an
original script (.txt / .json / .srt).

HOW TO RUN
----------
1. Install dependencies (see INSTALL.md or the comment block below).
2. Edit the CONFIG section to point at your files.
3. Run:  python script_alignment.py

REQUIRED FILES
--------------
- Your video file (mp4, avi, mov, mkv …)
- Your script file (.txt, .json, or .srt)
"""

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG — edit these before running
# ─────────────────────────────────────────────────────────────────────────────
VIDEO_FILE  = r"D:\Scenolytics 2\ML Models\test1.mp4"
SCRIPT_FILE = r"D:\Scenolytics 2\ML Models\testscript.txt"
MODEL_DIR   = r"D:\Downloads 2\Desktop\seamless-m4t-v2-large" # local folder to cache the ~10 GB model
                                        # first run downloads it; subsequent runs load locally

# ─────────────────────────────────────────────────────────────────────────────
# IMPORTS
# ─────────────────────────────────────────────────────────────────────────────
import torch
import torchaudio          # noqa: F401  (pulled in by SeamlessM4T)
import numpy as np
import os
import gc
import re
import json
import difflib
import pandas as pd
import librosa
import soundfile as sf

from transformers import AutoProcessor, SeamlessM4Tv2Model

try:
    from moviepy.editor import VideoFileClip   # MoviePy 1.x
except ModuleNotFoundError:
    from moviepy import VideoFileClip          # MoviePy 2.x

# ── Patch torch.load for WhisperX / omegaconf compatibility ──────────────────
import torch.serialization
try:
    from omegaconf.listconfig import ListConfig
    from omegaconf.dictconfig import DictConfig
    torch.serialization.add_safe_globals([ListConfig, DictConfig])
except ImportError:
    pass

_orig_torch_load = torch.load
torch.load = lambda *a, **kw: _orig_torch_load(*a, **{**kw, "weights_only": False})

# ── Device ────────────────────────────────────────────────────────────────────
device       = "cuda" if torch.cuda.is_available() else "cpu"
compute_type = "float16" if device == "cuda" else "float32"

if device == "cuda":
    print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
    print(f"   Total VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
else:
    print("⚠️  No GPU detected — transcription will be very slow on CPU.")


# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Load SeamlessM4T v2 Model
# ─────────────────────────────────────────────────────────────────────────────
def load_seamless_model(model_dir: str):
    config_path = os.path.join(model_dir, "config.json")

    if os.path.exists(config_path):
        print(f"Loading model from local cache: {model_dir}")
        model_id         = model_dir
        local_files_only = True
    else:
        print("Model not found locally — downloading from HuggingFace (~10 GB)…")
        os.makedirs(model_dir, exist_ok=True)
        model_id         = "facebook/seamless-m4t-v2-large"
        local_files_only = False

    # Avoid fast-tokenizer conversion issues (tiktoken path)
    processor = AutoProcessor.from_pretrained(
        model_id,
        local_files_only=local_files_only,
        use_fast=False,
    )

    if device == "cuda":
        model = SeamlessM4Tv2Model.from_pretrained(
            model_id,
            load_in_8bit=True,
            device_map="auto",
            local_files_only=local_files_only,
        )
    else:
        # CPU-safe path (no bitsandbytes / 8bit)
        model = SeamlessM4Tv2Model.from_pretrained(
            model_id,
            local_files_only=local_files_only,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=True,
        ).to("cpu")

    if not local_files_only:
        print(f"Saving model to {model_dir} for future use…")
        processor.save_pretrained(model_dir)
        model.save_pretrained(model_dir)

    print("✅ SeamlessM4T v2 model ready!")
    if torch.cuda.is_available():
        used  = torch.cuda.memory_allocated(0) / 1e9
        total = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"   GPU VRAM used: {used:.1f} / {total:.1f} GB")

    return processor, model


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Extract Audio from Video
# ─────────────────────────────────────────────────────────────────────────────
def extract_audio(video_path: str, audio_path: str = "extracted_audio.wav") -> tuple:
    print(f"Extracting audio from {video_path} …")
    video = VideoFileClip(video_path)
    video.audio.write_audiofile(audio_path, codec="pcm_s16le", verbose=False, logger=None)
    video.close()
    print(f"✅ Audio saved to: {audio_path}")

    audio_array, sample_rate = librosa.load(audio_path, sr=16000)
    duration = len(audio_array) / sample_rate
    print(f"   Duration    : {duration:.1f}s  ({duration/60:.1f} min)")
    print(f"   Sample rate : {sample_rate} Hz")
    return audio_array, sample_rate, audio_path


# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Transcribe with SeamlessM4T (chunked)
# ─────────────────────────────────────────────────────────────────────────────
def transcribe_with_chunking(
    audio_array,
    processor,
    model,
    chunk_length_seconds: int = 20,
    overlap_seconds: int = 1,
) -> str:
    sr         = 16000
    chunk_size  = chunk_length_seconds * sr
    overlap_size = overlap_seconds * sr
    step        = chunk_size - overlap_size

    starts = list(range(0, len(audio_array), step))
    total  = len(starts)
    print(f"Processing {total} chunk(s) of ~{chunk_length_seconds}s each…\n")

    transcriptions = []
    for idx, i in enumerate(starts, 1):
        chunk = audio_array[i : i + chunk_size]
        if len(chunk) < sr * 0.5:
            continue

        print(f"  Chunk {idx}/{total}  ({len(chunk)/sr:.1f}s)…", end=" ", flush=True)
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            gc.collect()

            inputs = processor(
                audios=chunk,
                sampling_rate=sr,
                return_tensors="pt",
            ).to(device)

            with torch.no_grad():
                output_tokens = model.generate(
                    **inputs,
                    tgt_lang="arz",        # Egyptian Arabic
                    generate_speech=False,
                    max_new_tokens=256,
                )

            text = processor.decode(
                output_tokens[0].tolist()[0],
                skip_special_tokens=True,
            )
            transcriptions.append(text)
            print("✓")

            del inputs, output_tokens
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

        except Exception as e:
            print(f"✗ Error: {e}")

    return " ".join(transcriptions)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Word-Level Alignment with WhisperX
# ─────────────────────────────────────────────────────────────────────────────
def align_with_whisperx(audio_array, transcript_text: str, sample_rate: int = 16000) -> list:
    import whisperx

    temp_audio   = "temp_align.wav"
    sf.write(temp_audio, audio_array, sample_rate)
    audio        = whisperx.load_audio(temp_audio)
    duration_sec = len(audio_array) / sample_rate

    segments = [{"text": transcript_text.strip(), "start": 0.0, "end": duration_sec}]

    print("Word-level alignment (using SeamlessM4T transcript)…")
    try:
        model_a, metadata = whisperx.load_align_model(language_code="ar", device=device)
        result_aligned = whisperx.align(
            segments, model_a, metadata,
            audio, device, return_char_alignments=False,
        )
        del model_a
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        print("  Word-level alignment done.")
    except Exception as e:
        print(f"  Alignment failed ({e}), falling back to even split.")
        result_aligned = {
            "segments": [{"text": transcript_text.strip(), "start": 0.0,
                          "end": duration_sec, "words": None}]
        }

    word_timestamps = []
    for seg in result_aligned["segments"]:
        if "words" in seg and seg["words"]:
            for w in seg["words"]:
                if w.get("word", "").strip() and "start" in w and "end" in w:
                    word_timestamps.append({
                        "word"    : w["word"].strip(),
                        "start"   : round(w["start"], 3),
                        "end"     : round(w["end"],   3),
                        "duration": round(w["end"] - w["start"], 3),
                    })
        else:
            words = seg["text"].strip().split()
            dur   = seg["end"] - seg["start"]
            wdur  = dur / max(len(words), 1)
            for k, word in enumerate(words):
                s = seg["start"] + k * wdur
                word_timestamps.append({
                    "word"    : word,
                    "start"   : round(s,        3),
                    "end"     : round(s + wdur, 3),
                    "duration": round(wdur,      3),
                })

    os.remove(temp_audio)
    return word_timestamps


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Arabic Normalisation helpers
# ─────────────────────────────────────────────────────────────────────────────
_ARABIC_INDIC_DIGITS = str.maketrans(
    "\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669",
    "0123456789",
)

def normalize_arabic(text: str) -> str:
    text = re.sub(r"[\u200B\u200C\u200D\uFEFF]", "", text)
    text = text.replace("\u0640", "")
    text = re.sub(r"[\uFEF5\uFEF6\uFEF7\uFEF8]", "\u0644\u0627", text)
    text = re.sub("\u0644\u0623|\u0644\u0625|\u0644\u0622|\u0644\u0627", "\u0644\u0627", text)
    text = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]", "", text)
    text = re.sub("[\u0625\u0623\u0622\u0627\u0671]", "\u0627", text)
    text = re.sub("[\u0624\u0676]",    "\u0648", text)
    text = re.sub("[\u0626]",           "\u064A", text)
    text = re.sub("[\u0621\u0655\u0654]", "\u0627", text)
    text = re.sub("\u0649",  "\u064A", text)
    text = re.sub("\u0629",  "\u0647", text)
    text = re.sub("\u06AF", "\u0643", text)
    text = text.translate(_ARABIC_INDIC_DIGITS)
    text = re.sub(r"(.)\1{2,}", r"\1\1", text)
    text = re.sub(r"(.)\1+",   r"\1",    text)
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+",      " ", text)
    return text.strip()


def _dam_lev(a: str, b: str, cap: int = 2) -> int:
    la, lb = len(a), len(b)
    if abs(la - lb) > cap:
        return cap + 1
    if a == b:
        return 0
    prev2 = list(range(lb + 1))
    prev1 = [0] * (lb + 1)
    for i in range(1, la + 1):
        curr = [i] + [0] * lb
        for j in range(1, lb + 1):
            cost = 0 if a[i-1] == b[j-1] else 1
            curr[j] = min(curr[j-1] + 1, prev1[j] + 1, prev1[j-1] + cost)
            if i > 1 and j > 1 and a[i-1] == b[j-2] and a[i-2] == b[j-1]:
                curr[j] = min(curr[j], prev2[j-2] + cost)
        prev2, prev1 = prev1, curr
    return prev1[lb]


def words_are_close(w1: str, w2: str) -> bool:
    if not w1 or not w2:
        return False
    if min(len(w1), len(w2)) == 1:
        return w1 == w2
    return _dam_lev(w1, w2, cap=2) <= 2


_NUM_WORDS = {
    'واحد':'1','وحده':'1','وحدها':'1','وحدهم':'1',
    'اتنين':'2','اثنين':'2','تنين':'2','اثنتين':'2',
    'تلاتة':'3','تلاته':'3','ثلاثة':'3','تلات':'3','ثلاث':'3',
    'اربعة':'4','اربعه':'4','اربع':'4',
    'خمسة':'5','خمسه':'5','خمس':'5',
    'ستة':'6','سته':'6','ست':'6',
    'سبعة':'7','سبعه':'7','سبع':'7',
    'تمانية':'8','تمانيه':'8','ثمانية':'8','تمان':'8','تمنية':'8',
    'تسعة':'9','تسعه':'9','تسع':'9',
    'عشرة':'10','عشره':'10','عشر':'10',
    'عشرين':'20','تلاتين':'30','ثلاثين':'30',
    'اربعين':'40','خمسين':'50','ستين':'60',
    'سبعين':'70','تمانين':'80','تسعين':'90',
    'مية':'100','ميه':'100','مئة':'100','مائة':'100',
    'الف':'1000','الاف':'1000',
}


def normalize_word_sequence(words: list) -> list:
    _PRONOUNS = {'هو','هي','هم','هما','انت','انتي','انتو','احنا','انا','ده','دي','دول'}
    result, i = [], 0
    while i < len(words):
        w = words[i]
        if w == 'ما' and i + 1 < len(words):
            nxt = words[i + 1]
            result.append('ما' + nxt if nxt in _PRONOUNS else 'م' + nxt)
            i += 2; continue
        if w == 'مش' and i + 1 < len(words):
            result.append('مش' + words[i + 1])
            i += 2; continue
        if w == 'على' and i + 1 < len(words) and words[i + 1] == 'شان':
            result.append('علشان')
            i += 2; continue
        result.append(_NUM_WORDS.get(w, w))
        i += 1
    return result


# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Script Loader
# ─────────────────────────────────────────────────────────────────────────────
def srt_to_seconds(ts: str) -> float:
    ts = ts.replace(",", ".")
    h, m, s = ts.split(":")
    return int(h)*3600 + int(m)*60 + float(s)


def parse_srt(content: str) -> list:
    segs, lines, i = [], content.strip().split("\n"), 0
    while i < len(lines):
        if lines[i].strip().isdigit():
            i += 1
        if i < len(lines) and "-->" in lines[i]:
            parts = lines[i].split("-->")
            s, e  = srt_to_seconds(parts[0].strip()), srt_to_seconds(parts[1].strip().split()[0])
            i += 1
            texts = []
            while i < len(lines) and lines[i].strip() and not lines[i].strip().isdigit():
                texts.append(lines[i].strip()); i += 1
            if texts:
                segs.append({"text": " ".join(texts), "start": s, "end": e})
        i += 1
    return segs


def load_script(path: str) -> list:
    with open(path, encoding="utf-8") as f:
        content = f.read()
    if path.endswith(".json"):
        data = json.loads(content)
        if isinstance(data, list) and data and "start" in data[0]:
            return data
        return [{"text": data.get("text", content), "start": 0, "end": 0}]
    if path.endswith(".srt"):
        return parse_srt(content)
    return [{"text": content, "start": 0, "end": 0}]


# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — Compare Script vs Transcript
# ─────────────────────────────────────────────────────────────────────────────
def compare(norm_script: str, norm_transcript: str, aligned_segments: list) -> pd.DataFrame:
    sw = normalize_word_sequence(norm_script.split())
    tw = normalize_word_sequence(norm_transcript.split())

    ts_list = [{"word": normalize_arabic(s["word"]), "start": s["start"], "end": s["end"]}
               for s in aligned_segments]

    rows, t_idx = [], 0
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, sw, tw).get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) else None
                rows.append({"Status": "✓ Match", "Script": sw[i1+k], "Transcript": tw[j1+k],
                              "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A", "Note": ""})
                t_idx += 1

        elif tag == "replace":
            _handled = False
            if (i2-i1) == 1 and (j2-j1) == 2:
                merged_t = tw[j1] + tw[j1+1]
                if sw[i1] == merged_t or words_are_close(sw[i1], merged_t):
                    ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) else None
                    rows.append({"Status": "✓ Match", "Script": sw[i1],
                                 "Transcript": merged_t,
                                 "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                                 "Note": f"merged: {tw[j1]!r}+{tw[j1+1]!r}"})
                    t_idx += 2; _handled = True
            elif (i2-i1) == 2 and (j2-j1) == 1:
                merged_s = sw[i1] + sw[i1+1]
                if merged_s == tw[j1] or words_are_close(merged_s, tw[j1]):
                    ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) else None
                    rows.append({"Status": "✓ Match", "Script": merged_s,
                                 "Transcript": tw[j1],
                                 "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                                 "Note": f"split: {sw[i1]!r}+{sw[i1+1]!r}"})
                    t_idx += 1; _handled = True

            if not _handled:
                for k in range(max(i2-i1, j2-j1)):
                    s_w = sw[i1+k] if i1+k < i2 else ""
                    t_w = tw[j1+k] if j1+k < j2 else ""
                    ts  = ts_list[t_idx]["start"] if t_w and t_idx < len(ts_list) else None
                    if s_w and t_w:
                        if words_are_close(s_w, t_w):
                            status, note = "✓ Match",    f"~1-edit: {s_w!r} ~ {t_w!r}"
                        else:
                            status, note = "🟡 Changed", f"{s_w!r} -> {t_w!r}"
                    elif s_w:
                        status, note, ts = "🔴 Skipped", f"{s_w!r} not said", None
                    else:
                        status, note = "🟢 Added",   f"{t_w!r} added"
                    rows.append({"Status": status, "Script": s_w or "-", "Transcript": t_w or "-",
                                  "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A", "Note": note})
                    if t_w:
                        t_idx += 1

        elif tag == "delete":
            for k in range(i2-i1):
                rows.append({"Status": "🔴 Skipped", "Script": sw[i1+k], "Transcript": "-",
                              "Timestamp": "N/A", "Note": f"{sw[i1+k]!r} not said"})

        elif tag == "insert":
            for k in range(j2-j1):
                ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) else None
                rows.append({"Status": "🟢 Added", "Script": "-", "Transcript": tw[j1+k],
                              "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                              "Note": f"{tw[j1+k]!r} added"})
                t_idx += 1

    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
def main():
    # 1. Load model
    processor, model = load_seamless_model(MODEL_DIR)

    # 2. Extract audio
    audio_array, sample_rate, audio_path = extract_audio(VIDEO_FILE)

    # 3. Transcribe
    print("\nStarting transcription…\n")
    transcription = transcribe_with_chunking(audio_array, processor, model)
    print("\n" + "="*60)
    print("TRANSCRIPTION (Egyptian Arabic / arz):")
    print("="*60)
    print(transcription)
    print("="*60)

    # 4. Align
    print("\nAligning audio…")
    aligned_segments = align_with_whisperx(audio_array, transcription)
    print(f"\n{len(aligned_segments)} words with timestamps")
    print("\nFirst 20 words:")
    for i, seg in enumerate(aligned_segments[:20], 1):
        print(f"  {i:3}. [{seg['start']:7.3f}s - {seg['end']:7.3f}s]  {seg['word']}")
    if len(aligned_segments) > 20:
        print(f"  … and {len(aligned_segments)-20} more")

    # 5. Load script & compare
    script_segments = load_script(SCRIPT_FILE)
    script_text     = " ".join(seg["text"].strip() for seg in script_segments)
    norm_script     = normalize_arabic(script_text)
    norm_transcript = " ".join(normalize_arabic(seg["word"]) for seg in aligned_segments)

    print(f"\nScript    : {len(norm_script.split())} words")
    print(f"Transcript: {len(norm_transcript.split())} words")

    df = compare(norm_script, norm_transcript, aligned_segments)

    # 6. Summary
    total   = len(df)
    matched = (df["Status"] == "✓ Match").sum()
    changed = (df["Status"] == "🟡 Changed").sum()
    skipped = (df["Status"] == "🔴 Skipped").sum()
    added   = (df["Status"] == "🟢 Added").sum()
    accuracy = matched / max(matched + changed + skipped, 1) * 100

    print("\n" + "="*60)
    print("Summary")
    print("="*60)
    print(f"Total     : {total}")
    print(f"Match     : {matched}  ({matched/total*100:.1f}%)")
    print(f"Changed   : {changed}  ({changed/total*100:.1f}%)")
    print(f"Skipped   : {skipped}  ({skipped/total*100:.1f}%)")
    print(f"Added     : {added}    ({added/total*100:.1f}%)")
    print(f"\nWord Accuracy: {accuracy:.1f}%")

    # 7. Save results to CSV
    out_csv = "alignment_results.csv"
    df.to_csv(out_csv, index=False, encoding="utf-8-sig")
    print(f"\n✅ Full results saved to: {out_csv}")

    pd.set_option("display.max_rows", None)
    pd.set_option("display.max_colwidth", 60)
    print("\nFull Comparison Table:")
    print(df.to_string())


if __name__ == "__main__":
    main()
