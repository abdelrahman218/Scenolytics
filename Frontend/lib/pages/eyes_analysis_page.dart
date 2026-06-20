import 'package:flutter/material.dart';

import '../config/app_env.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';

class EmotionTransition {
  final int timestampSeconds;
  final String fromEmotion;
  final String toEmotion;
  final String sentence;
  final String? fromSentence;
  final String? toSentence;
  final String? label;
  final double? shiftScore;
  final double? displacement;
  final String? dirBefore;
  final String? dirAfter;
  final String? message;
  final String? beforeImagePath;
  final String? afterImagePath;
  final double? imageAspectRatio;

  const EmotionTransition({
    required this.timestampSeconds,
    required this.fromEmotion,
    required this.toEmotion,
    required this.sentence,
    this.fromSentence,
    this.toSentence,
    this.label,
    this.shiftScore,
    this.displacement,
    this.dirBefore,
    this.dirAfter,
    this.message,
    this.beforeImagePath,
    this.afterImagePath,
    this.imageAspectRatio,
  });

  factory EmotionTransition.fromJson(Map<String, dynamic> json) {
    final timeMs = json['time_ms'];
    final timeSec = json['time_sec'];
    final parsedSeconds = timeSec is num
        ? timeSec.toInt()
        : timeMs is num
            ? (timeMs / 1000).round()
            : 0;

    return EmotionTransition(
      timestampSeconds: parsedSeconds,
      fromEmotion: (json['from_emotion'] ?? 'unknown').toString(),
      toEmotion: (json['to_emotion'] ?? 'unknown').toString(),
      sentence: (json['to_sentence'] ?? json['from_sentence'] ?? '').toString(),
      fromSentence: json['from_sentence']?.toString(),
      toSentence: json['to_sentence']?.toString(),
      label: json['label']?.toString(),
      shiftScore: (json['score'] as num?)?.toDouble(),
      displacement: (json['displacement'] as num?)?.toDouble(),
      dirBefore: json['dir_before']?.toString(),
      dirAfter: json['dir_after']?.toString(),
      message: json['message']?.toString(),
      beforeImagePath: AppEnv.minioObjectUrl(
        (json['before_image'] ??
                json['before_image_url'] ??
                json['before_image_path'])
            ?.toString(),
      ),
      afterImagePath: AppEnv.minioObjectUrl(
        (json['after_image'] ??
                json['after_image_url'] ??
                json['after_image_path'])
            ?.toString(),
      ),
      imageAspectRatio: (json['image_aspect_ratio'] as num?)?.toDouble(),
    );
  }

  String get formattedTime {
    final m = timestampSeconds ~/ 60;
    final s = timestampSeconds % 60;
    return m > 0
        ? '${m}m ${s.toString().padLeft(2, '0')}s'
        : '${s}s';
  }

  bool get hasShift {
    final normalized = label?.toUpperCase();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized != 'NO_SHIFT';
    }

    return (shiftScore ?? 0) > 0;
  }

  String get shiftLabel => (label?.isNotEmpty ?? false)
      ? label!
      : (hasShift ? 'SHIFT' : 'NO_SHIFT');
}

class EyesAnalysisResult {
  final double score;
  final String result;
  final String message;
  final List<EmotionTransition> transitions;

  const EyesAnalysisResult({
    required this.score,
    required this.result,
    required this.message,
    required this.transitions,
  });
}

/// Derives a human-readable label/message from a raw expressiveness score when
/// the backend did not supply one.
String _eyesResultLabel(double score) {
  if (score >= 85) return 'EXPRESSIVE';
  if (score >= 60) return 'MODERATELY EXPRESSIVE';
  if (score >= 30) return 'SUBTLE';
  return 'NEUTRAL';
}

String _eyesResultMessage(double score) {
  if (score >= 85) return 'Eyes moved strongly — strong physical expression';
  if (score >= 60) return 'Moderate eye movement and aperture variation';
  if (score >= 30) return 'Subtle eye movement detected';
  return 'Minimal eye movement detected';
}

const _emotionEmoji = <String, String>{
  'angry':   '😡',
  'fearful': '😨',
  'sad':     '😢',
  'happy':   '😊',
  'surprised': '😲',
  'disgusted': '🤢',
  'neutral': '😐',
};

String _emotionEmoji_(String e) =>
    _emotionEmoji[e.toLowerCase()] ?? '🎭';

const double _kMobileBreak = 600;
const double _kTransitionImageAspectRatio = 16 / 9;

class EyesAnalysisPage extends StatelessWidget {
  /// Parsed eye analysis. Null when the evaluation produced no eye data.
  final EyesAnalysisResult? data;

  /// When true, omits [Scaffold]/[AppBar] so this can live inside a parent
  /// tab or scroll region without a nested app bar.
  final bool nested;

  /// AI evaluation has not finished for this submission yet.
  final bool pending;

  const EyesAnalysisPage({
    super.key,
    this.data,
    this.nested = false,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < _kMobileBreak;
    final padding = isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    final gapAfterScore = isMobile ? 16.0 : 24.0;
    final gapBeforeTransitions = isMobile ? 10.0 : 14.0;
    final transitionBottomPad = isMobile ? 12.0 : 16.0;

    final result = data;
    final Widget content;
    if (pending) {
      content = const _EyesNotice(
        title: 'Eyes analysis is pending',
        message:
            'The AI evaluation has not completed yet for this submission. '
            'The expressiveness score and eye-movement transitions will appear '
            'here as soon as analysis finishes.',
        showSpinner: true,
      );
    } else if (result == null) {
      content = const _EyesNotice(
        title: 'No eyes analysis available',
        message:
            'No gaze / eye-movement data was produced for this submission.',
      );
    } else {
      content = ListView(
        padding: padding,
        children: [
          _ScoreCard(data: result),
          SizedBox(height: gapAfterScore),
          _SectionHeader(
            title: 'Eye Movement During Emotion Transitions',
            icon: Icons.swap_horiz_rounded,
            count: result.transitions.length,
            useGradient: true,
          ),
          SizedBox(height: gapBeforeTransitions),
          if (result.transitions.isEmpty)
            const _EyesNotice(
              title: 'No emotion transitions detected',
              message:
                  'The actor\'s gaze stayed steady through the recording, so no '
                  'emotion-transition frames were captured.',
              boxed: true,
            )
          else
            ...result.transitions.map(
              (t) => Padding(
                padding: EdgeInsets.only(bottom: transitionBottomPad),
                child: _TransitionCard(transition: t),
              ),
            ),
        ],
      );
    }

    if (nested) {
      return ColoredBox(
        color: ScenolyticsColors.pageBackground,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: const _AppBar(),
      body: content,
    );
  }
}

/// Builds the eye-analysis view from the AI evaluation payload
/// (`eye_expression_score`). Returns null when no eye data is present.
EyesAnalysisResult? eyesAnalysisResultFromEvaluation(
  ActorAuditionSubmission submission,
) {
  final detail = submission.evaluationDetail;
  final raw = detail?['eye_expression_score'] ?? detail?['eye_expression'];
  final fallbackScore = submission.eyesAnalysisScore.clamp(0, 100).toDouble();

  if (raw is! Map) {
    if (!submission.evaluationCompleted) return null;
    // Score merged from a numeric column but no rich object — still show a card.
    return EyesAnalysisResult(
      score: fallbackScore,
      result: _eyesResultLabel(fallbackScore),
      message: _eyesResultMessage(fallbackScore),
      transitions: const [],
    );
  }

  final m = raw.map((k, v) => MapEntry(k.toString(), v));
  final score = (m['score'] as num?)?.toDouble() ?? fallbackScore;
  final transitionsRaw = m['transitions'];
  final transitions = transitionsRaw is List
      ? transitionsRaw
          .whereType<Map>()
          .map((e) =>
              EmotionTransition.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList()
      : <EmotionTransition>[];

  return EyesAnalysisResult(
    score: score,
    result: (m['result'] ?? _eyesResultLabel(score)).toString(),
    message: (m['message'] ?? _eyesResultMessage(score)).toString(),
    transitions: transitions,
  );
}

/// Simple notice card used for pending / empty eye-analysis states.
class _EyesNotice extends StatelessWidget {
  const _EyesNotice({
    required this.title,
    required this.message,
    this.showSpinner = false,
    this.boxed = false,
  });

  final String title;
  final String message;
  final bool showSpinner;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
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
              if (showSpinner)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                const Icon(Icons.remove_red_eye_outlined,
                    size: 20, color: ScenolyticsColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
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
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ScenolyticsColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
    if (boxed) return card;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [card],
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: ScenolyticsColors.heroBarGradient,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text(
        'Eyes Analysis',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final EyesAnalysisResult data;
  const _ScoreCard({required this.data});

  static const String _scoreDescription =
      "Measures how much the actor's eyelids open and narrow over time relative to their own baseline. Higher scores mean more visible eye-aperture variation";

  Color get _scoreColor {
    if (data.score >= 85) return ScenolyticsColors.success;
    if (data.score >= 60) return ScenolyticsColors.warning;
    return ScenolyticsColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: ScenolyticsColors.heroBarGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.remove_red_eye_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'Expressive Eyes Score',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ScenolyticsColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ScenolyticsColors.textMuted,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  _scoreDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: ScenolyticsColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ScenolyticsColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScenolyticsColors.outlineSoft),
            boxShadow: [
              BoxShadow(
                color: ScenolyticsColors.primary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Score circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _scoreColor, width: 3),
                  color: _scoreColor.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.score.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: TextStyle(
                          fontSize: 10,
                          color: ScenolyticsColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Description + result + message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data.result,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ScenolyticsColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool useGradient;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleRow = Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: useGradient ? Colors.white : ScenolyticsColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: useGradient ? Colors.white : ScenolyticsColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: useGradient
                ? Colors.white.withValues(alpha: 0.2)
                : ScenolyticsColors.accentCyanMuted,
            borderRadius: BorderRadius.circular(20),
            border: useGradient
                ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                : null,
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: useGradient ? Colors.white : ScenolyticsColors.primary,
            ),
          ),
        ),
      ],
    );

    if (!useGradient) {
      return titleRow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: titleRow,
    );
  }
}

class _TransitionCard extends StatelessWidget {
  final EmotionTransition transition;
  const _TransitionCard({required this.transition});

  @override
  Widget build(BuildContext context) {
    final fromColor = ScenolyticsColors.error;
    final toColor = transition.hasShift
      ? ScenolyticsColors.success
      : ScenolyticsColors.textMuted;
    // before timestamp = transitionSeconds - 1, after = transitionSeconds + 1
    final beforeSec = transition.timestampSeconds - 1;
    final afterSec  = transition.timestampSeconds + 1;

    return Container(
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header banner ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ScenolyticsColors.surfaceMuted,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 15, color: ScenolyticsColors.primaryDim),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Transition at ${transition.formattedTime} — '
                        '${transition.shiftLabel.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ScenolyticsColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _EmotionChip(
                        emotion: transition.fromEmotion, color: fromColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: ScenolyticsColors.primaryDim),
                    ),
                    _EmotionChip(emotion: transition.toEmotion, color: toColor),
                  ],
                ),
              ],
            ),
          ),

          // ── Before / After photo frames side by side ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PhotoFrame(
                    label: 'BEFORE',
                    emotion: transition.fromEmotion,
                    timestampSec: beforeSec.toDouble(),
                    color: fromColor,
                    imagePath: transition.beforeImagePath,
                    imageAspectRatio: transition.imageAspectRatio,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoFrame(
                    label: 'AFTER',
                    emotion: transition.toEmotion,
                    timestampSec: afterSec.toDouble(),
                    color: toColor,
                    imagePath: transition.afterImagePath,
                    imageAspectRatio: transition.imageAspectRatio,
                  ),
                ),
              ],
            ),
          ),

          // ── Sentence ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        size: 14, color: ScenolyticsColors.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Sentence at transition',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ScenolyticsColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ScenolyticsColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ScenolyticsColors.outlineSoft
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '"${transition.sentence}"',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScenolyticsColors.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  final String label;       // "BEFORE" or "AFTER"
  final String emotion;
  final double timestampSec;
  final Color color;
  final String? imagePath;  // null → placeholder
  final double? imageAspectRatio;

  const _PhotoFrame({
    required this.label,
    required this.emotion,
    required this.timestampSec,
    required this.color,
    this.imagePath,
    this.imageAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: imageAspectRatio ?? _kTransitionImageAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image or placeholder ─────────────────────────────────────
            imagePath != null
                ? Image.network(
                    imagePath!,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _PhotoPlaceholder(loading: true);
                    },
                    errorBuilder: (context, error, stack) =>
                        const _PhotoPlaceholder(),
                  )
                : const _PhotoPlaceholder(),

            // ── Dark gradient at top so text is always readable ───────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Emotion label + timestamp overlaid top-left ───────────────
            Positioned(
              top: 8,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "BEFORE  (angry)" row
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 1.1,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // timestamp
                  Text(
                    '${timestampSec.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback shown while a transition frame loads, or when it is missing /
/// fails to load (e.g. the MinIO object is unavailable).
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D2137),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white24,
                ),
              )
            : Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.15),
              ),
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  final String emotion;
  final Color color;
  const _EmotionChip({required this.emotion, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emotionEmoji_(emotion), style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            emotion[0].toUpperCase() + emotion.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
