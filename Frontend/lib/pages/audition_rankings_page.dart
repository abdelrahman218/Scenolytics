import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/mock_audition_rankings.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

/// Which slice of the leaderboard is shown below the stats row.
enum RankingsViewMode {
  /// Full list, competition ranks preserved.
  all,

  /// Highest-scoring ten rows (same ranks as in [all]).
  topTen,

  /// Only submissions with a callback sent.
  callbacks,
}

/// Director-facing leaderboard of actor submissions for an audition, sorted by score.
/// Layout adapts from narrow (mobile) to wide (web / tablet landscape).
class AuditionRankingsPage extends StatefulWidget {
  const AuditionRankingsPage({
    super.key,
    this.submissions,
  });

  final List<ActorAuditionSubmission>? submissions;

  @override
  State<AuditionRankingsPage> createState() => _AuditionRankingsPageState();
}

class _AuditionRankingsPageState extends State<AuditionRankingsPage> {
  RankingsViewMode _viewMode = RankingsViewMode.all;

  static const int _topCandidateCount = 10;

  List<RankedAuditionSubmission> _visibleRanked(
    List<RankedAuditionSubmission> ranked,
  ) {
    switch (_viewMode) {
      case RankingsViewMode.all:
        return ranked;
      case RankingsViewMode.topTen:
        if (ranked.length <= _topCandidateCount) return ranked;
        return ranked.sublist(0, _topCandidateCount);
      case RankingsViewMode.callbacks:
        return ranked.where((e) => e.submission.receivedCallback).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submissions = widget.submissions ?? kMockAuditionSubmissions;
    final ranked = rankAuditionSubmissions(submissions);
    final theme = Theme.of(context);
    final visible = _visibleRanked(ranked);

    if (ranked.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No submissions yet.'),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.pageBackdropGradientFor(theme.brightness),
      ),
      child: CustomScrollView(
        primary: false,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: const SliverToBoxAdapter(child: _RankingsHeaderCard()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _StatsSection(
                totalSubmissions: ranked.length,
                averageScore: ranked
                        .map((e) => e.submission.score)
                        .reduce((a, b) => a + b) /
                    ranked.length,
                topScore: ranked.first.submission.score,
                callbacksSent: mockCallbacksSentCount(submissions),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _RankingsViewToolbar(
                mode: _viewMode,
                onModeChanged: (m) => setState(() => _viewMode = m),
                onFilterPressed: () => _showRankingsFiltersBottomSheet(context),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    _viewMode == RankingsViewMode.callbacks
                        ? 'No callbacks match this view yet.'
                        : 'Nothing to show for this view.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _CompactRankCard(entry: visible[index]);
                },
              ),
            ),
          const SliverToBoxAdapter(
            child: ScenolyticsFooter(),
          ),
        ],
      ),
    );
  }
}

/// Header-style mode toggles + filter control (matches shell nav button feel).
class _RankingsViewToolbar extends StatelessWidget {
  const _RankingsViewToolbar({
    required this.mode,
    required this.onModeChanged,
    required this.onFilterPressed,
  });

  final RankingsViewMode mode;
  final ValueChanged<RankingsViewMode> onModeChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        final filterReserve = kIsWeb ? 128.0 : 44.0;
        const gapAfterSegment = 12.0;
        final maxSeg = kIsWeb ? 300.0 : 252.0;
        final segmentWidth = math.min(
          maxSeg,
          math.max(120.0, avail - filterReserve - gapAfterSegment),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: segmentWidth,
              child: _SlidingRankingsSegmentedControl(
                mode: mode,
                onModeChanged: onModeChanged,
              ),
            ),
            const SizedBox(width: gapAfterSegment),
            const Spacer(),
            _RankingsFilterButton(onPressed: onFilterPressed),
          ],
        );
      },
    );
  }
}

/// Mobile: compact tonal icon (unchanged feel). Web: purple→pink gradient + label.
class _RankingsFilterButton extends StatelessWidget {
  const _RankingsFilterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      const radius = 20.0;
      return Tooltip(
        message: 'Filters',
        child: Material(
          color: Colors.transparent,
          elevation: 3,
          shadowColor: ScenolyticsColors.webRankingsFilterGradientEnd
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: ScenolyticsColors.webRankingsFilterGradient,
                borderRadius: BorderRadius.all(Radius.circular(radius)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: ScenolyticsColors.webRankingsFilterForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: ScenolyticsColors.webRankingsFilterForeground,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: 'Filters',
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
      ),
      icon: const Icon(Icons.tune_rounded, size: 20),
    );
  }
}

/// One capsule control with a sliding pill (iOS-style); colors from [ScenolyticsColors].
class _SlidingRankingsSegmentedControl extends StatelessWidget {
  const _SlidingRankingsSegmentedControl({
    required this.mode,
    required this.onModeChanged,
  });

  final RankingsViewMode mode;
  final ValueChanged<RankingsViewMode> onModeChanged;

  static const double _height = 36;
  static const double _pillInset = 2.5;

  int get _selectedIndex => switch (mode) {
        RankingsViewMode.all => 0,
        RankingsViewMode.topTen => 1,
        RankingsViewMode.callbacks => 2,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final track = ScenolyticsColors.rankingsSegmentTrack(b);
    final pill = ScenolyticsColors.rankingsSegmentPill(b);
    final selectedLabel = ScenolyticsColors.rankingsSegmentSelectedLabel(b);
    final unselectedLabel = ScenolyticsColors.rankingsSegmentUnselectedLabel(b);
    final pillRadius = (_height - 2 * _pillInset) / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w <= 0) return const SizedBox(height: _height);

        final segW = w / 3;
        final pillW = segW - 2 * _pillInset;
        final pillLeft = _pillInset + _selectedIndex * segW;

        return SizedBox(
          height: _height,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
                child: const SizedBox.expand(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: pillLeft,
                top: _pillInset,
                width: pillW,
                bottom: _pillInset,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pill,
                    borderRadius: BorderRadius.circular(pillRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: b == Brightness.dark ? 0.28 : 0.1,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SegmentTap(
                      label: 'All Rankings',
                      selected: mode == RankingsViewMode.all,
                      selectedColor: selectedLabel,
                      unselectedColor: unselectedLabel,
                      onTap: () => onModeChanged(RankingsViewMode.all),
                    ),
                  ),
                  Expanded(
                    child: _SegmentTap(
                      label: 'Top Candidates',
                      selected: mode == RankingsViewMode.topTen,
                      selectedColor: selectedLabel,
                      unselectedColor: unselectedLabel,
                      onTap: () => onModeChanged(RankingsViewMode.topTen),
                    ),
                  ),
                  Expanded(
                    child: _SegmentTap(
                      label: 'Callbacks',
                      selected: mode == RankingsViewMode.callbacks,
                      selectedColor: selectedLabel,
                      unselectedColor: unselectedLabel,
                      onTap: () => onModeChanged(RankingsViewMode.callbacks),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentTap extends StatelessWidget {
  const _SegmentTap({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          _SlidingRankingsSegmentedControl._height / 2,
        ),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  fontSize: 12.5,
                  color: selected ? selectedColor : unselectedColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showRankingsFiltersBottomSheet(BuildContext context) {
  if (kIsWeb) {
    _showRankingsFiltersWebDialog(context);
  } else {
    _showRankingsFiltersMobileSheet(context);
  }
}

void _showRankingsFiltersWebDialog(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Score range, role, date, tags, and more will live here when '
                  'you connect your API.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showRankingsFiltersMobileSheet(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.paddingOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filters',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score range, role, date, tags, and more will live here when '
              'you connect your API.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}

/// Hero-style card: title, audition name, and round — gradients in light mode,
/// deeper hero tones in dark mode so it stays readable on the page backdrop.
class _RankingsHeaderCard extends StatelessWidget {
  const _RankingsHeaderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final cs = theme.colorScheme;
    final onHero = ScenolyticsColors.onPrimary;

    final decoration = BoxDecoration(
      gradient: b == Brightness.dark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF021A2E),
                ScenolyticsColors.heroGradientStart,
                Color(0xFF052F45),
              ],
            )
          : ScenolyticsColors.heroBarGradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: onHero.withValues(alpha: b == Brightness.dark ? 0.12 : 0.2),
      ),
      boxShadow: [
        BoxShadow(
          color: cs.shadow.withValues(alpha: b == Brightness.dark ? 0.35 : 0.12),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: decoration,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.movie_filter_rounded, color: onHero, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Audition rankings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 8,
                            color: Color(0x55000000),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                kMockAuditionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
                    size: 18,
                    color: onHero.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kMockAuditionRound,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onHero.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: -8,
          top: -12,
          child: Icon(
            Icons.movie_filter_rounded,
            size: 96,
            color: onHero.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.totalSubmissions,
    required this.averageScore,
    required this.topScore,
    required this.callbacksSent,
  });

  final int totalSubmissions;
  final double averageScore;
  final double topScore;
  final int callbacksSent;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final cards = <Widget>[
      _StatCard(
        label: 'Total submissions',
        value: '$totalSubmissions',
        icon: Icons.groups_2_outlined,
      ),
      _StatCard(
        label: 'Average score',
        value: averageScore.toStringAsFixed(1),
        icon: Icons.analytics_outlined,
      ),
      _StatCard(
        label: 'Top score',
        value: topScore.toStringAsFixed(1),
        icon: Icons.emoji_events_outlined,
      ),
      _StatCard(
        label: 'Callbacks sent',
        value: '$callbacksSent',
        icon: Icons.mark_email_read_outlined,
      ),
    ];

    if (width >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(child: cards[i]),
            if (i < 3) const SizedBox(width: 12),
          ],
        ],
      );
    }

    // Phone and tablet: two cards per row (2×2).
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;

    return Material(
      color: cs.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(b).withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
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

class _CompactRankCard extends StatelessWidget {
  const _CompactRankCard({required this.entry});

  final RankedAuditionSubmission entry;

  static const double _radius = 14;
  static const double _accentWidth = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final s = entry.submission;

    final cardBg = b == Brightness.dark
        ? ScenolyticsColors.actorCardSurfaceDark
        : ScenolyticsColors.actorCardSurfaceLight;
    final cardBorder = b == Brightness.dark
        ? ScenolyticsColors.actorCardBorderDark
        : ScenolyticsColors.actorCardBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: b == Brightness.dark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _accentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _leftRankAccentGradient(entry.rank),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _accentWidth + 16,
                16,
                16,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActorRankMedal(rank: entry.rank),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.actorName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Age: ${s.age}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.auditionRole,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _OverallScoreChip(score: s.score),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          final narrow = c.maxWidth < 360;
                          final metrics = <(String, int, Color)>[
                            ('Emotional', s.emotionalScore,
                                ScenolyticsColors.metricEmotional),
                            ('Vocal tone', s.vocalToneScore,
                                ScenolyticsColors.metricVocalTone),
                            ('Body language', s.bodyLanguageScore,
                                ScenolyticsColors.metricBodyLanguage),
                            ('Script match', s.scriptMatchScore,
                                ScenolyticsColors.metricScriptMatch),
                          ];
                          final track = b == Brightness.dark
                              ? ScenolyticsColors.actorCardMetricTrackDark
                              : ScenolyticsColors.actorCardMetricTrackLight;

                          Widget cell(int i) {
                            final (label, value, color) = metrics[i];
                            return _ActorMetricBar(
                              label: label,
                              value: value,
                              barColor: color,
                              trackColor: track,
                            );
                          }

                          if (narrow) {
                            return Column(
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: cell(0)),
                                    const SizedBox(width: 10),
                                    Expanded(child: cell(1)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: cell(2)),
                                    const SizedBox(width: 10),
                                    Expanded(child: cell(3)),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < 4; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(child: cell(i)),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, fc) {
                          final stackFooter = fc.maxWidth < 320;
                          final submitted = Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatActorCardSubmitted(s.submittedAt),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          );
                          final watch = OutlinedButton.icon(
                            onPressed: () {},
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Watch'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.onSurface,
                              side: BorderSide(
                                color: cs.outline.withValues(alpha: 0.65),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          if (stackFooter) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                submitted,
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: watch,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: submitted),
                              watch,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static LinearGradient _leftRankAccentGradient(int rank) {
    return switch (rank) {
      1 => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD54F), Color(0xFFFF8C42)],
        ),
      2 => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ScenolyticsColors.rankSilver,
            ScenolyticsColors.rankSilver.withValues(alpha: 0.55),
          ],
        ),
      3 => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCD7F32), Color(0xFF8B5A2B)],
        ),
      _ => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ScenolyticsColors.accentCyan, ScenolyticsColors.secondary],
        ),
    };
  }
}

String _formatActorCardSubmitted(DateTime utc) {
  final local = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Submitted: ${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _ActorRankMedal extends StatelessWidget {
  const _ActorRankMedal({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 48.0;

    if (rank <= 3) {
      final (Color iconColor, IconData icon) = switch (rank) {
        1 => (const Color(0xFFFFD700), Icons.emoji_events_rounded),
        2 => (const Color(0xFFC0C5CE), Icons.emoji_events_rounded),
        3 => (const Color(0xFFCD7F32), Icons.emoji_events_rounded),
        _ => (Colors.white, Icons.emoji_events_rounded),
      };

      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: ScenolyticsColors.rankMedalBackdrop,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 26),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _OverallScoreChip extends StatelessWidget {
  const _OverallScoreChip({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ScenolyticsColors.overallScoreChip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        score.round().toString(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ScenolyticsColors.overallScoreChipOn,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ActorMetricBar extends StatelessWidget {
  const _ActorMetricBar({
    required this.label,
    required this.value,
    required this.barColor,
    required this.trackColor,
  });

  final String label;
  final int value;
  final Color barColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final v = value.clamp(0, 100) / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$value',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: trackColor,
            color: barColor,
          ),
        ),
      ],
    );
  }
}
