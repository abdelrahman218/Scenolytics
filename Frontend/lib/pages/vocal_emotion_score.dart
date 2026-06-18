import 'package:flutter/material.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/evaluation_parsing.dart';
import '../utils/playback_candidates.dart';
import '../widgets/evaluation_recording_player.dart';

const double _kMobileBreak = 600;
bool _isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= _kMobileBreak;

class SentenceEmotion {
  final String timestamp;
  final String text;
  final String emotion;
  final String emoji;
  final double confidence;

  const SentenceEmotion({
    required this.timestamp,
    required this.text,
    required this.emotion,
    required this.emoji,
    required this.confidence,
  });
}

/// Builds the per-sentence vocal-emotion breakdown from the AI evaluation
/// payload (`detected_emotions_vocal.sentence_results`). Returns an empty list
/// when no per-sentence data is present.
List<SentenceEmotion> vocalSentencesFromEvaluation(
  Map<String, dynamic>? detail,
) {
  return evaluationSentenceResults(detail, channel: 'vocal').map((r) {
    final detected = (r['detected_emotion'] ?? '').toString();
    return SentenceEmotion(
      timestamp: timeRangeStart(r['time_range']?.toString()),
      text: (r['sentence'] ?? '').toString(),
      emotion: detected.isEmpty ? 'No speech' : capitalizeEmotion(detected),
      emoji: detected.isEmpty ? '🔇' : emotionEmoji(detected),
      confidence: normalizeConfidencePct(r['confidence'] as num?),
    );
  }).toList();
}

class VocalEmotionScorePage extends StatelessWidget {
  const VocalEmotionScorePage({
    super.key,
    required this.submission,
    this.sentences,
    this.nested = false,
  });

  final ActorAuditionSubmission submission;

  /// Per-sentence breakdown. When null it is derived from the submission's
  /// AI evaluation payload (`detected_emotions_vocal.sentence_results`).
  final List<SentenceEmotion>? sentences;

  /// When true, omits the page header so this can live inside a parent tab.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final actorName = submission.actorName.trim().isEmpty ? 'Actor' : submission.actorName.trim();
    final actorAge = submission.age;
    final actorScore = submission.vocalToneScore;
    final pending = !submission.evaluationCompleted;
    final resolvedSentences =
        sentences ?? vocalSentencesFromEvaluation(submission.evaluationDetail);
    final candidates = submissionPlaybackCandidates(submission);
    final body = Column(
      children: [
        if (!nested) _AppBar(),
        Expanded(
          child: pending
              ? _PendingAnalysisView(
                  actorName: actorName,
                  actorAge: actorAge,
                  label: 'Vocal emotion analysis',
                )
              : wide
                  ? _WebLayout(
                      sentences: resolvedSentences,
                      actorName: actorName,
                      actorAge: actorAge,
                      actorScore: actorScore,
                      candidates: candidates,
                    )
                  : _MobileLayout(
                      sentences: resolvedSentences,
                      actorName: actorName,
                      actorAge: actorAge,
                      actorScore: actorScore,
                      candidates: candidates,
                    ),
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
  final List<SentenceEmotion> sentences;
  final String actorName;
  final int actorAge;
  final int actorScore;
  final List<String> candidates;
  const _MobileLayout({
    required this.sentences,
    required this.actorName,
    required this.actorAge,
    required this.actorScore,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActorCard(name: actorName, age: actorAge, score: actorScore),
        const SizedBox(height: 14),
        EvaluationAudioPlayer(candidates: candidates),
        const SizedBox(height: 14),
        const _SectionHeading('Emotion Detected By Sentence'),
        const SizedBox(height: 10),
        if (sentences.isEmpty)
          const _NoSentenceBreakdown()
        else
          ...sentences.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SentenceCard(sentence: s),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  final List<SentenceEmotion> sentences;
  final String actorName;
  final int actorAge;
  final int actorScore;
  final List<String> candidates;
  const _WebLayout({
    required this.sentences,
    required this.actorName,
    required this.actorAge,
    required this.actorScore,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        _ActorCard(name: actorName, age: actorAge, score: actorScore),
        const SizedBox(height: 16),
        EvaluationAudioPlayer(candidates: candidates),
        const SizedBox(height: 20),
        const _SectionHeading('Emotion Detected By Sentence'),
        const SizedBox(height: 14),
        if (sentences.isEmpty)
          const _NoSentenceBreakdown()
        else
          _SentenceGrid(sentences: sentences),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Shown when the evaluation completed but carries no per-sentence breakdown.
class _NoSentenceBreakdown extends StatelessWidget {
  const _NoSentenceBreakdown();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: ScenolyticsColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No per-sentence breakdown is available for this submission. '
              'The overall score above reflects the full recording.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: ScenolyticsColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceGrid extends StatelessWidget {
  final List<SentenceEmotion> sentences;
  const _SentenceGrid({required this.sentences});

  @override
  Widget build(BuildContext context) {
    final rows = <List<SentenceEmotion>>[];
    for (var i = 0; i < sentences.length; i += 2) {
      rows.add(sentences.sublist(i, (i + 2).clamp(0, sentences.length)));
    }
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SentenceCard(sentence: row[0])),
              if (row.length > 1) ...[
                const SizedBox(width: 20),
                Expanded(child: _SentenceCard(sentence: row[1])),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }).toList(),
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
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const Text(
            'Vocal Emotion Score',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _ActorCard extends StatelessWidget {
  final String name;
  final int age;
  final int score;
  const _ActorCard({required this.name, required this.age, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ScenolyticsColors.primary, ScenolyticsColors.accentCyan],
              ),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ScenolyticsColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Age: $age',
                    style: const TextStyle(
                        fontSize: 12, color: ScenolyticsColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: ScenolyticsColors.accentCyan, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$score',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScenolyticsColors.primary)),
          ),
        ],
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
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ScenolyticsColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final SentenceEmotion sentence;
  const _SentenceCard({required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentence.timestamp,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ScenolyticsColors.textMuted,
                    letterSpacing: 0.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sentence.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ScenolyticsColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(sentence.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sentence.emotion,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ScenolyticsColors.accentCyan,
                    ),
                  ),
                ),
                Text(
                  '${sentence.confidence.toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ScenolyticsColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _AnimatedProgressBar(value: sentence.confidence / 100),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double value;
  const _AnimatedProgressBar({required this.value});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: _anim.value,
          minHeight: 6,
          backgroundColor: ScenolyticsColors.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation<Color>(
              ScenolyticsColors.accentCyanSoft),
        ),
      ),
    );
  }
}

class _PendingAnalysisView extends StatelessWidget {
  final String actorName;
  final int actorAge;
  final String label;
  const _PendingAnalysisView({
    required this.actorName,
    required this.actorAge,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ActorCardPending(name: actorName, age: actorAge),
        const SizedBox(height: 16),
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
                      '$label is pending',
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
                'The detailed breakdown, scores, and sentence-level results '
                'will appear here as soon as analysis finishes.',
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

class _ActorCardPending extends StatelessWidget {
  final String name;
  final int age;
  const _ActorCardPending({required this.name, required this.age});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ScenolyticsColors.primary,
                  ScenolyticsColors.accentCyan,
                ],
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ScenolyticsColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Age: $age',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScenolyticsColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ScenolyticsColors.accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ScenolyticsColors.accentCyan.withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ScenolyticsColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}