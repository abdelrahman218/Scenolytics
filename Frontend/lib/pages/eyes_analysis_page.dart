import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';

// ─── Data models ────────────────────────────────────────────────────────────

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
  // Optional frame images — pass asset paths or network URLs.
  // If null, a dark placeholder is shown instead.
  final String? beforeImagePath;
  final String? afterImagePath;
  // Optional per-transition aspect ratio for the uploaded photo.
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

// ─── Hardcoded sample data ───────────────────────────────────────────────────

const _kSampleData = EyesAnalysisResult(
  score: 93.8,
  result: 'EXPRESSIVE',
  message: 'Eyes moved strongly—strong physical expression',
  transitions: [
    EmotionTransition(
      timestampSeconds: 12,
      fromEmotion: 'angry',
      toEmotion: 'fearful',
      sentence:
          'how no matter how much i\'d like not to hate you i hate you even more'
          ' it grows i can\'t even see now',
      label: 'NO_SHIFT',
      shiftScore: 0.0,
      displacement: 0.01061,
      dirBefore: 'DOWN',
      dirAfter: 'DOWN',
      beforeImagePath: 'lib/assets/bef.png',
      afterImagePath: 'lib/assets/aft .png',
    ),
    EmotionTransition(
      timestampSeconds: 21,
      fromEmotion: 'fearful',
      toEmotion: 'sad',
      sentence:
          'all i see is this picture of you you and her i don\'t even know if'
          ' this picture\'s real any more i don\'t even care it\'s a made up'
          ' picture it invades my head the two of you in this picture it stings'
          ' me more than if i actually see you with her',
      label: 'STRONG_SHIFT',
      shiftScore: 100.0,
      displacement: 0.06519,
      dirBefore: 'CENTER',
      dirAfter: 'CENTER',
      beforeImagePath: 'lib/assets/bef.png',
      afterImagePath: 'lib/assets/aft .png',
    ),
  ],
);

// ─── Emotion helpers ─────────────────────────────────────────────────────────

const _emotionEmoji = <String, String>{
  'angry':   '😡',
  'fearful': '😨',
  'sad':     '😢',
  'happy':   '😊',
  'surprised': '😲',
  'disgusted': '🤢',
  'neutral': '😐',
};

const _emotionColor = <String, Color>{
  'angry':     Color(0xFFDC2626),
  'fearful':   Color(0xFF7C3AED),
  'sad':       Color(0xFF2563EB),
  'happy':     ScenolyticsColors.success,
  'surprised': Color(0xFFD97706),
  'disgusted': Color(0xFF059669),
  'neutral':   ScenolyticsColors.textMuted,
};

String _emotionEmoji_(String e) =>
    _emotionEmoji[e.toLowerCase()] ?? '🎭';

Color _emotionColor_(String e) =>
    _emotionColor[e.toLowerCase()] ?? ScenolyticsColors.primary;

// ─── Breakpoint ──────────────────────────────────────────────────────────────

const double _kMobileBreak = 600;
const double _kTransitionImageAspectRatio = 16 / 9;

// ─── Page entry point ────────────────────────────────────────────────────────

class EyesAnalysisPage extends StatelessWidget {
  final EyesAnalysisResult data;

  const EyesAnalysisPage({super.key, this.data = _kSampleData});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      body: w < _kMobileBreak
          ? _MobileLayout(data: data)
          : _WebLayout(data: data),
    );
  }
}

// ─── App bar ─────────────────────────────────────────────────────────────────

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

// ─── Mobile layout ───────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final EyesAnalysisResult data;
  const _MobileLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: const _AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScoreCard(data: data),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Eye Movement During Emotion Transitions',
            icon: Icons.swap_horiz_rounded,
            count: data.transitions.length,
            useGradient: true,
          ),
          const SizedBox(height: 10),
          ...data.transitions.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransitionCard(transition: t),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Web layout ──────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final EyesAnalysisResult data;
  const _WebLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: const _AppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          _ScoreCard(data: data),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Eye Movement During Emotion Transitions',
            icon: Icons.swap_horiz_rounded,
            count: data.transitions.length,
            useGradient: true,
          ),
          const SizedBox(height: 14),
          ...data.transitions.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TransitionCard(transition: t),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score card ──────────────────────────────────────────────────────────────

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

// ─── Section header ──────────────────────────────────────────────────────────

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

// ─── Transition card ─────────────────────────────────────────────────────────

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

// ─── Photo frame with overlaid emotion label ──────────────────────────────────

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
                ? Image.asset(
                    imagePath!,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  )
                : Container(
                    color: const Color(0xFF0D2137),
                    child: Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),

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

// ─── Small emotion chip used in the header ────────────────────────────────────

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

// ─── Shift chip ─────────────────────────────────────────────────────────────

