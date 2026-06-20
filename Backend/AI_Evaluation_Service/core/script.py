import os, json, time, traceback
import soundfile as sf
import numpy as np
import torch
import gc
import librosa
import whisperx
import re
import pandas as pd
import difflib

# == Arabic normalisation (enhanced) ==========================================

_ARABIC_INDIC_DIGITS = str.maketrans("\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669",
                                      "0123456789")

def normalize_arabic(text):
    # 0. Strip zero-width & invisible characters (ZWS, ZWNJ, ZWJ, BOM)
    text = re.sub(r"[\u200B\u200C\u200D\uFEFF]", "", text)
    # 1. Tatweel (kashida) removal
    text = text.replace("\u0640", "")
    # 2. Lam-Alef ligatures -> plain lam + alef
    text = re.sub(r"[\uFEF5\uFEF6\uFEF7\uFEF8]", "\u0644\u0627", text)
    text = re.sub("\u0644\u0623|\u0644\u0625|\u0644\u0622|\u0644\u0627", "\u0644\u0627", text)
    # 3. Diacritics removal
    text = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]", "", text)
    # 4. Hamza / Alef normalization
    text = re.sub("[\u0625\u0623\u0622\u0627\u0671]", "\u0627", text)
    text = re.sub("[\u0624\u0676]",    "\u0648", text)
    text = re.sub("[\u0626]",           "\u064A", text)
    text = re.sub("[\u0621\u0655\u0654]", "\u0627", text)
    # 5. Other letter normalizations
    text = re.sub("\u0649",  "\u064A", text)
    text = re.sub("\u0629",  "\u0647", text)
    text = re.sub("\u06AF", "\u0643", text)
    # 6. Arabic-Indic digit -> Western digit
    text = text.translate(_ARABIC_INDIC_DIGITS)
    # 7. Repeated character collapsing
    # FIX: single pass capping runs of 3+ at 2, preserving valid Arabic gemination (e.g. الله, مرة).
    # The original two-pass approach had a dead first pass followed by a second pass that collapsed
    # ALL consecutive duplicates to 1, incorrectly destroying legitimate doubled letters.
    text = re.sub(r"(.)\1{2,}", r"\1\1", text)
    # 8. Punctuation & whitespace cleanup
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+",      " ", text)
    text = text.lower()
    return text.strip()


# == Damerau-Levenshtein distance (capped at 2 for speed) =====================

def _dam_lev(a, b, cap=2):
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
            curr[j] = min(curr[j-1] + 1,
                          prev1[j]   + 1,
                          prev1[j-1] + cost)
            if i > 1 and j > 1 and a[i-1] == b[j-2] and a[i-2] == b[j-1]:
                curr[j] = min(curr[j], prev2[j-2] + cost)
        prev2, prev1 = prev1, curr
    return prev1[lb]

def words_are_close(w1, w2):
    """True if words differ by at most 2 edits (including adjacent transposition).
    Single-character words must match exactly to avoid over-matching particles.
    """
    if not w1 or not w2:
        return False
    if min(len(w1), len(w2)) == 1:
        return w1 == w2
    dist = _dam_lev(w1, w2, cap=2)
    if dist == 1:
        return True
    if dist == 2:
        return w1.startswith(w2) or w2.startswith(w1)

    return False



# == Egyptian Arabic number words -> digits ===================================

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

# == Sequence-level normalisation: contractions + number words ================

def normalize_word_sequence(words):
    _PRONOUNS = {'هو','هي','هم','هما','انت','انتي','انتو','احنا','انا','ده','دي','دول'}
    result = []
    i = 0
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


# == SRT helpers ==============================================================

def srt_to_seconds(ts):
    ts = ts.replace(",", ".")
    h, m, s = ts.split(":")
    return int(h)*3600 + int(m)*60 + float(s)

def parse_srt(script_text):
    segs, lines, i = [], script_text.strip().split("\n"), 0
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

def load_script(path):
    with open(path, encoding="utf-8") as f:
        script_text = f.read()
    if path.endswith(".json"):
        data = json.loads(script_text)
        if isinstance(data, list) and data:
            if isinstance(data[0], dict) and "start" in data[0]:
                return data
            # FIX: handle list of dicts that have "text" but no "start" (e.g. plain segment lists)
            if isinstance(data[0], dict) and "text" in data[0]:
                return [{"text": item["text"], "start": 0, "end": 0} for item in data if "text" in item]
        return [{"text": data.get("text", script_text) if isinstance(data, dict) else script_text,
                 "start": 0, "end": 0}]
    if path.endswith(".srt"):
        return parse_srt(script_text)
    return [{"text": script_text, "start": 0, "end": 0}]

def strip_emotion_labels(text):
    return re.sub(r'"[^"]+"', '', text)

def parse_script_to_json(raw_text):
    """
    Accepts raw script text directly (not a filepath) since the script is
    passed in-memory from MLPipeline rather than read from a multipart
    form field on disk.
    """
    raw_flat = re.sub(r'[\r\n]+', ' ', raw_text)
    raw_flat = re.sub(r'\s+', ' ', raw_flat).strip()
    matches = re.findall(r'(.*?)"([^"]+)"', raw_flat)
    if matches:
        sentences = []
        for script_text, emotion in matches:
            script_text = script_text.strip()
            if script_text:
                sentences.append({'script_text': script_text, 'emotion': emotion.strip().lower()})
        if sentences:
            return sentences
    # fallback: treat entire text as one neutral sentence
    return [{'script_text': raw_text.strip(), 'emotion': 'neutral'}]

def build_word_sent_map(sentences):
    """Map each script word index -> sentence index."""
    mapping = []
    for s_idx, entry in enumerate(sentences):
        words = normalize_arabic(entry['script_text']).split()
        for _ in words:
            mapping.append(s_idx)
    return mapping

def annotate_sent_idx(df, script_word_to_sent):
    """Tag each row in comparison df with its sentence index."""
    cursor, last, indices = 0, 0, []
    for _, row in df.iterrows():
        if row['Script'] != '-':
            if cursor < len(script_word_to_sent):
                last = script_word_to_sent[cursor]
                cursor += 1
        indices.append(last)
    df = df.copy()
    df['sent_idx'] = indices
    return df
def _status_map(s):
    return {
        "✓ Match":    "match",
        "🟡 Changed": "changed",
        "🔴 Skipped": "skipped",
        "🟢 Added":   "added",
    }.get(s, "unknown")
def reconstruct_timestamps(df_annotated, sentences, total_duration):
    """Build sentence-level timestamps from the comparison table."""
    def to_float(ts):
        try: return float(str(ts).replace('s', '').strip())
        except: return None

    df_annotated = df_annotated.copy()
    df_annotated['_t'] = df_annotated['Timestamp'].apply(to_float)
    USABLE = {'\u2713 Match', '\U0001f7e1 Changed', '\U0001f7e2 Added'}
    enriched = []

    for s_idx, entry in enumerate(sentences):
        sdf    = df_annotated[df_annotated['sent_idx'] == s_idx]
        usable = sdf[sdf['_t'].notna() & sdf['Status'].isin(USABLE)]

        n_script = max(len(sdf[sdf['Script'] != '-']), 1)
        n_said   = len(sdf[sdf['Status'].isin({'\u2713 Match', '\U0001f7e1 Changed'})])
        coverage = n_said / n_script

        if len(usable) == 0:
            enriched.append({
                'script_text' : entry['script_text'],
                'emotion' : entry['emotion'],
                't_start' : None,
                't_end'   : None,
                'coverage': 0.0,
                'status'  : 'missing'
            })
            continue

        t_start  = usable['_t'].min()
        next_sdf = df_annotated[df_annotated['sent_idx'] == s_idx + 1]
        next_t   = next_sdf[next_sdf['_t'].notna()]

        if len(next_t) > 0:
            t_end = (usable['_t'].max() + next_t['_t'].min()) / 2.0
        else:
            t_end = total_duration

        t_start = max(0.0, t_start)
        t_end   = min(total_duration, t_end)
        if t_end <= t_start:
            t_end = min(t_start + 0.5, total_duration)

        enriched.append({
            'content':             entry['script_text'],
            'emotion':             entry['emotion'],
            't_start':             round(t_start, 4),
            't_end':               round(t_end,   4),
            'coverage':            round(coverage, 3),
            'sentence_score':      round(coverage * 100, 2),
            'status':              'ok' if coverage >= 0.5 else 'partial',
            'sentence_index':      s_idx,
            'transcript_sentence': " ".join(
            r["Transcript"] for r in df_annotated[df_annotated['sent_idx'] == s_idx].to_dict('records')
            if r["Transcript"] != "-"
            ),
            'word_diff': [
               {
                    "status":          _status_map(r["Status"]),
                    "script_word":     r["Script"],
                    "transcript_word": r["Transcript"],
               }
               for r in df_annotated[df_annotated['sent_idx'] == s_idx].to_dict('records')
            ],
       })

    return enriched


# == Word-level comparison ====================================================

def compare(norm_script_text, norm_transcript_text, aligned_segments):
    sw = normalize_word_sequence(norm_script_text.split())
    tw = normalize_word_sequence(norm_transcript_text.split())

    ts_list = []
    for s in aligned_segments:
        if 'word' in s and 'start' in s and 'end' in s:
            ts_list.append({"word": normalize_arabic(s["word"]), "start": s["start"], "end": s["end"]})
        else:
            ts_list.append({"word": "", "start": None, "end": None})

    rows, t_idx = [], 0
    matcher = difflib.SequenceMatcher(None, sw, tw)

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) and ts_list[t_idx]["start"] is not None else None
                rows.append({"Status": "\u2713 Match", "Script": sw[i1+k], "Transcript": tw[j1+k],
                              "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A", "Note": ""})
                t_idx += 1

        elif tag == "replace":
            _handled = False
            if (i2-i1) == 1 and (j2-j1) == 2:
                merged_t = tw[j1] + tw[j1+1]
                if sw[i1] == merged_t or words_are_close(sw[i1], merged_t):
                    ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) and ts_list[t_idx]["start"] is not None else None
                    rows.append({"Status": "\u2713 Match", "Script": sw[i1],
                                 "Transcript": merged_t,
                                 "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                                 "Note": f"merged: {tw[j1]!r}+{tw[j1+1]!r}"})
                    t_idx += 2; _handled = True
            elif (i2-i1) == 2 and (j2-j1) == 1:
                merged_s = sw[i1] + sw[i1+1]
                if merged_s == tw[j1] or words_are_close(merged_s, tw[j1]):
                    ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) and ts_list[t_idx]["start"] is not None else None
                    rows.append({"Status": "\u2713 Match", "Script": merged_s,
                                 "Transcript": tw[j1],
                                 "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                                 "Note": f"split: {sw[i1]!r}+{sw[i1+1]!r}"})
                    t_idx += 1; _handled = True

            if not _handled:
                for k in range(max(i2-i1, j2-j1)):
                    s_w = sw[i1+k] if i1+k < i2 else ""
                    t_w = tw[j1+k] if j1+k < j2 else ""
                    ts  = ts_list[t_idx]["start"] if t_w and t_idx < len(ts_list) and ts_list[t_idx]["start"] is not None else None

                    if s_w and t_w:
                        if words_are_close(s_w, t_w):
                            status = "\u2713 Match"
                            note   = f"~1-edit: {s_w!r} ~ {t_w!r}"
                        else:
                            status = "\U0001f7e1 Changed"
                            note   = f"{s_w!r} -> {t_w!r}"
                    elif s_w:
                        status, note, ts = "\U0001f534 Skipped", f"{s_w!r} not said", None
                    else:
                        status, note = "\U0001f7e2 Added", f"{t_w!r} added"

                    rows.append({"Status": status, "Script": s_w or "-", "Transcript": t_w or "-",
                                  "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A", "Note": note})
                    if t_w:
                        t_idx += 1

        elif tag == "delete":
            for k in range(i2-i1):
                rows.append({"Status": "\U0001f534 Skipped", "Script": sw[i1+k], "Transcript": "-",
                              "Timestamp": "N/A", "Note": f"{sw[i1+k]!r} not said"})

        elif tag == "insert":
            for k in range(j2-j1):
                ts = ts_list[t_idx]["start"] if t_idx < len(ts_list) and ts_list[t_idx]["start"] is not None else None
                rows.append({"Status": "\U0001f7e2 Added", "Script": "-", "Transcript": tw[j1+k],
                              "Timestamp": f"{ts:.2f}s" if ts is not None else "N/A",
                              "Note": f"{tw[j1+k]!r} added"})
                t_idx += 1

    return pd.DataFrame(rows)


def compute_summary(df):
    """Compute word-accuracy stats matching the notebook summary output."""
    total   = len(df)
    matched = int((df["Status"] == "\u2713 Match").sum())
    changed = int((df["Status"] == "\U0001f7e1 Changed").sum())
    skipped = int((df["Status"] == "\U0001f534 Skipped").sum())
    added   = int((df["Status"] == "\U0001f7e2 Added").sum())
    matched_words= df[df["Status"] == "\u2713 Match"]["Script"]
    changed_words = df[df["Status"] == "\U0001f7e1 Changed"]["Script"]
    skipped_words = df[df["Status"] == "\U0001f534 Skipped"]["Script"]
    added_words   = df[df["Status"] == "\U0001f7e2 Added"]["Transcript"]
    accuracy = matched / max(matched + changed + skipped, 1) * 100
    return {
        "total"   : total,
        "matched" : matched,
        "changed" : changed,
        "skipped" : skipped,
        "added"   : added,
        "matched_words": matched_words.tolist(),
        "changed_words": changed_words.tolist(),
        "skipped_words": skipped_words.tolist(),
        "added_words": added_words.tolist(),
        "word_accuracy_pct": round(accuracy, 2),
    }



def _detect_language(text):
    """Heuristic eng/arz detection from text, based on Arabic-block char ratio."""
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    total_alpha  = sum(1 for c in text if c.isalpha())
    if total_alpha == 0:
        return 'eng'
    return 'arz' if (arabic_chars / total_alpha) > 0.3 else 'eng'



_LANG_ALIASES = {
    "ar": "arz", "ara": "arz", "arb": "arz", "arz": "arz", "arabic": "arz",
    "en": "eng", "eng": "eng", "english": "eng",
}

def _resolve_lang(code):
    if not code:
        return None
    return _LANG_ALIASES.get(code.strip().lower())


# WhisperX's alignment models are keyed by plain ISO 639-1 codes ("en", "ar"),
# not SeamlessM4T's dialect-specific ones -- this is the only place that
# distinction matters, so it's contained right here.
_WHISPERX_LANG = {"eng": "en", "arz": "ar"}

def _to_whisperx_lang(lang):
    return _WHISPERX_LANG.get(lang, "en")

import tempfile

def _align_with_whisperx(audio_array, transcript_text, sample_rate=16000, language=None):
    if language is None:
        language = _detect_language(transcript_text)
    whisperx_lang = _to_whisperx_lang(language)
    print(f"[ALIGN] language={language} (whisperx={whisperx_lang}), words in transcript={len(transcript_text.split())}")

    # FIX: was a hardcoded Colab path ("/content/temp_align.wav") that doesn't
    # exist outside Colab/Drive mounts -- now a real cross-platform temp file.
    fd, temp_audio = tempfile.mkstemp(suffix=".wav")
    os.close(fd)

    duration_sec = len(audio_array) / sample_rate
    segments     = [{"text": transcript_text.strip(), "start": 0.0, "end": duration_sec}]

    try:
        sf.write(temp_audio, audio_array, sample_rate)
        audio = whisperx.load_audio(temp_audio)

        model_a, metadata = whisperx.load_align_model(
            language_code=language
        )
        result_aligned = whisperx.align(
            segments, model_a, metadata,
            audio, return_char_alignments=False,
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
    finally:
        if os.path.exists(temp_audio):
            os.remove(temp_audio)

    word_timestamps = []
    for seg in result_aligned["segments"]:
        if "words" in seg and seg["words"]:
            for w in seg["words"]:
                if w.get("word", "").strip() and "start" in w and "end" in w:
                    word_timestamps.append({
                        "word"    : w["word"].strip(),
                        "start"   : round(float(w["start"]), 3),
                        "end"     : round(float(w["end"]),   3),
                        "duration": round(float(w["end"] - w["start"]), 3),
                    })
        else:
            words = seg["text"].strip().split()
            dur   = seg["end"] - seg["start"]
            wdur  = dur / max(len(words), 1)
            for k, word in enumerate(words):
                s = seg["start"] + k * wdur
                word_timestamps.append({
                    "word"    : word,
                    "start"   : round(float(s), 3),
                    "end"     : round(float(s + wdur), 3),
                    "duration": round(float(wdur), 3),
                })

    print(f"[ALIGN] Returning {len(word_timestamps)} words")
    return word_timestamps


def _transcribe_with_chunking(
    processor,
    model,
    device,
    audio_array,
    chunk_length_seconds=20,
    overlap_seconds=1,
    tgt_lang="arz",
):
    sr           = 16000
    chunk_size   = chunk_length_seconds * sr
    overlap_size = overlap_seconds * sr
    step         = chunk_size - overlap_size
    transcriptions = []
    starts = list(range(0, len(audio_array), step))
    total  = len(starts)
    print(f"Processing {total} chunk(s), tgt_lang={tgt_lang}...\n")
    for idx, i in enumerate(starts, 1):
        chunk = audio_array[i: i + chunk_size]
        if len(chunk) < sr * 0.5:
            continue
        print(f"  Chunk {idx}/{total} ({len(chunk)/sr:.1f}s)...", end=" ", flush=True)
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            gc.collect()
            inputs = processor(audio=chunk, sampling_rate=sr, return_tensors="pt").to(device)
            with torch.no_grad():
                output_tokens = model.generate(
                    **inputs,
                    tgt_lang=tgt_lang,
                    generate_speech=False,
                    max_new_tokens=256,
                )
            text = processor.decode(output_tokens.sequences[0].tolist(), skip_special_tokens=True)
            transcriptions.append(text)
            print("\u2713")
            del inputs, output_tokens
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception as e:
            print(f"\u2717 {e}")
    return " ".join(transcriptions)