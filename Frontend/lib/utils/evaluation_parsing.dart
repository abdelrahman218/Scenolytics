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
  final m = secs ~/ 60;
  final s = secs % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// First number in a "Xs-Ys" range, in whole seconds. Null when not parseable.
int? timeRangeStartSeconds(String? timeRange) {
  if (timeRange == null) return null;
  final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(timeRange);
  if (m == null) return null;
  return double.tryParse(m.group(1)!)?.round();
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
