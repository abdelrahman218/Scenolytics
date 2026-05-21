import os
import gc
import traceback
import tempfile

import soundfile as sf
import numpy as np
import torch
import librosa
import whisperx

from transformers import AutoProcessor, SeamlessM4Tv2Model


# =============================================================================
# Globals
# =============================================================================

processor = None
model = None
device = None
_align_device = None

SAMPLE_RATE = 16000

MODEL_PATH_CANDIDATES = [
    "./models/seamless-m4t-v2-large",
    "./models/seamless-m4t-v2-large-clean",
    "models/seamless-m4t-v2-large-fp32",
    "models/seamless-m4t-v2-large-clean",
]


# =============================================================================
# Helpers
# =============================================================================

def _find_model_path():
    for path in MODEL_PATH_CANDIDATES:
        if os.path.exists(path):
            return path

    raise FileNotFoundError(
        f"Could not find SeamlessM4T model.\nTried:\n" +
        "\n".join(MODEL_PATH_CANDIDATES)
    )


# =============================================================================
# Load Model
# =============================================================================

def load_script_model():
    global processor, model, device, _align_device

    # Already loaded
    if model is not None:
        return processor, model

    model_path = _find_model_path()

    device = "cuda" if torch.cuda.is_available() else "cpu"

    print(f"[SCRIPT] Loading SeamlessM4T on {device}")
    print(f"[SCRIPT] Model path: {model_path}")

    processor = AutoProcessor.from_pretrained(model_path)

    model = SeamlessM4Tv2Model.from_pretrained(
        model_path,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32,
        low_cpu_mem_usage=True,
    ).to(device)

    model.eval()

    _align_device = device

    print(f"[SCRIPT] WhisperX align device: {_align_device}")
    print("[SCRIPT] Model loaded successfully")

    return processor, model


# =============================================================================
# Language Detection
# =============================================================================

def _detect_language(text):
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    total_alpha = sum(1 for c in text if c.isalpha())

    if total_alpha == 0:
        return "en"

    return "ar" if (arabic_chars / total_alpha) > 0.3 else "en"


# =============================================================================
# WhisperX Alignment
# =============================================================================

def _align_with_whisperx(
    audio_array,
    transcript_text,
    sample_rate=16000,
    language=None,
):
    global _align_device

    if language is None:
        language = _detect_language(transcript_text)

    print(
        f"[ALIGN] language={language}, "
        f"words={len(transcript_text.split())}"
    )

    with tempfile.NamedTemporaryFile(
        suffix=".wav",
        delete=False,
    ) as temp_file:
        temp_audio = temp_file.name

    sf.write(temp_audio, audio_array, sample_rate)

    try:
        audio = whisperx.load_audio(temp_audio)

        duration_sec = len(audio_array) / sample_rate

        segments = [{
            "text": transcript_text.strip(),
            "start": 0.0,
            "end": duration_sec,
        }]

        try:
            model_a, metadata = whisperx.load_align_model(
                language_code=language,
                device=_align_device,
            )

            result_aligned = whisperx.align(
                segments,
                model_a,
                metadata,
                audio,
                _align_device,
                return_char_alignments=False,
            )

            del model_a

            gc.collect()

            if torch.cuda.is_available():
                torch.cuda.empty_cache()

            print("[ALIGN] WhisperX alignment done")

        except Exception as e:
            print(f"[ALIGN] Failed: {e}")
            traceback.print_exc()

            result_aligned = {
                "segments": [{
                    "text": transcript_text.strip(),
                    "start": 0.0,
                    "end": duration_sec,
                    "words": None,
                }]
            }

        word_timestamps = []

        for seg in result_aligned["segments"]:

            if "words" in seg and seg["words"]:

                for w in seg["words"]:

                    if (
                        w.get("word", "").strip()
                        and "start" in w
                        and "end" in w
                    ):
                        word_timestamps.append({
                            "word": w["word"].strip(),
                            "start": round(float(w["start"]), 3),
                            "end": round(float(w["end"]), 3),
                            "duration": round(
                                float(w["end"] - w["start"]),
                                3,
                            ),
                        })

            else:
                words = seg["text"].strip().split()

                dur = seg["end"] - seg["start"]

                wdur = dur / max(len(words), 1)

                for k, word in enumerate(words):

                    s = seg["start"] + k * wdur

                    word_timestamps.append({
                        "word": word,
                        "start": round(float(s), 3),
                        "end": round(float(s + wdur), 3),
                        "duration": round(float(wdur), 3),
                    })

        print(f"[ALIGN] Returning {len(word_timestamps)} words")

        return word_timestamps

    finally:
        if os.path.exists(temp_audio):
            os.remove(temp_audio)


# =============================================================================
# Transcription
# =============================================================================

def _transcribe(audio_array):
    global processor, model, device

    if model is None:
        load_script_model()

    print("[TRANSCRIBE] Running SeamlessM4T...")

    inputs = processor(
        audios=audio_array,
        sampling_rate=SAMPLE_RATE,
        return_tensors="pt",
    ).to(device)

    try:
        with torch.no_grad():

            if device == "cuda":

                with torch.autocast("cuda"):

                    output_tokens = model.generate(
                        **inputs,
                        tgt_lang="eng",
                        generate_speech=False,
                        max_new_tokens=256,
                    )

            else:

                output_tokens = model.generate(
                    **inputs,
                    tgt_lang="eng",
                    generate_speech=False,
                    max_new_tokens=256,
                )

        transcription = processor.decode(
            output_tokens.sequences[0].tolist(),
            skip_special_tokens=True,
        )

        print(
            f"[TRANSCRIBE] "
            f"{len(transcription.split())} words"
        )

        return transcription

    finally:
        del inputs

        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        gc.collect()


# =============================================================================
# Main Function
# =============================================================================

def transcribe_and_align(audio_path, language=None):

    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    load_script_model()

    print(f"[DEBUG] Loading audio: {audio_path}")

    audio_array, sr = sf.read(audio_path)

    if len(audio_array.shape) > 1:
        audio_array = np.mean(audio_array, axis=1)

    audio_array = audio_array.astype(np.float32).flatten()

    print(f"[DEBUG] duration={len(audio_array)/sr:.2f}s")

    if len(audio_array) == 0:
        raise ValueError("Empty audio")

    if sr != SAMPLE_RATE:
        audio_array = librosa.resample(
            audio_array,
            orig_sr=sr,
            target_sr=SAMPLE_RATE,
        )

    # -------------------------------------------------------------------------
    # Step 1: Transcribe
    # -------------------------------------------------------------------------

    transcription = _transcribe(audio_array)

    print(
        f"[DEBUG] transcript words="
        f"{len(transcription.split())}"
    )

    # -------------------------------------------------------------------------
    # Step 2: Align
    # -------------------------------------------------------------------------

    try:
        lang = language or _detect_language(transcription)

        aligned_words = _align_with_whisperx(
            audio_array,
            transcription,
            language=lang,
        )

    except Exception as e:

        print(f"[DEBUG] alignment error: {e}")

        traceback.print_exc()

        aligned_words = []

        lang = language or "en"

    return {
        "text": transcription,
        "aligned_words": aligned_words,
        "language": lang,
        "segments": [],
    }