import 'package:flutter/material.dart';

import '../data/mock_audition_rankings.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';

/// Director-facing leaderboard of actor submissions for an audition, sorted by score.
/// Layout adapts from narrow (mobile) to wide (web / tablet landscape).
class AuditionRankingsPage extends StatelessWidget {
  const AuditionRankingsPage({super.key});

  static const double _wideBreakpoint = 800;

  @override
  Widget build(BuildContext context) {
    final ranked = mockRankedAuditionSubmissions();
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < _wideBreakpoint;

    if (ranked.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No submissions yet.'),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: ScenolyticsColors.pageBackdropGradient,
      ),
      child: CustomScrollView(
        slivers: [
          if (narrow)
            SliverToBoxAdapter(child: _RankingHeroBanner())
          else
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 132,
              automaticallyImplyLeading: false,
              backgroundColor: ScenolyticsColors.primary,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: ScenolyticsColors.onPrimary,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 20,
                  bottom: 18,
                ),
                title: Text(
                  'Audition rankings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: ScenolyticsColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 6,
                        color: Color(0x66000000),
                      ),
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: ScenolyticsColors.heroBarGradient,
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: -30,
                      child: Icon(
                        Icons.movie_filter_rounded,
                        size: 140,
                        color: ScenolyticsColors.onPrimary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
                    size: 20,
                    color: ScenolyticsColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The Horizon — Callback round',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ScenolyticsColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _SummaryStrip(
                count: ranked.length,
                topScore: ranked.first.submission.score,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.crossAxisExtent >= _wideBreakpoint;
                if (wide) {
                  return SliverToBoxAdapter(
                    child: _WideLeaderboardTable(ranked: ranked),
                  );
                }
                return SliverList.separated(
                  itemCount: ranked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _CompactRankCard(entry: ranked[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone layout: scrolls with the page (no [SliverAppBar]).
///
/// A [Scaffold] [drawer] makes [SliverAppBar] imply a second menu icon; a pinned
/// bar with a transparent [backgroundColor] also loses the gradient when collapsed.
class _RankingHeroBanner extends StatelessWidget {
  const _RankingHeroBanner();

  static const double _height = 132;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: ScenolyticsColors.heroBarGradient,
                ),
              ),
              Positioned(
                right: -20,
                top: -30,
                child: Icon(
                  Icons.movie_filter_rounded,
                  size: 140,
                  color: ScenolyticsColors.onPrimary.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Audition rankings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: ScenolyticsColors.onPrimary,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 6,
                          color: Color(0x66000000),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.count, required this.topScore});

  final int count;
  final double topScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.accentCyan.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryChip(
                  icon: Icons.groups_2_outlined,
                  label: 'Submissions',
                  value: '$count',
                  tint: ScenolyticsColors.primaryContainer,
                  iconColor: ScenolyticsColors.primary,
                ),
                _SummaryChip(
                  icon: Icons.emoji_events_rounded,
                  label: 'Top score',
                  value: topScore.toStringAsFixed(1),
                  tint: ScenolyticsColors.accentCyanMuted,
                  iconColor: ScenolyticsColors.secondary,
                ),
                _SummaryChip(
                  icon: Icons.insights_outlined,
                  label: 'Live sort',
                  value: 'By score',
                  tint: ScenolyticsColors.tertiaryContainer,
                  iconColor: ScenolyticsColors.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: ScenolyticsColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sorted by score · tied scores share the same rank',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ScenolyticsColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ScenolyticsColors.textMuted,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ScenolyticsColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactRankCard extends StatelessWidget {
  const _CompactRankCard({required this.entry});

  final RankedAuditionSubmission entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = entry.submission;
    final accent = _rankAccent(entry.rank);

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(17),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withValues(alpha: 0.45)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _RankBadge(rank: entry.rank),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.actorName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ScenolyticsColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ScenolyticsColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.auditionRole,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color:
                                      ScenolyticsColors.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: ScenolyticsColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSubmitted(s.submittedAt),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ScenolyticsColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                ScenolyticsColors.primaryBright,
                                ScenolyticsColors.accentCyan,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              s.score.toStringAsFixed(1),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            'score',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ScenolyticsColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _rankAccent(int rank) {
    return switch (rank) {
      1 => ScenolyticsColors.accentCyan,
      2 => ScenolyticsColors.secondary,
      3 => ScenolyticsColors.tertiary,
      _ => ScenolyticsColors.outlineStrong,
    };
  }
}

class _WideLeaderboardTable extends StatelessWidget {
  const _WideLeaderboardTable({required this.ranked});

  final List<RankedAuditionSubmission> ranked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.accentCyan.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primary.withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final parentWidth = maxW.isFinite && maxW > 0 ? maxW : 640.0;
          const minTable = 640.0;
          final needsHorizontalScroll = parentWidth < minTable;
          final tableWidth = needsHorizontalScroll ? minTable : parentWidth;

          final table = Table(
            columnWidths: const {
              0: FixedColumnWidth(64),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2.2),
              3: FlexColumnWidth(1.4),
              4: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ScenolyticsColors.primary,
                      ScenolyticsColors.secondary,
                    ],
                  ),
                ),
                children: [
                  _tableHeader(context, 'Rank', light: true),
                  _tableHeader(context, 'Actor', light: true),
                  _tableHeader(context, 'Role / sides', light: true),
                  _tableHeader(context, 'Submitted', light: true),
                  _tableHeader(
                    context,
                    'Score',
                    align: TextAlign.end,
                    light: true,
                  ),
                ],
              ),
              for (var i = 0; i < ranked.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isOdd
                        ? ScenolyticsColors.surfaceTableStripe
                        : Colors.transparent,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      child: Center(
                        child: _RankBadge(rank: ranked[i].rank, dense: true),
                      ),
                    ),
                    _tableCell(
                      context,
                      ranked[i].submission.actorName,
                      weight: FontWeight.w700,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: ScenolyticsColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ranked[i].submission.auditionRole,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: ScenolyticsColors.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _tableCell(
                      context,
                      _formatSubmitted(ranked[i].submission.submittedAt),
                      muted: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            ScenolyticsColors.primaryBright,
                            ScenolyticsColors.accentCyan,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          ranked[i].submission.score.toStringAsFixed(1),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );

          final sized = SizedBox(width: tableWidth, child: table);
          if (needsHorizontalScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: sized,
            );
          }
          return sized;
        },
      ),
    );
  }

  static Widget _tableHeader(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.start,
    bool light = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(
        text,
        textAlign: align,
        style: theme.textTheme.labelLarge?.copyWith(
          color: light
              ? ScenolyticsColors.onPrimary
              : ScenolyticsColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static Widget _tableCell(
    BuildContext context,
    String text, {
    bool muted = false,
    FontWeight? weight,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: muted
              ? ScenolyticsColors.textMuted
              : ScenolyticsColors.textPrimary,
          fontWeight: weight,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, this.dense = false});

  final int rank;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (rank) {
      1 => (ScenolyticsColors.rankGold, ScenolyticsColors.rankGoldText),
      2 => (ScenolyticsColors.rankSilver, ScenolyticsColors.rankSilverText),
      3 => (ScenolyticsColors.rankBronze, ScenolyticsColors.rankBronzeText),
      _ => (
        ScenolyticsColors.primaryContainer,
        ScenolyticsColors.onPrimaryContainer,
      ),
    };

    final size = dense ? 38.0 : 46.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: fg.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: dense ? 16 : 18,
          color: fg,
        ),
      ),
    );
  }
}

String _formatSubmitted(DateTime utc) {
  final local = utc.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$m-$d · $h:$min';
}
