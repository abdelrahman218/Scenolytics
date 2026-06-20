import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/script_alignment_parsing.dart';

const double _kMobileBreak = 600;
bool _isWide(BuildContext ctx) =>
    MediaQuery.of(ctx).size.width >= _kMobileBreak;

const _colMatched = Color.fromARGB(255, 34, 255, 0);
const _colAdded = ScenolyticsColors.success;
const _colRemoved = ScenolyticsColors.error;
const _colChanged = ScenolyticsColors.warning;
const _colExtra = ScenolyticsColors.secondary;

enum WordStatus { matched, added, removed, changed, extra }

class AlignedWord {
  final String word;
  final WordStatus status;
  final String? changedFrom;
  const AlignedWord(this.word, this.status, {this.changedFrom});

  factory AlignedWord.fromStatus(String word, String status) {
    final normalized = normalizeAlignmentStatus(status);
    switch (normalized) {
      case 'added':
        return AlignedWord(word, WordStatus.added);
      case 'removed':
        return AlignedWord(word, WordStatus.removed);
      case 'changed':
        return AlignedWord(word, WordStatus.changed);
      case 'extra':
        return AlignedWord(word, WordStatus.extra);
      default:
        return AlignedWord(word, WordStatus.matched);
    }
  }
}

class SentenceAlignment {
  final String label;
  final int score;
  final List<AlignedWord> scriptWords;
  final List<AlignedWord> transcriptWords;

  const SentenceAlignment({
    required this.label,
    required this.score,
    required this.scriptWords,
    required this.transcriptWords,
  });
}

class ChangedWordPair {
  final String scriptWord;
  final String transcriptWord;
  final String sentenceLabel;
  const ChangedWordPair({
    required this.scriptWord,
    required this.transcriptWord,
    required this.sentenceLabel,
  });
}

class AddedWord {
  final String word;
  final String sentenceLabel;
  const AddedWord({required this.word, required this.sentenceLabel});
}

class RemovedWord {
  final String word;
  final String sentenceLabel;
  const RemovedWord({required this.word, required this.sentenceLabel});
}

class AlignmentResult {
  final String actorName;
  final int age;
  final int score;
  final int matched;
  final int added;
  final int removed;
  final int changed;
  final List<ChangedWordPair> changedPairs;
  final List<AddedWord> addedWords;
  final List<RemovedWord> removedWords;
  final List<SentenceAlignment> sentences;
  final String? transcript;

  const AlignmentResult({
    required this.actorName,
    required this.age,
    required this.score,
    required this.matched,
    required this.added,
    required this.removed,
    required this.changed,
    required this.changedPairs,
    required this.addedWords,
    required this.removedWords,
    required this.sentences,
    this.transcript,
  });

  /// Builds the script-alignment view from the AI evaluation payload
  /// (`script_alignment_details`). Returns null when no alignment data exists.
  static AlignmentResult? fromEvaluation(
    Map<String, dynamic>? detail,
    ActorAuditionSubmission submission,
  ) {
    if (detail == null) return null;
    final raw = detail['script_alignment_details'];
    if (raw is! Map) return null;
    final d = raw.map((k, v) => MapEntry(k.toString(), v));

    List<dynamic> asList(Object? v) => v is List ? v : const [];
    int countOf(String countKey, String listKey) {
      final c = d[countKey];
      if (c is num) return c.toInt();
      return asList(d[listKey]).length;
    }

    String wordText(Object? item) {
      if (item is String) return item;
      if (item is Map) {
        return (item['word'] ??
                item['text'] ??
                item['script'] ??
                item['expected'] ??
                '')
            .toString();
      }
      return item?.toString() ?? '';
    }

    final changedPairs = asList(d['changed_words']).map((item) {
      if (item is Map) {
        final m = item.map((k, v) => MapEntry(k.toString(), v));
        final script = (m['script'] ??
                m['expected'] ??
                m['from'] ??
                m['original'] ??
                m['word'] ??
                '')
            .toString();
        final transcript =
            (m['transcript'] ?? m['actual'] ?? m['to'] ?? m['hypothesis'] ?? '')
                .toString();
        return ChangedWordPair(
          scriptWord: script,
          transcriptWord: transcript,
          sentenceLabel: (m['sentence'] ?? '').toString(),
        );
      }
      return ChangedWordPair(
        scriptWord: wordText(item),
        transcriptWord: '',
        sentenceLabel: '',
      );
    }).toList();

    final addedWords = asList(d['added_words'])
        .map((w) => AddedWord(word: wordText(w), sentenceLabel: ''))
        .toList();
    final removedWords = asList(d['skipped_words'])
        .map((w) => RemovedWord(word: wordText(w), sentenceLabel: ''))
        .toList();

    final overall = submission.scriptMatchScore;
    final globalRows = collectAlignmentTokenRows(d);
    final sentences = <SentenceAlignment>[];
    final aligned = asList(d['sentences_aligned']);
    for (var i = 0; i < aligned.length; i++) {
      final s = aligned[i];
      if (s is! Map) continue;
      final m = s.map((k, v) => MapEntry(k.toString(), v));
      final content = (m['content'] ?? m['sentence'] ?? m['script'] ?? '')
          .toString()
          .trim();
      if (content.isEmpty) continue;

      final sides = buildSentenceWordSides(
        sentence: m,
        sentenceIndex: i,
        globalRows: globalRows,
      );

      final start = m['t_start'];
      final end = m['t_end'];
      final timeLabel = (start is num && end is num)
          ? ' (${start.toStringAsFixed(1)}s–${end.toStringAsFixed(1)}s)'
          : '';
      final num? rawScore = m['score'] as num?;
      final num? coverage = m['coverage'] as num?;
      final sentScore = rawScore != null
          ? rawScore.round()
          : coverage != null
              ? (coverage <= 1 ? (coverage * 100).round() : coverage.round())
              : overall;

      sentences.add(
        SentenceAlignment(
          label: 'Sentence ${i + 1}$timeLabel',
          score: sentScore.clamp(0, 100),
          scriptWords: [
            for (var w = 0; w < sides.scriptWords.length; w++)
              AlignedWord.fromStatus(
                sides.scriptWords[w],
                w < sides.scriptStatuses.length
                    ? sides.scriptStatuses[w]
                    : 'matched',
              ),
          ],
          transcriptWords: [
            for (var w = 0; w < sides.transcriptWords.length; w++)
              AlignedWord.fromStatus(
                sides.transcriptWords[w],
                w < sides.transcriptStatuses.length
                    ? sides.transcriptStatuses[w]
                    : 'matched',
              ),
          ],
        ),
      );
    }

    final heard = d['transcript']?.toString().trim() ?? '';

    return AlignmentResult(
      actorName:
          submission.actorName.trim().isEmpty ? 'Actor' : submission.actorName.trim(),
      age: submission.age,
      score: overall,
      matched: countOf('matched_word_count', 'matched_words'),
      added: countOf('added_word_count', 'added_words'),
      removed: countOf('skipped_word_count', 'skipped_words'),
      changed: countOf('changed_word_count', 'changed_words'),
      changedPairs: changedPairs,
      addedWords: addedWords,
      removedWords: removedWords,
      sentences: sentences,
      transcript: heard.isEmpty ? null : heard,
    );
  }
}

class ScriptAlignmentScorePage extends StatelessWidget {
  const ScriptAlignmentScorePage({
    super.key,
    required this.submission,
    this.result,
    this.nested = false,
  });

  final ActorAuditionSubmission submission;
  final AlignmentResult? result;

  /// When true, omits the page header so this can live inside a parent tab.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final pending = !submission.evaluationCompleted;
    final data = pending
        ? null
        : (result ??
            AlignmentResult.fromEvaluation(submission.evaluationDetail, submission));
    final wide = _isWide(context);

    final body = Column(
      children: [
        if (!nested) _AppBar(),
        Expanded(
          child: pending
              ? const _ScriptAlignmentPending()
              : data == null
                  ? const _ScriptAlignmentUnavailable()
                  : wide
                      ? _WebLayout(data: data)
                      : _MobileLayout(data: data),
        ),
      ],
    );
    if (nested) {
      return ColoredBox(
        color: ScenolyticsColors.pageBackground,
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      body: body,
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final AlignmentResult data;
  const _MobileLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeading('WORD STATISTICS'),
        const SizedBox(height: 10),
        _WordStatsGrid(data: data),
        const SizedBox(height: 16),
        _SectionHeading('SENTENCE COMPARISON'),
        const SizedBox(height: 10),
        if (data.transcript != null && data.transcript!.isNotEmpty) ...[
          _TranscriptOnlyCard(
            transcript: data.transcript!,
            showAlignmentWarning: data.sentences.isEmpty,
          ),
          const SizedBox(height: 10),
        ],
        ...data.sentences.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SentenceAccordion(sentence: s),
        )),
        const SizedBox(height: 16),
        _SectionHeading('WORD LISTS'),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colChanged,
          label: 'Changed Words',
          count: data.changedPairs.length,
          children: data.changedPairs.map((p) => _ChangedWordRow(pair: p)).toList(),
        ),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colAdded,
          label: 'Added Words',
          count: data.addedWords.length,
          children: data.addedWords.map((w) => _AddedWordRow(item: w)).toList(),
        ),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colRemoved,
          label: 'Removed Words',
          count: data.removedWords.length,
          children: data.removedWords.map((w) => _RemovedWordRow(item: w)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  final AlignmentResult data;
  const _WebLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        _SectionHeading('WORD STATISTICS'),
        const SizedBox(height: 16),
        _WordStatsGrid(data: data),
        const SizedBox(height: 16),
        _SectionHeading('SENTENCE COMPARISON'),
        const SizedBox(height: 10),
        if (data.transcript != null && data.transcript!.isNotEmpty) ...[
          _TranscriptOnlyCard(
            transcript: data.transcript!,
            showAlignmentWarning: data.sentences.isEmpty,
          ),
          const SizedBox(height: 10),
        ],
        ...data.sentences.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SentenceAccordion(sentence: s),
        )),
        const SizedBox(height: 16),
        _SectionHeading('WORD LISTS'),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colChanged,
          label: 'Changed Words',
          count: data.changedPairs.length,
          children: data.changedPairs.map((p) => _ChangedWordRow(pair: p)).toList(),
        ),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colAdded,
          label: 'Added Words',
          count: data.addedWords.length,
          children: data.addedWords.map((w) => _AddedWordRow(item: w)).toList(),
        ),
        const SizedBox(height: 10),
        _WordListSection(
          color: _colRemoved,
          label: 'Removed Words',
          count: data.removedWords.length,
          children: data.removedWords.map((w) => _RemovedWordRow(item: w)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
      decoration: const BoxDecoration(gradient: ScenolyticsColors.heroBarGradient),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Script Alignment Score',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600,
              color: Colors.white, letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceAccordion extends StatefulWidget {
  final SentenceAlignment sentence;
  const _SentenceAccordion({required this.sentence});

  @override
  State<_SentenceAccordion> createState() => _SentenceAccordionState();
}

class _SentenceAccordionState extends State<_SentenceAccordion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Auto-expand first sentence
    _expanded = widget.sentence.label == 'Sentence 1';
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _expanded ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Color _scoreColor(int score) {
    if (score >= 85) return _colMatched;
    if (score >= 70) return _colAdded;
    return _colRemoved;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(widget.sentence.score);

    return Container(
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sentence.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ScenolyticsColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.sentence.score}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ScenolyticsColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          SizeTransition(
            sizeFactor: _animation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  height: 1,
                  color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.6),
                ),
                _ExpandedWordRow(
                  label: 'SCRIPT',
                  words: widget.sentence.scriptWords,
                ),
                Divider(
                  height: 1,
                  color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.6),
                ),
                _ExpandedWordRow(
                  label: 'TRANSCRIPT',
                  words: widget.sentence.transcriptWords,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedWordRow extends StatelessWidget {
  final String label;
  final List<AlignedWord> words;
  const _ExpandedWordRow({required this.label, required this.words});

  Color _colorFor(WordStatus s) {
    switch (s) {
      case WordStatus.matched: return _colMatched;
      case WordStatus.added:   return _colAdded;
      case WordStatus.removed: return _colRemoved;
      case WordStatus.changed: return _colChanged;
      case WordStatus.extra:   return _colExtra;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: label == 'SCRIPT'
                      ? ScenolyticsColors.primary
                      : ScenolyticsColors.accentCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ScenolyticsColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (words.isEmpty)
            Text(
              label == 'TRANSCRIPT'
                  ? 'No speech was transcribed for this line.'
                  : '—',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: ScenolyticsColors.textMuted,
              ),
            )
          else
            Wrap(
            spacing: 4,
            runSpacing: 6,
            children: words.map((w) {
              final color = _colorFor(w.status);
              final isMatched = w.status == WordStatus.matched;
              final isChanged = w.status == WordStatus.changed;
              final isRemoved = w.status == WordStatus.removed;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMatched
                      ? Colors.transparent
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: isChanged
                      ? Border(bottom: BorderSide(color: color, width: 2))
                      : isRemoved
                          ? Border.all(color: color.withValues(alpha: 0.4))
                          : null,
                ),
                child: Text(
                  isRemoved ? w.word : w.word,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isMatched ? FontWeight.w400 : FontWeight.w600,
                    color: color,
                    decoration: isRemoved
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WordStatsGrid extends StatelessWidget {
  final AlignmentResult data;
  const _WordStatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawMax = [data.matched, data.added, data.removed, data.changed]
        .reduce(math.max)
        .toDouble();
    final maxVal = rawMax <= 0 ? 1.0 : rawMax;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Matched',
                count: data.matched,
                color: _colMatched,
                progress: data.matched / maxVal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Added',
                count: data.added,
                color: _colAdded,
                progress: data.added / maxVal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Removed',
                count: data.removed,
                color: _colRemoved,
                progress: data.removed / maxVal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Changed',
                count: data.changed,
                color: _colChanged,
                progress: data.changed / maxVal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final double progress;
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: ScenolyticsColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ScenolyticsColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordListSection extends StatefulWidget {
  final Color color;
  final String label;
  final int count;
  final List<Widget> children;

  const _WordListSection({
    required this.color,
    required this.label,
    required this.count,
    required this.children,
  });

  @override
  State<_WordListSection> createState() => _WordListSectionState();
}

class _WordListSectionState extends State<_WordListSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ScenolyticsColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ScenolyticsColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items
          SizeTransition(
            sizeFactor: _animation,
            child: Column(
              children: widget.children
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          Divider(
                            height: 1,
                            color: ScenolyticsColors.outlineSoft
                                .withValues(alpha: 0.5),
                          ),
                          e.value,
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangedWordRow extends StatelessWidget {
  final ChangedWordPair pair;
  const _ChangedWordRow({required this.pair});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _WordPill(text: '"${pair.scriptWord}"', color: _colRemoved, strikethrough: false),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: ScenolyticsColors.textMuted),
          const SizedBox(width: 8),
          _WordPill(text: '"${pair.transcriptWord}"', color: _colChanged, strikethrough: false),
          const Spacer(),
          Text(
            pair.sentenceLabel,
            style: const TextStyle(
              fontSize: 11,
              color: ScenolyticsColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddedWordRow extends StatelessWidget {
  final AddedWord item;
  const _AddedWordRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _colAdded.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text('+',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _colAdded,
                )),
            ),
          ),
          const SizedBox(width: 10),
          _WordPill(text: '"${item.word}"', color: _colAdded, strikethrough: false),
          const Spacer(),
          Text(
            item.sentenceLabel,
            style: const TextStyle(
              fontSize: 11,
              color: ScenolyticsColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovedWordRow extends StatelessWidget {
  final RemovedWord item;
  const _RemovedWordRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _colRemoved.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text('−',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _colRemoved,
                )),
            ),
          ),
          const SizedBox(width: 10),
          _WordPill(text: '"${item.word}"', color: _colRemoved, strikethrough: true),
          const Spacer(),
          Text(
            item.sentenceLabel,
            style: const TextStyle(
              fontSize: 11,
              color: ScenolyticsColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool strikethrough;
  const _WordPill({required this.text, required this.color, required this.strikethrough});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: color,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ScenolyticsColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Shows the full ASR transcript ("what we heard"). Always rendered above the
/// per-sentence comparison so the director can read the recognized speech in
/// full; [showAlignmentWarning] adds a note when no sentence aligned at all.
class _TranscriptOnlyCard extends StatelessWidget {
  const _TranscriptOnlyCard({
    required this.transcript,
    this.showAlignmentWarning = false,
  });

  final String transcript;
  final bool showAlignmentWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: ScenolyticsColors.accentCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'FULL TRANSCRIPT — WHAT WE HEARD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: ScenolyticsColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transcript,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: ScenolyticsColors.textPrimary,
            ),
          ),
          if (showAlignmentWarning) ...[
            const SizedBox(height: 8),
            const Text(
              'Word alignment to the script was 0% — the actor may have read '
              'different lines than the audition script.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: ScenolyticsColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Evaluation finished but produced no script alignment (e.g. the audition had
/// no script attached, so there was nothing to align against).
class _ScriptAlignmentUnavailable extends StatelessWidget {
  const _ScriptAlignmentUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: ScenolyticsColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScenolyticsColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.menu_book_outlined,
                      size: 20, color: ScenolyticsColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No script alignment available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ScenolyticsColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'This audition did not include a script to compare against, so '
                'no word-level alignment was produced for this submission.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ScenolyticsColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScriptAlignmentPending extends StatelessWidget {
  const _ScriptAlignmentPending();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: ScenolyticsColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScenolyticsColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Script alignment is pending',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ScenolyticsColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'The AI evaluation has not completed yet for this submission. '
                'Word-level statistics and sentence comparisons will appear '
                'here as soon as analysis finishes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ScenolyticsColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}