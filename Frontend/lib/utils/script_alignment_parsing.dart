// Helpers for turning `script_alignment_details` into per-sentence script /
// transcript word rows with match / changed / skipped / added coloring.

/// Normalises backend status strings (✓ Match, skipped, changed, etc.).
String normalizeAlignmentStatus(Object? raw) {
  final s = raw?.toString().trim().toLowerCase() ?? '';
  if (s.isEmpty) return 'matched';
  if (s.contains('match') || s == 'ok' || s.contains('✓')) return 'matched';
  if (s.contains('change') || s.contains('🟡')) return 'changed';
  if (s.contains('skip') ||
      s.contains('remove') ||
      s.contains('missing') ||
      s.contains('🔴')) {
    return 'removed';
  }
  if (s.contains('add') || s.contains('extra') || s.contains('🟢')) {
    return 'added';
  }
  return s;
}

int? _sentenceIndexFrom(Map<String, dynamic> m) {
  final raw = m['sentence_index'] ??
      m['sent_idx'] ??
      m['sentence_idx'] ??
      m['sentence_order'] ??
      m['sentence'];
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final digits = RegExp(r'\d+').firstMatch(raw);
    if (digits != null) return int.tryParse(digits.group(0)!);
  }
  return null;
}

String _wordField(Map<String, dynamic> m, List<String> keys) {
  for (final key in keys) {
    final v = m[key];
    if (v == null) continue;
    final t = v.toString().trim();
    if (t.isNotEmpty && t != '-') return t;
  }
  return '';
}

/// One aligned token from the backend comparison table.
class AlignmentTokenRow {
  const AlignmentTokenRow({
    required this.status,
    required this.script,
    required this.transcript,
    this.sentenceIndex,
  });

  final String status;
  final String script;
  final String transcript;
  final int? sentenceIndex;
}

List<dynamic> _asList(Object? v) => v is List ? v : const [];

/// Collects word-level rows from every key the backend may emit.
List<AlignmentTokenRow> collectAlignmentTokenRows(Map<String, dynamic> d) {
  final rows = <AlignmentTokenRow>[];

  void addRow(Map<String, dynamic> m, {String? defaultStatus}) {
    final script = _wordField(m, const [
      'script',
      'Script',
      'expected',
      'from',
      'original',
      'word',
    ]);
    final transcript = _wordField(m, const [
      'transcript',
      'Transcript',
      'actual',
      'heard',
      'hypothesis',
      'recognized',
      'to',
      'spoken',
      'said',
      'asr',
    ]);
    final status = normalizeAlignmentStatus(
      m['status'] ?? m['Status'] ?? m['type'] ?? defaultStatus ?? 'matched',
    );
    if (script.isEmpty && transcript.isEmpty) return;
    rows.add(
      AlignmentTokenRow(
        status: status,
        script: script,
        transcript: transcript,
        sentenceIndex: _sentenceIndexFrom(m),
      ),
    );
  }

  for (final key in const [
    'aligned_words',
    'alignment',
    'comparison',
    'comparison_rows',
    'alignment_rows',
    'word_alignment',
    'words',
  ]) {
    for (final item in _asList(d[key])) {
      if (item is Map) {
        addRow(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
  }

  for (final item in _asList(d['matched_words'])) {
    if (item is String) {
      final w = item.trim();
      if (w.isEmpty) continue;
      rows.add(
        AlignmentTokenRow(
          status: 'matched',
          script: w,
          transcript: w,
        ),
      );
    } else if (item is Map) {
      addRow(
        item.map((k, v) => MapEntry(k.toString(), v)),
        defaultStatus: 'matched',
      );
    }
  }

  for (final item in _asList(d['skipped_words'])) {
    if (item is String) {
      final w = item.trim();
      if (w.isEmpty) continue;
      rows.add(AlignmentTokenRow(status: 'removed', script: w, transcript: ''));
    } else if (item is Map) {
      addRow(
        item.map((k, v) => MapEntry(k.toString(), v)),
        defaultStatus: 'removed',
      );
    }
  }

  for (final item in _asList(d['added_words'])) {
    if (item is String) {
      final w = item.trim();
      if (w.isEmpty) continue;
      rows.add(AlignmentTokenRow(status: 'added', script: '', transcript: w));
    } else if (item is Map) {
      addRow(
        item.map((k, v) => MapEntry(k.toString(), v)),
        defaultStatus: 'added',
      );
    }
  }

  for (final item in _asList(d['changed_words'])) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry(k.toString(), v));
    addRow(m, defaultStatus: 'changed');
  }

  return rows;
}

List<AlignmentTokenRow> _rowsForSentence(
  List<AlignmentTokenRow> all,
  int sentenceIndex,
  String sentenceContent,
) {
  final tagged = all.where((r) => r.sentenceIndex == sentenceIndex).toList();
  if (tagged.isNotEmpty) return tagged;

  final untagged = all.where((r) => r.sentenceIndex == null).toList();
  if (untagged.isEmpty) return const [];

  final contentLower = sentenceContent.toLowerCase();
  final contentWords = contentLower
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toSet();

  return untagged.where((r) {
    if (r.script.isNotEmpty) {
      return contentWords.contains(r.script.toLowerCase()) ||
          contentLower.contains(r.script.toLowerCase());
    }
    return r.transcript.isNotEmpty;
  }).toList();
}

List<AlignmentTokenRow> _rowsFromSentenceObject(Map<String, dynamic> m) {
  final rows = <AlignmentTokenRow>[];
  for (final key in const ['words', 'alignment', 'comparison', 'tokens']) {
    final list = _asList(m[key]);
    for (final item in list) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final script = _wordField(map, const [
        'script',
        'Script',
        'expected',
        'from',
        'word',
      ]);
      final transcript = _wordField(map, const [
        'transcript',
        'Transcript',
        'actual',
        'heard',
        'to',
        'hypothesis',
      ]);
      final status = normalizeAlignmentStatus(
        map['status'] ?? map['Status'] ?? map['type'] ?? 'matched',
      );
      if (script.isEmpty && transcript.isEmpty) continue;
      rows.add(
        AlignmentTokenRow(
          status: status,
          script: script,
          transcript: transcript,
          sentenceIndex: _sentenceIndexFrom(map),
        ),
      );
    }
    if (rows.isNotEmpty) return rows;
  }
  return rows;
}

/// Builds parallel script / transcript token lists for one sentence.
({List<String> scriptWords, List<String> scriptStatuses, List<String> transcriptWords, List<String> transcriptStatuses})
    buildSentenceWordSides({
  required Map<String, dynamic> sentence,
  required int sentenceIndex,
  required List<AlignmentTokenRow> globalRows,
}) {
  var rows = _rowsFromSentenceObject(sentence);
  if (rows.isEmpty) {
    final content = _wordField(sentence, const [
      'content',
      'sentence',
      'script',
    ]);
    rows = _rowsForSentence(globalRows, sentenceIndex, content);
  }

  final scriptWords = <String>[];
  final scriptStatuses = <String>[];
  final transcriptWords = <String>[];
  final transcriptStatuses = <String>[];

  for (final row in rows) {
    final status = row.status;
    if (row.script.isNotEmpty) {
      scriptWords.add(row.script);
      scriptStatuses.add(status);
    }
    if (row.transcript.isNotEmpty) {
      transcriptWords.add(row.transcript);
      transcriptStatuses.add(
        status == 'removed' ? 'matched' : status,
      );
    }
  }

  // Explicit per-sentence transcript when rows did not carry tokens.
  if (transcriptWords.isEmpty) {
    final heard = _wordField(sentence, const [
      'transcript',
      'hypothesis',
      'recognized',
      'actual',
      'heard',
      'spoken',
      'said',
      'asr',
    ]);
    if (heard.isNotEmpty) {
      for (final w in heard.split(RegExp(r'\s+'))) {
        if (w.isEmpty) continue;
        transcriptWords.add(w);
        transcriptStatuses.add('matched');
      }
    }
  }

  // Script line fallback from content when no row data.
  if (scriptWords.isEmpty) {
    final content = _wordField(sentence, const [
      'content',
      'sentence',
      'script',
    ]);
    for (final w in content.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      scriptWords.add(w);
      scriptStatuses.add('matched');
    }
  }

  return (
    scriptWords: scriptWords,
    scriptStatuses: scriptStatuses,
    transcriptWords: transcriptWords,
    transcriptStatuses: transcriptStatuses,
  );
}
