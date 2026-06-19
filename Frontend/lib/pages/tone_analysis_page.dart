import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';
import '../utils/evaluation_parsing.dart';

// Pitch / loudness variation explorer for the Tone tab.
//
// Fed by the AI evaluation payload (`tone_analysis.segments`, mapped via
// [ToneAnalysisResult.fromSegments]). Each segment carries:
//   pitchVariationHz    — F0 standard deviation (Hz)
//   loudnessVariationDb  — energy standard deviation (dB)

const double _kMobileBreak = 600;
const double _space8 = 8;
const double _space12 = 12;
const double _space16 = 16;

bool _isWide(BuildContext ctx) =>
    kIsWeb || MediaQuery.of(ctx).size.width >= _kMobileBreak;

// Section accents (brand ramp).
const _colPitch = ScenolyticsColors.primaryBright;
const _colLoudness = ScenolyticsColors.secondary;

// Chart surface — deep brand teal so the white plot reads in both themes.
const _colChartBg = ScenolyticsColors.darkSurfaceCard;
const _colGrid = ScenolyticsColors.darkOutlineSoft;
const _colChartAxisText = ScenolyticsColors.darkTextMuted;

// ── Data models ───────────────────────────────────────────────────────────
class ToneSegment {
  final String label;
  final String sentence;
  final double startSec;
  final double endSec;
  final double pitchVariationHz;
  final double loudnessVariationDb;

  const ToneSegment({
    required this.label,
    required this.sentence,
    required this.startSec,
    required this.endSec,
    required this.pitchVariationHz,
    required this.loudnessVariationDb,
  });
}

class ToneAnalysisResult {
  final String actorName;
  final int age;
  final int score;
  final List<ToneSegment> segments;

  const ToneAnalysisResult({
    required this.actorName,
    required this.age,
    required this.score,
    required this.segments,
  });

  /// Builds the chart-ready model from parsed evaluation tone segments.
  factory ToneAnalysisResult.fromSegments({
    required String actorName,
    required int age,
    required int score,
    required List<EvaluationToneSegment> segments,
  }) {
    final mapped = <ToneSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final sentence = s.content.isEmpty ? 'Segment ${i + 1}' : s.content;
      mapped.add(
        ToneSegment(
          label: 'S${i + 1}: $sentence',
          sentence: sentence,
          startSec: s.startSeconds,
          endSec: s.endSeconds,
          pitchVariationHz: s.pitchVariation,
          loudnessVariationDb: s.loudnessVariation,
        ),
      );
    }
    return ToneAnalysisResult(
      actorName: actorName,
      age: age,
      score: score,
      segments: mapped,
    );
  }
}

// ── Page root ───────────────────────────────────────────────────────────
class ToneAnalysisPage extends StatelessWidget {
  const ToneAnalysisPage({
    super.key,
    required this.result,
    this.nested = false,
    this.pending = false,
  });

  final ToneAnalysisResult result;

  /// When true, omits the [Scaffold]/[AppBar] so this can live inside a parent
  /// tab (the details page already supplies a header + background).
  final bool nested;

  /// AI evaluation has not finished for this submission yet.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final body = _ToneBody(result: result, pending: pending);

    if (nested) {
      return ColoredBox(
        color: _pageBg(context),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: _pageBg(context),
      appBar: const _AppBar(),
      body: Stack(
        children: [
          const _PageBackdrop(),
          body,
        ],
      ),
    );
  }
}

Color _pageBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? ScenolyticsColors.darkPageBackground
        : ScenolyticsColors.pageBackground;

// ── Shared scrollable body (responsive) ──────────────────────────────────
class _ToneBody extends StatelessWidget {
  const _ToneBody({required this.result, required this.pending});

  final ToneAnalysisResult result;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final segments = result.segments;

    final children = <Widget>[
      _ToneScoreCard(score: result.score),
      const SizedBox(height: _space16),
    ];

    if (pending) {
      children.add(const _ToneNotice(
        title: 'Tone analysis is pending',
        message: 'The AI evaluation has not completed yet. The pitch and '
            'loudness variation charts will appear here once analysis finishes.',
        showSpinner: true,
      ));
    } else if (segments.isEmpty) {
      children.add(const _ToneNotice(
        title: 'No per-segment timeline available',
        message: 'The tone score above reflects the full recording, but no '
            'timestamped segments were produced for this submission (speech '
            'transcription may have been unavailable).',
      ));
    } else {
      children.addAll([
        _SectionCard(
          title: 'Pitch Variation',
          icon: Icons.multitrack_audio_rounded,
          accent: _colPitch,
          banner: const _PitchBanner(),
          chart: _ChartCard(
            segments: segments,
            getValue: (s) => s.pitchVariationHz,
            color: _colPitch,
            unit: 'Hz',
            yLabel: 'Pitch variation',
            markerShape: MarkerShape.circle,
          ),
        ),
        const SizedBox(height: _space16),
        _SectionCard(
          title: 'Loudness Variation',
          icon: Icons.volume_up_rounded,
          accent: _colLoudness,
          banner: const _LoudnessBanner(),
          chart: _ChartCard(
            segments: segments,
            getValue: (s) => s.loudnessVariationDb,
            color: _colLoudness,
            unit: 'dB',
            yLabel: 'Loudness variation',
            markerShape: MarkerShape.square,
          ),
        ),
        const SizedBox(height: _space16),
        _SegmentLegend(segments: segments),
      ]);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 32 : 16,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

// ── Backdrop (full page only) ─────────────────────────────────────────────
class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradient = ScenolyticsColors.pageBackdropGradientFor(brightness);

    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: _BackdropBlob(
                  size: 220,
                  colors: [
                    ScenolyticsColors.accentCyan.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
              Positioned(
                left: -100,
                top: 220,
                child: _BackdropBlob(
                  size: 260,
                  colors: [
                    ScenolyticsColors.primaryBright.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              Positioned(
                right: 18,
                bottom: -120,
                child: _BackdropBlob(
                  size: 300,
                  colors: [
                    ScenolyticsColors.tertiary.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BackdropBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

// ── AppBar (full page only) ───────────────────────────────────────────────
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
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Tone Analysis',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

// ── Insight banners ───────────────────────────────────────────────────────
class _InsightBanner extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final List<InlineSpan> spans;

  const _InsightBanner({
    required this.accent,
    required this.icon,
    required this.spans,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_space12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: _space12),
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: _space8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: ScenolyticsColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  children: spans,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchBanner extends StatelessWidget {
  const _PitchBanner();

  @override
  Widget build(BuildContext context) {
    return const _InsightBanner(
      accent: _colPitch,
      icon: Icons.multitrack_audio_rounded,
      spans: <InlineSpan>[
        TextSpan(
          text:
              'This line shows how much the voice MOVES UP AND DOWN in pitch '
              'each segment.\n',
        ),
        TextSpan(
          text: 'HIGH value ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: '= Voice is melodic and emotionally alive.\n'),
        TextSpan(
          text: 'LOW value ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: '= Voice is flat and stuck on one note.'),
      ],
    );
  }
}

class _LoudnessBanner extends StatelessWidget {
  const _LoudnessBanner();

  @override
  Widget build(BuildContext context) {
    return const _InsightBanner(
      accent: _colLoudness,
      icon: Icons.volume_up_rounded,
      spans: <InlineSpan>[
        TextSpan(
          text:
              'This line shows how much the volume RISES AND FALLS within each '
              'segment.\n',
        ),
        TextSpan(
          text: 'HIGH value ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text:
              '= Strong dynamic contrast: some words are loud, some quiet. '
              'This makes a performance feel alive.\n',
        ),
        TextSpan(
          text: 'LOW value ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text:
              '= Volume is uniform throughout: no emphasis, no whispers, no '
              'bursts. Every word sounds equally important, which means no '
              'word feels important at all.',
        ),
      ],
    );
  }
}

// ── Tone score card ───────────────────────────────────────────────────────
class _ToneScoreCard extends StatefulWidget {
  final int score;
  const _ToneScoreCard({required this.score});

  @override
  State<_ToneScoreCard> createState() => _ToneScoreCardState();
}

class _ToneScoreCardState extends State<_ToneScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _scoreColor(int score) {
    if (score >= 75) return ScenolyticsColors.primaryBright;
    if (score >= 50) return ScenolyticsColors.secondary;
    return ScenolyticsColors.tertiary;
  }

  Color _scoreTrackColor(int score) {
    if (score >= 75) return ScenolyticsColors.primaryContainer;
    if (score >= 50) return ScenolyticsColors.secondaryContainer;
    return ScenolyticsColors.tertiaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _scoreColor(widget.score);
    final track = _scoreTrackColor(widget.score);
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _space16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ScenolyticsColors.cardSheenFor(brightness).colors[0],
            ScenolyticsColors.primaryContainer.withValues(alpha: 0.18),
            ScenolyticsColors.secondaryContainer.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ScenolyticsColors.primaryContainer.withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A1F2A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.equalizer_rounded, size: 18, color: accent),
              const SizedBox(width: 7),
              const Text(
                'Tone Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ScenolyticsColors.primaryDim,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(130, 130),
                painter: _ScoreRingPainter(
                  score: widget.score,
                  progress: _anim.value,
                  accent: accent,
                  trackColor: track,
                ),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(widget.score * _anim.value).round()}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          '/ 100',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ScenolyticsColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: track.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (widget.score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      ScenolyticsColors.accentCyan,
                      ScenolyticsColors.primaryContainer,
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _InsightBanner(
            accent: ScenolyticsColors.secondary,
            icon: Icons.info_outline_rounded,
            spans: <InlineSpan>[
              TextSpan(
                text:
                    'The Tone Score reflects how closely the actor\'s vocal '
                    'delivery matches the required emotions for each scene.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final int score;
  final double progress;
  final Color accent;
  final Color trackColor;

  const _ScoreRingPainter({
    required this.score,
    required this.progress,
    required this.accent,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;
    const startAngle = -pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final sweepAngle = 2 * pi * (score / 100).clamp(0.0, 1.0) * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.score != score || old.accent != accent;
}

// ── Section card ──────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget banner;
  final Widget chart;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.banner,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A1F2A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SectionHeading(
                title,
                color: ScenolyticsColors.primaryDim,
                icon: icon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          banner,
          const SizedBox(height: _space12),
          chart,
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _SectionHeading(this.text, {required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Segment legend (maps S1, S2… to sentence + time range) ────────────────
class _SegmentLegend extends StatelessWidget {
  const _SegmentLegend({required this.segments});

  final List<ToneSegment> segments;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mutedText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextMuted
        : ScenolyticsColors.textMuted;
    final primaryText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextPrimary
        : ScenolyticsColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ScenolyticsColors.primaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            'Segments',
            color: ScenolyticsColors.primaryDim,
            icon: Icons.format_list_numbered_rounded,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colPitch.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _colPitch.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'S${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _colPitch,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clockRange(segments[i].startSec, segments[i].endSec),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        segments[i].sentence,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Notice card (pending / empty) ─────────────────────────────────────────
class _ToneNotice extends StatelessWidget {
  const _ToneNotice({
    required this.title,
    required this.message,
    this.showSpinner = false,
  });

  final String title;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mutedText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextMuted
        : ScenolyticsColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ScenolyticsColors.primaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showSpinner)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: ScenolyticsColors.primaryBright,
                  ),
                )
              else
                const Icon(Icons.equalizer_rounded,
                    size: 20, color: ScenolyticsColors.primaryDim),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ScenolyticsColors.primaryDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart card ────────────────────────────────────────────────────────────
enum MarkerShape { circle, square }

class _ChartCard extends StatefulWidget {
  final List<ToneSegment> segments;
  final double Function(ToneSegment) getValue;
  final Color color;
  final String unit;
  final String yLabel;
  final MarkerShape markerShape;
  const _ChartCard({
    required this.segments,
    required this.getValue,
    required this.color,
    required this.unit,
    required this.yLabel,
    required this.markerShape,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
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
    final values = widget.segments.map(widget.getValue).toList();
    return Container(
      decoration: BoxDecoration(
        color: _colChartBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.yLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => LayoutBuilder(
                  builder: (layoutContext, constraints) {
                    int hitIndex(double localX) {
                      if (values.isEmpty) return 0;
                      final chartW = constraints.maxWidth -
                          _LinePainter.kLeftPad -
                          _LinePainter.kRightPad;
                      if (chartW <= 0) return 0;
                      final step = chartW / max(values.length - 1, 1);
                      return ((localX - _LinePainter.kLeftPad) / step)
                          .round()
                          .clamp(0, values.length - 1);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (values.isEmpty) return;
                        final idx = hitIndex(details.localPosition.dx);
                        setState(() => _hoveredIndex = idx);
                      },
                      child: MouseRegion(
                        onHover: (e) {
                          if (values.isEmpty) return;
                          final idx = hitIndex(e.localPosition.dx);
                          if (_hoveredIndex != idx) {
                            setState(() => _hoveredIndex = idx);
                          }
                        },
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: CustomPaint(
                          painter: _LinePainter(
                            values: values,
                            color: widget.color,
                            unit: widget.unit,
                            yLabel: widget.yLabel,
                            markerShape: widget.markerShape,
                            progress: _anim.value,
                            hoveredIndex: _hoveredIndex,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: _space8),
        ],
      ),
    );
  }
}

// ── Line chart painter ────────────────────────────────────────────────────
class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final String unit;
  final String yLabel;
  final MarkerShape markerShape;
  final double progress;
  final int? hoveredIndex;

  static const kLeftPad = 50.0;
  static const kRightPad = 16.0;
  static const kTopPad = 16.0;
  static const kBotPad = 28.0;

  const _LinePainter({
    required this.values,
    required this.color,
    required this.unit,
    required this.yLabel,
    required this.markerShape,
    required this.progress,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final chartW = size.width - kLeftPad - kRightPad;
    final chartH = size.height - kTopPad - kBotPad;
    final maxVal = (values.reduce(max) * 1.3).clamp(1.0, double.infinity);
    final n = values.length;
    final step = n > 1 ? chartW / (n - 1) : chartW / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      Paint()..color = _colChartBg,
    );

    const gridCount = 5;
    final gridPaint = Paint()
      ..color = _colGrid.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;

    for (int g = 0; g <= gridCount; g++) {
      final yFrac = g / gridCount;
      final yPx = kTopPad + chartH * (1 - yFrac);
      canvas.drawLine(
        Offset(kLeftPad, yPx),
        Offset(size.width - kRightPad, yPx),
        gridPaint,
      );
      final val = maxVal * yFrac;
      _drawText(
        canvas,
        val.toStringAsFixed(0),
        Offset(2, yPx - 6),
        const TextStyle(
          color: _colChartAxisText,
          fontSize: 9,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxWidth: kLeftPad - 4,
      );
    }

    canvas.save();
    canvas.translate(12, kTopPad + chartH / 2);
    canvas.rotate(-pi / 2);
    _drawText(
      canvas,
      yLabel,
      const Offset(0, 0),
      const TextStyle(
        color: _colChartAxisText,
        fontSize: 9,
        letterSpacing: 0.3,
      ),
      centered: true,
      maxWidth: chartH,
    );
    canvas.restore();

    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = kLeftPad + (n == 1 ? chartW / 2 : i * step);
      final rawY = kTopPad + chartH * (1 - values[i] / maxVal);
      final y = _lerpDouble(kTopPad + chartH, rawY, progress);
      pts.add(Offset(x, y));
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(kLeftPad, 0, chartW * progress + 2, size.height),
    );

    final fillPath = Path()..moveTo(pts.first.dx, kTopPad + chartH);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, kTopPad + chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Rect.fromLTWH(kLeftPad, kTopPad, chartW, chartH)),
    );

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();

    for (int i = 0; i < pts.length; i++) {
      final frac = n > 1 ? i / (n - 1) : 1.0;
      if (frac > progress) continue;

      final p = pts[i];
      final hov = hoveredIndex == i;
      final mSize = hov ? 7.0 : 5.0;
      final mColor = hov ? Colors.white : color;

      if (markerShape == MarkerShape.circle) {
        canvas.drawCircle(p, mSize, Paint()..color = mColor);
        canvas.drawCircle(
          p,
          mSize,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        final r = Rect.fromCenter(
          center: p,
          width: mSize * 2,
          height: mSize * 2,
        );
        canvas.drawRect(r, Paint()..color = mColor);
        canvas.drawRect(
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      _drawLabel(
        canvas,
        '${values[i].toStringAsFixed(1)} $unit',
        Offset(p.dx, p.dy - 20),
        TextStyle(
          color: hov ? Colors.white : color,
          fontSize: hov ? 11 : 9,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

      // Segment index tick under each marker (S1, S2…).
      _drawText(
        canvas,
        'S${i + 1}',
        Offset(p.dx - 8, kTopPad + chartH + 8),
        const TextStyle(
          color: _colChartAxisText,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: 24,
      );

      if (hov) {
        final dashPaint = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1;
        double dy = kTopPad;
        while (dy < kTopPad + chartH) {
          canvas.drawLine(
            Offset(p.dx, dy),
            Offset(p.dx, min(dy + 4, kTopPad + chartH)),
            dashPaint,
          );
          dy += 8;
        }
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool centered = false,
    double maxWidth = 200,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, centered ? offset.translate(-tp.width / 2, 0) : offset);
  }

  void _drawLabel(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    const padX = 6.0;
    const padY = 2.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + padX * 2,
        height: tp.height + padY * 2,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = _colChartBg.withValues(alpha: 0.78),
    );
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress ||
      old.hoveredIndex != hoveredIndex ||
      old.values != values;
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
