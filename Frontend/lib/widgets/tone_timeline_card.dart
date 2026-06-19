import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';
import '../utils/evaluation_parsing.dart';

/// Timestamped per-segment prosody breakdown from `tone_analysis.segments`.
///
/// Splits the recording into the same time windows the AI pipeline measured and
/// shows pitch + loudness variation for each slice. Shared by the Tone tab and
/// the Vocal tab (as a fallback when no per-sentence emotion breakdown exists).
class ToneTimelineCard extends StatelessWidget {
  const ToneTimelineCard({
    super.key,
    required this.segments,
    this.title = 'Timeline breakdown',
  });

  final List<EvaluationToneSegment> segments;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final cardSurface = brightness == Brightness.dark
        ? ScenolyticsColors.darkSurfaceCard
        : ScenolyticsColors.surfaceCard;
    final outline = brightness == Brightness.dark
        ? ScenolyticsColors.darkOutlineSoft.withValues(alpha: 0.5)
        : ScenolyticsColors.outlineSoft.withValues(alpha: 0.6);
    final mutedText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextMuted
        : ScenolyticsColors.textMuted;

    final maxPitch = segments
        .map((s) => s.pitchVariation)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxLoud = segments
        .map((s) => s.loudnessVariation)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 18, color: ScenolyticsColors.metricToneAnalysis),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Recording split into ${segments.length} '
            '${segments.length == 1 ? "segment" : "segments"} by timestamp.',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedText),
          ),
          const SizedBox(height: 14),
          for (final seg in segments) ...[
            _ToneSegmentRow(
              segment: seg,
              maxPitch: maxPitch,
              maxLoud: maxLoud,
            ),
            if (seg != segments.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ToneSegmentRow extends StatelessWidget {
  const _ToneSegmentRow({
    required this.segment,
    required this.maxPitch,
    required this.maxLoud,
  });

  final EvaluationToneSegment segment;
  final double maxPitch;
  final double maxLoud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emotion = segment.emotion.trim();
    final hasContent = segment.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    ScenolyticsColors.metricToneAnalysis.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                segment.clockLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ScenolyticsColors.metricToneAnalysis,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const Spacer(),
            if (emotion.isNotEmpty) ...[
              Text(emotionEmoji(emotion), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                capitalizeEmotion(emotion),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ScenolyticsColors.accentCyan,
                ),
              ),
            ],
          ],
        ),
        if (hasContent) ...[
          const SizedBox(height: 6),
          Text(
            segment.content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
        const SizedBox(height: 8),
        _MetricBar(
          label: 'Pitch variation',
          value: segment.pitchVariation,
          unit: 'Hz',
          fraction: maxPitch <= 0 ? 0 : (segment.pitchVariation / maxPitch),
          color: ScenolyticsColors.primary,
        ),
        const SizedBox(height: 6),
        _MetricBar(
          label: 'Loudness variation',
          value: segment.loudnessVariation,
          unit: 'dB',
          fraction: maxLoud <= 0 ? 0 : (segment.loudnessVariation / maxLoud),
          color: ScenolyticsColors.accentCyan,
        ),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.unit,
    required this.fraction,
    required this.color,
  });

  final String label;
  final double value;
  final String unit;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final mutedText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextMuted
        : ScenolyticsColors.textMuted;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: mutedText),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            '${value.toStringAsFixed(1)} $unit',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
