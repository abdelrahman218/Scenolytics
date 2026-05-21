import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';

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
  });

  factory AlignmentResult.mock() => const AlignmentResult(
    actorName: 'ef',
    age: 20,
    score: 87,
    matched: 156,
    added: 12,
    removed: 8,
    changed: 24,
    changedPairs: [
      ChangedWordPair(scriptWord: 'Hello', transcriptWord: 'Hi', sentenceLabel: 'Sentence 1'),
      ChangedWordPair(scriptWord: 'الزقازيق', transcriptWord: 'القاهره', sentenceLabel: 'Sentence 2'),
      ChangedWordPair(scriptWord: 'say', transcriptWord: 'tel', sentenceLabel: 'Sentence 3'),
      ChangedWordPair(scriptWord: 'smoked', transcriptWord: 'smoked', sentenceLabel: 'Sentence 4'),
      ChangedWordPair(scriptWord: 'ticket', transcriptWord: 'those', sentenceLabel: 'Sentence 5'),
    ],
    addedWords: [
      AddedWord(word: 'actually', sentenceLabel: 'Sentence 3'),
      AddedWord(word: 'really', sentenceLabel: 'Sentence 5'),
      AddedWord(word: 'um', sentenceLabel: 'Sentence 7'),
      AddedWord(word: 'basically', sentenceLabel: 'Sentence 8'),
    ],
    removedWords: [
      RemovedWord(word: 'important', sentenceLabel: 'Sentence 2'),
      RemovedWord(word: 'very', sentenceLabel: 'Sentence 4'),
      RemovedWord(word: 'please', sentenceLabel: 'Sentence 6'),
    ],
    sentences: [
      SentenceAlignment(
        label: 'Sentence 1',
        score: 90,
        scriptWords: [
          AlignedWord('Hello', WordStatus.changed, changedFrom: 'Hello'),
          AlignedWord('everyone,', WordStatus.matched),
          AlignedWord('welcome', WordStatus.matched),
          AlignedWord('to', WordStatus.matched),
          AlignedWord('the', WordStatus.matched),
          AlignedWord('presentation', WordStatus.matched),
          AlignedWord('today.', WordStatus.matched),
        ],
        transcriptWords: [
          AlignedWord('Hi', WordStatus.changed),
          AlignedWord('everyone,', WordStatus.matched),
          AlignedWord('welcome', WordStatus.matched),
          AlignedWord('to', WordStatus.matched),
          AlignedWord('the', WordStatus.matched),
          AlignedWord('presentation', WordStatus.matched),
          AlignedWord('today.', WordStatus.matched),
        ],
      ),
      SentenceAlignment(
        label: 'Sentence 2',
        score: 72,
        scriptWords: [
          AlignedWord('I', WordStatus.matched),
          AlignedWord('was', WordStatus.matched),
          AlignedWord('here', WordStatus.matched),
          AlignedWord('that', WordStatus.matched),
          AlignedWord('I', WordStatus.matched),
          AlignedWord('forced', WordStatus.matched),
          AlignedWord('my', WordStatus.matched),
          AlignedWord('way', WordStatus.matched),
          AlignedWord('in', WordStatus.matched),
          AlignedWord('important', WordStatus.removed),
        ],
        transcriptWords: [
          AlignedWord('I', WordStatus.matched),
          AlignedWord('was', WordStatus.matched),
          AlignedWord('here', WordStatus.matched),
          AlignedWord('that', WordStatus.matched),
          AlignedWord('I', WordStatus.matched),
          AlignedWord('forced', WordStatus.matched),
          AlignedWord('my', WordStatus.matched),
          AlignedWord('way', WordStatus.matched),
          AlignedWord('in', WordStatus.matched),
        ],
      ),
      SentenceAlignment(
        label: 'Sentence 3',
        score: 91,
        scriptWords: [
          AlignedWord('tel', WordStatus.matched),
          AlignedWord('the', WordStatus.matched),
          AlignedWord('DEA', WordStatus.matched),
          AlignedWord('once', WordStatus.matched),
          AlignedWord('I', WordStatus.matched),
          AlignedWord('leave', WordStatus.matched),
        ],
        transcriptWords: [
          AlignedWord('tel', WordStatus.matched),
          AlignedWord('the', WordStatus.matched),
          AlignedWord('DEA', WordStatus.matched),
          AlignedWord('once', WordStatus.matched),
          AlignedWord('I', WordStatus.matched),
          AlignedWord('leave', WordStatus.matched),
          AlignedWord('actually', WordStatus.added),
        ],
      ),
      SentenceAlignment(
        label: 'Sentence 4',
        score: 88,
        scriptWords: [
          AlignedWord('and', WordStatus.matched),
          AlignedWord('say', WordStatus.changed, changedFrom: 'say'),
          AlignedWord('to', WordStatus.matched),
          AlignedWord('them', WordStatus.matched),
          AlignedWord('very', WordStatus.removed),
        ],
        transcriptWords: [
          AlignedWord('and', WordStatus.matched),
          AlignedWord('tel', WordStatus.changed),
          AlignedWord('to', WordStatus.matched),
          AlignedWord('them', WordStatus.matched),
        ],
      ),
    ],
  );

  factory AlignmentResult.mockForSubmission(ActorAuditionSubmission s) {
    final base = AlignmentResult.mock();
    return AlignmentResult(
      actorName: s.actorName.trim().isEmpty ? base.actorName : s.actorName.trim(),
      age: s.age > 0 ? s.age : base.age,
      score: s.scriptMatchScore,
      matched: base.matched,
      added: base.added,
      removed: base.removed,
      changed: base.changed,
      changedPairs: base.changedPairs,
      addedWords: base.addedWords,
      removedWords: base.removedWords,
      sentences: base.sentences,
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
        : (result ?? AlignmentResult.mockForSubmission(submission));
    final wide = _isWide(context);

    final body = Column(
      children: [
        if (!nested) _AppBar(),
        Expanded(
          child: pending
              ? const _ScriptAlignmentPending()
              : wide
                  ? _WebLayout(data: data!)
                  : _MobileLayout(data: data!),
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
      case WordStatus.matched: return ScenolyticsColors.textPrimary;
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
    final maxVal = [data.matched, data.added, data.removed, data.changed]
        .reduce(math.max)
        .toDouble();

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