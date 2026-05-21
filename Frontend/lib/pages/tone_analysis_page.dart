import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/scenolytics_colors.dart';

const double _kMobileBreak = 600;
const double _space8 = 8;
const double _space12 = 12;
const double _space16 = 16;

bool _isWide(BuildContext ctx) =>
    kIsWeb || MediaQuery.of(ctx).size.width >= _kMobileBreak;

const _colPitch = Color(0xFF64FFDA);
const _colLoudness = Color(0xFFFF6E40);
const _colGrid = Color(0xFF444466);
const _colChartBg = Color(0xFF0F0F23);

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
  final String? audioUrl;
  final List<ToneSegment> segments;

  const ToneAnalysisResult({
    required this.actorName,
    required this.age,
    required this.score,
    this.audioUrl,
    required this.segments,
  });

  factory ToneAnalysisResult.mock() => const ToneAnalysisResult(
    actorName: 'Yousef',
    age: 20,
    score: 74,
    segments: [
      ToneSegment(
        label: 'S1: Sentence one goes here.',
        sentence: 'Sentence one goes here.',
        startSec: 0.0,
        endSec: 20.0,
        pitchVariationHz: 42.3,
        loudnessVariationDb: 8.1,
      ),
      ToneSegment(
        label: 'S2: Sentence two goes here.',
        sentence: 'Sentence two goes here.',
        startSec: 21.0,
        endSec: 40.5,
        pitchVariationHz: 78.6,
        loudnessVariationDb: 14.3,
      ),
      ToneSegment(
        label: 'S3: Sentence three goes here.',
        sentence: 'Sentence three goes here.',
        startSec: 40.5,
        endSec: 75.0,
        pitchVariationHz: 31.1,
        loudnessVariationDb: 5.9,
      ),
    ],
  );
}

// Page root
class ToneAnalysisPage extends StatelessWidget {
  const ToneAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = ToneAnalysisResult.mock();
    final wide = _isWide(context);

    return wide ? _WebLayout(data: data) : _MobileLayout(data: data);
  }
}

// Mobile layout
class _MobileLayout extends StatelessWidget {
  final ToneAnalysisResult data;
  const _MobileLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: const _AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Pitch Variation',
            icon: Icons.multitrack_audio_rounded,
            banner: const _PitchBanner(),
            chart: _ChartCard(
              segments: data.segments,
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
            banner: const _LoudnessBanner(),
            chart: _ChartCard(
              segments: data.segments,
              getValue: (s) => s.loudnessVariationDb,
              color: _colLoudness,
              unit: 'dB',
              yLabel: 'Loudness variation',
              markerShape: MarkerShape.square,
            ),
          ),
          const SizedBox(height: _space16),
        ],
      ),
    );
  }
}

// Web layout — side-by-side cards, equal height via SizedBox + stretch
class _WebLayout extends StatelessWidget {
  final ToneAnalysisResult data;
  const _WebLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: const _AppBar(),
      body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left — Pitch Variation
                Expanded(
                  child: _SectionCard(
                    title: 'Pitch Variation',
                    icon: Icons.multitrack_audio_rounded,
                    banner: const _PitchBanner(),
                    stretchChart: true,
                    chart: _ChartCard(
                      segments: data.segments,
                      getValue: (s) => s.pitchVariationHz,
                      color: _colPitch,
                      unit: 'Hz',
                      yLabel: 'Pitch variation',
                      markerShape: MarkerShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: _space16),
                // Right — Loudness Variation
                Expanded(
                  child: _SectionCard(
                    title: 'Loudness Variation',
                    icon: Icons.volume_up_rounded,
                    banner: const _LoudnessBanner(),
                    stretchChart: true,
                    chart: _ChartCard(
                      segments: data.segments,
                      getValue: (s) => s.loudnessVariationDb,
                      color: _colLoudness,
                      unit: 'dB',
                      yLabel: 'Loudness variation',
                      markerShape: MarkerShape.square,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

// AppBar
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

// Insight banners
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
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
                    fontSize: 12,
                    height: 1.45,
                    color: ScenolyticsColors.textPrimary,
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
              'This line shows how much voice MOVES UP AND DOWN in pitch each '
              'segment.\n',
        ),
        TextSpan(
          text: 'HIGH value',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: '= Voice is melodic and emotionally alive.\n'),
        TextSpan(
          text: 'LOW value',
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
              'This line shows how much Volume RISES AND FALLS within each '
              'segment.\n',
        ),
        TextSpan(
          text: 'HIGH value',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text:
              '= Strong dynamic contrast: some words are loud some are quiet. '
              'This makes a performance feel alive.\n',
        ),
        TextSpan(
          text: 'LOW value',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text:
              '= Volume is uniform throughout: no emphasis  no whispers, '
              'no bursts. Every word sounds equally important which means no '
              'word feels important at all.',
        ),
      ],
    );
  }
}

// Section card
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget banner;
  final Widget chart;
  /// true on web: chart fills remaining height via Expanded.
  /// false on mobile: chart sizes itself naturally inside ListView.
  final bool stretchChart;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.banner,
    required this.chart,
    this.stretchChart = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_space12),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.secondaryContainer.withValues(alpha: 0.35),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title,
            color: ScenolyticsColors.textPrimary,
            icon: icon,
          ),
          const SizedBox(height: _space8),
          banner,
          const SizedBox(height: _space12),
          stretchChart ? Expanded(child: chart) : chart,
        ],
      ),
    );
  }
}

// Section heading
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

// Chart card
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
                      final chartW =
                          constraints.maxWidth -
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

// Line chart CustomPainter
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
    final maxVal = values.reduce(max) * 1.3;
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
          color: Color(0xFF9AA7B0),
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
        color: Color(0xFF9AA7B0),
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
      final y = lerpDouble(kTopPad + chartH, rawY, progress);
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

double lerpDouble(double a, double b, double t) => a + (b - a) * t;