from flask import Flask, request, jsonify
import os, json, time, traceback
import soundfile as sf
import numpy as np
import torch
import gc
import librosa
import whisperx

app = Flask(__name__)

SAMPLE_RATE    = 16000
SAVE_DIR       = "/content/drive/MyDrive/seamless_api_cache"
TRANSCRIPT_DIR = os.path.join(SAVE_DIR, "transcripts")
os.makedirs(TRANSCRIPT_DIR, exist_ok=True)

# ── resolve device once at startup ───────────────────────────────────────────
_align_device = str(next(model.parameters()).device)
print(f"[STARTUP] align_device={_align_device}")


def _detect_language(text):
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    total_alpha  = sum(1 for c in text if c.isalpha())
    if total_alpha == 0:
        return 'en'
    return 'ar' if (arabic_chars / total_alpha) > 0.3 else 'en'


def _align_with_whisperx(audio_array, transcript_text, sample_rate=16000, language=None):
    if language is None:
        language = _detect_language(transcript_text)
    print(f"[ALIGN] language={language}, words in transcript={len(transcript_text.split())}")

    temp_audio   = "/content/temp_align.wav"
    sf.write(temp_audio, audio_array, sample_rate)
    audio        = whisperx.load_audio(temp_audio)
    duration_sec = len(audio_array) / sample_rate
    segments     = [{"text": transcript_text.strip(), "start": 0.0, "end": duration_sec}]

    try:
        model_a, metadata = whisperx.load_align_model(
            language_code=language,
            device=_align_device,
        )
        result_aligned = whisperx.align(
            segments, model_a, metadata,
            audio, _align_device, return_char_alignments=False,
        )
        del model_a
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        print("[ALIGN] WhisperX alignment done")
    except Exception as e:
        print(f"[ALIGN] Failed: {e}")
        traceback.print_exc()
        result_aligned = {"segments": [{"text": transcript_text.strip(), "start": 0.0, "end": duration_sec, "words": None}]}

    word_timestamps = []
    for seg in result_aligned["segments"]:
        if "words" in seg and seg["words"]:
            for w in seg["words"]:
                if w.get("word", "").strip() and "start" in w and "end" in w:
                    word_timestamps.append({
                        "word":     w["word"].strip(),
                        "start":    round(float(w["start"]), 3),
                        "end":      round(float(w["end"]),   3),
                        "duration": round(float(w["end"] - w["start"]), 3),
                    })
        else:
            words = seg["text"].strip().split()
            dur   = seg["end"] - seg["start"]
            wdur  = dur / max(len(words), 1)
            for k, word in enumerate(words):
                s = seg["start"] + k * wdur
                word_timestamps.append({
                    "word":     word,
                    "start":    round(float(s), 3),
                    "end":      round(float(s + wdur), 3),
                    "duration": round(float(wdur), 3),
                })

    if os.path.exists(temp_audio):
        os.remove(temp_audio)

    print(f"[ALIGN] Returning {len(word_timestamps)} words")
    return word_timestamps


def _transcribe_with_chunking(audio_array, chunk_length_seconds=20, overlap_seconds=1):
    sr           = 16000
    chunk_size   = chunk_length_seconds * sr
    overlap_size = overlap_seconds * sr
    step         = chunk_size - overlap_size
    transcriptions = []
    starts = list(range(0, len(audio_array), step))
    total  = len(starts)
    print(f"Processing {total} chunk(s)...\n")
    for idx, i in enumerate(starts, 1):
        chunk = audio_array[i: i + chunk_size]
        if len(chunk) < sr * 0.5:
            continue
        print(f"  Chunk {idx}/{total} ({len(chunk)/sr:.1f}s)...", end=" ", flush=True)
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            gc.collect()
            inputs = processor(audios=chunk, sampling_rate=sr, return_tensors="pt").to(device)
            with torch.no_grad():
                output_tokens = model.generate(
                    **inputs, tgt_lang="eng", generate_speech=False, max_new_tokens=256,
                )
            text = processor.decode(output_tokens.sequences[0].tolist(), skip_special_tokens=True)
            transcriptions.append(text)
            print("✓")
            del inputs, output_tokens
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception as e:
            print(f"✗ {e}")
    return " ".join(transcriptions)



def health():
    return jsonify({"status": "ok"})



def transcribe_api_endpoint():
    if "audio" not in request.files:
        return jsonify({"error": "no audio file"}), 400

    audio_file = request.files["audio"]
    language   = request.form.get("language", None)

    timestamp = str(int(time.time()))
    save_path = os.path.join(TRANSCRIPT_DIR, f"{timestamp}_{audio_file.filename}")
    audio_file.save(save_path)

    file_size = os.path.getsize(save_path)
    print(f"[DEBUG] size={file_size} bytes, language_hint={language}")
    if file_size < 1000:
        return jsonify({"error": f"file too small: {file_size}"}), 400

    try:
        audio_array, sr = sf.read(save_path)
        audio_array = audio_array.astype(np.float32).flatten()
        print(f"[DEBUG] duration={len(audio_array)/sr:.2f}s")

        if len(audio_array) == 0:
            return jsonify({"error": "empty audio"}), 400
        if sr != SAMPLE_RATE:
            audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=SAMPLE_RATE)

        # Step 1: Transcribe
        transcription = _transcribe_with_chunking(audio_array)
        print(f"[DEBUG] transcript words={len(transcription.split())}: {transcription[:80]}...")

        # Step 2: Align
        try:
            lang          = language or _detect_language(transcription)
            aligned_words = _align_with_whisperx(audio_array, transcription, language=lang)
        except Exception as e:
            print(f"[DEBUG] alignment error: {e}")
            traceback.print_exc()
            aligned_words = []
            lang          = language or "en"

        return jsonify({
            "text":          transcription,
            "aligned_words": aligned_words,
            "language":      lang,
            "segments":      [],
        })

    except Exception as e:
        print(f"[DEBUG] Exception: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500