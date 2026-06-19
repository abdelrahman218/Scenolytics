// Shared helpers for turning the raw AI evaluation payload (from
// `GET /api/v1/evaluations/by-submission/:id`) into UI-friendly primitives.
//
// Keeping these here (instead of in each detail page) avoids duplicating the
// defensive JSON handling across the facial / vocal / script / eyes tabs.

const Map<String, String> _emotionEmoji = <String, String>{
  'angry': '😡',
  'anger': '😡',
  'fearful': '😨',
  'fear': '😨',
  'sad': '😢',
  'sadness': '😢',
  'happy': '😊',
  'happiness': '😊',
  'joy': '😊',
  'surprised': '😲',
  'surprise': '😲',
  'disgusted': '🤢',
  'disgust': '🤢',
  'neutral': '😐',
  'calm': '😌',
};

String emotionEmoji(String emotion) =>
    _emotionEmoji[emotion.trim().toLowerCase()] ?? '🎭';

String capitalizeEmotion(String e) {
  final t = e.trim();
  if (t.isEmpty) return '';
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

/// The pipeline emits confidence as 0..1; the UI shows a percentage. Values
/// already in 0..100 are passed through unchanged.
double normalizeConfidencePct(num? raw) {
  if (raw == null) return 0;
  final v = raw.toDouble();
  if (v <= 1.0) return (v * 100).clamp(0, 100);
  return v.clamp(0, 100);
}

/// "0.5s-3.2s" → "0:00" (start, mm:ss). Returns '' when not parseable.
String timeRangeStart(String? timeRange) {
  final secs = timeRangeStartSeconds(timeRange);
  if (secs == null) return '';
  return formatClock(secs.toDouble());
}

/// Seconds → "m:ss" clock label (e.g. 7.7 → "0:07"). Negative/NaN → "0:00".
String formatClock(double seconds) {
  if (seconds.isNaN || seconds < 0) seconds = 0;
  final total = seconds.round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// "0:00 – 0:08" style label for a start/end pair in seconds.
String clockRange(double startSeconds, double endSeconds) =>
    '${formatClock(startSeconds)} – ${formatClock(endSeconds)}';

/// First number in a "Xs-Ys" range, in whole seconds. Null when not parseable.
int? timeRangeStartSeconds(String? timeRange) {
  if (timeRange == null) return null;
  final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(timeRange);
  if (m == null) return null;
  return double.tryParse(m.group(1)!)?.round();
}

/// Parses a "5.2s-7.5s" style range into precise (start, end) seconds.
/// Either component may be null when the range is missing / "N/A".
({double? start, double? end}) timeRangeSeconds(String? timeRange) {
  if (timeRange == null) return (start: null, end: null);
  final nums = RegExp(r'([0-9]+(?:\.[0-9]+)?)')
      .allMatches(timeRange)
      .map((m) => double.tryParse(m.group(1)!))
      .toList();
  final start = nums.isNotEmpty ? nums[0] : null;
  final end = nums.length > 1 ? nums[1] : null;
  return (start: start, end: end);
}

/// Precise (start, end) seconds for a sentence row, reading numeric
/// `t_start`/`t_end` (aligned rows) first, then falling back to parsing a
/// `time_range` string (`sentence_results` rows). Nulls when unavailable.
({double? start, double? end}) sentenceTimeWindowSeconds(
  Map<String, dynamic> row,
) {
  final ts = _asDouble(row['t_start']);
  if (ts != null) {
    return (start: ts, end: _asDouble(row['t_end']));
  }
  return timeRangeSeconds(row['time_range']?.toString());
}

/// A "0:05 – 0:07" range label (or just the start when no end is known).
String clockRangeLabel(double? start, double? end) {
  if (start == null) return '';
  if (end == null) return formatClock(start);
  return clockRange(start, end);
}

/// Per-sentence emotion rows for a channel: `video` (facial) or `vocal`.
List<Map<String, dynamic>> evaluationSentenceResults(
  Map<String, dynamic>? detail, {
  required String channel,
}) {
  if (detail == null) return const [];
  final key =
      channel == 'video' ? 'detected_emotions_video' : 'detected_emotions_vocal';
  final block = detail[key];
  if (block is! Map) return const [];
  final results = block['sentence_results'];
  if (results is! List) return const [];
  return results
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .toList();
}

/// True when the evaluation row carries any rich breakdown for [channel].
bool hasSentenceBreakdown(Map<String, dynamic>? detail, {required String channel}) =>
    evaluationSentenceResults(detail, channel: channel).isNotEmpty;

/// One entry of the audio timeline (`tone_analysis.segments[]`). Each segment
/// covers [startSeconds]–[endSeconds] of the recording and carries the prosody
/// metrics the pipeline measured for that slice.
class EvaluationToneSegment {
  const EvaluationToneSegment({
    required this.index,
    required this.startSeconds,
    required this.endSeconds,
    required this.emotion,
    required this.content,
    required this.pitchVariation,
    required this.loudnessVariation,
  });

  final int index;
  final double startSeconds;
  final double endSeconds;
  final String emotion;
  final String content;
  final double pitchVariation;
  final double loudnessVariation;

  String get clockLabel => clockRange(startSeconds, endSeconds);
  double get durationSeconds =>
      (endSeconds - startSeconds).clamp(0, double.infinity);
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// Parses the timestamped prosody timeline from `tone_analysis.segments`.
///
/// This is the per-segment breakdown of the audio (always present once an
/// evaluation completes — even without script alignment the pipeline emits a
/// single whole-clip segment). Returns an empty list when absent.
List<EvaluationToneSegment> toneSegmentsFromEvaluation(
  Map<String, dynamic>? detail,
) {
  if (detail == null) return const [];
  final tone = detail['tone_analysis'];
  if (tone is! Map) return const [];
  final segments = tone['segments'];
  if (segments is! List) return const [];

  final out = <EvaluationToneSegment>[];
  for (var i = 0; i < segments.length; i++) {
    final raw = segments[i];
    if (raw is! Map) continue;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final start = _asDouble(m['t_start']) ?? 0;
    final end = _asDouble(m['t_end']) ?? start;
    out.add(
      EvaluationToneSegment(
        index: (m['index'] is num) ? (m['index'] as num).toInt() : i,
        startSeconds: start,
        endSeconds: end,
        emotion: (m['emotion'] ?? '').toString(),
        content: (m['content'] ?? '').toString().trim(),
        pitchVariation: _asDouble(m['pitch_variation']) ?? 0,
        loudnessVariation: _asDouble(m['loudness_variation']) ?? 0,
      ),
    );
  }
  return out;
}

/// True when a timestamped audio timeline is available.
bool hasToneTimeline(Map<String, dynamic>? detail) =>
    toneSegmentsFromEvaluation(detail).isNotEmpty;

/// Whole-clip vocal emotion summary from `detected_emotions_vocal` for when no
/// per-sentence breakdown exists. Returns null when the block is missing.
({String emotion, double confidencePct, int score})? wholeClipVocalEmotion(
  Map<String, dynamic>? detail,
) {
  if (detail == null) return null;
  final block = detail['detected_emotions_vocal'];
  if (block is! Map) return null;
  final primary = (block['primary'] ?? '').toString().trim();
  if (primary.isEmpty) return null;
  final score = block['score'];
  return (
    emotion: primary,
    confidencePct: normalizeConfidencePct(block['confidence'] as num?),
    score: score is num ? score.round() : 0,
  );
}

Map<String, dynamic>? _scriptAlignmentBlock(Map<String, dynamic>? detail) {
  if (detail == null) return null;
  final raw = detail['script_alignment_details'];
  if (raw is! Map) return null;
  return raw.map((k, v) => MapEntry(k.toString(), v));
}

/// ASR transcript from `script_alignment_details.transcript`, if any.
String? evaluationTranscript(Map<String, dynamic>? detail) {
  final block = _scriptAlignmentBlock(detail);
  final text = block?['transcript']?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Script alignment coverage as 0–100 (from `coverage` 0..1 or percent).
int evaluationAlignmentCoveragePct(Map<String, dynamic>? detail) {
  final block = _scriptAlignmentBlock(detail);
  final raw = block?['coverage'];
  if (raw is! num) return 0;
  final v = raw.toDouble();
  return (v <= 1 ? v * 100 : v).round().clamp(0, 100);
}

/// Rows from `script_alignment_details.sentences_aligned` (includes estimated
/// timelines when word-level alignment failed).
List<Map<String, dynamic>> scriptAlignedSentences(
  Map<String, dynamic>? detail,
) {
  final block = _scriptAlignmentBlock(detail);
  final rows = block?['sentences_aligned'];
  if (rows is! List) return const [];
  return rows
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .toList();
}

/// User-facing explanation when per-sentence emotion rows are missing.
String sentenceBreakdownMessage(Map<String, dynamic>? detail) {
  final transcript = evaluationTranscript(detail);
  final coverage = evaluationAlignmentCoveragePct(detail);
  final aligned = scriptAlignedSentences(detail);
  final block = _scriptAlignmentBlock(detail);
  final asrUnavailable = block?['asr_status']?.toString() == 'unavailable';

  if (asrUnavailable && aligned.isNotEmpty) {
    return 'The speech-to-text service was offline, so timestamps are '
        'estimated from the script length. Per-sentence vocal scores below '
        'use those time windows.';
  }
  if (transcript == null) {
    return 'Speech transcription was unavailable for this run, so a '
        'per-sentence breakdown could not be built. The scores and timeline '
        'above reflect the full recording.';
  }
  if (coverage == 0 && aligned.isEmpty) {
    return 'Transcription completed, but the recording did not match the '
        'script closely enough to assign per-sentence timestamps. '
        'Re-read the script lines provided for this audition.';
  }
  if (coverage == 0) {
    return 'Transcription completed, but word alignment to the script was 0%. '
        'Timestamps below are estimated from the script length. '
        'The actor may have improvised or skipped lines.';
  }
  if (coverage < 50) {
    return 'Transcription completed with $coverage% script alignment. '
        'Some per-sentence detail may be limited where lines were skipped '
        'or changed.';
  }
  return 'Per-sentence detail is limited for this recording. '
      'The scores above reflect the full clip.';
}

String timeRangeFromAlignedRow(Map<String, dynamic> row) {
  final start = _asDouble(row['t_start']);
  final end = _asDouble(row['t_end']);
  if (start != null && end != null) {
    return '${start}s-${end}s';
  }
  return row['time_range']?.toString() ?? '';
}
