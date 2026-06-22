import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repositories/auditions_repository.dart';
import '../models/actor_audition_card.dart';
import '../models/audition_listing.dart';
import '../models/audition_submission_status.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/callback_status_chips.dart';
import '../widgets/scenolytics_footer.dart';

/// Actor-facing dashboard listing every audition they have submitted to.
class ActorDashboardPage extends StatefulWidget {
  const ActorDashboardPage({
    super.key,
    required this.auditionsRepository,
    required this.actorToken,
    this.actorDisplayName,
    required this.onOpenSubmission,
    required this.onExploreAuditions,
  });

  final AuditionsRepository auditionsRepository;
  final String actorToken;
  final String? actorDisplayName;
  final ValueChanged<AuditionListing> onOpenSubmission;
  final VoidCallback onExploreAuditions;

  @override
  State<ActorDashboardPage> createState() => _ActorDashboardPageState();
}

enum _ActorSortMode {
  newest,
  oldest,
  alphabetical,
}

extension _ActorSortModeX on _ActorSortMode {
  String get label => switch (this) {
        _ActorSortMode.newest => 'Newest submission',
        _ActorSortMode.oldest => 'Oldest submission',
        _ActorSortMode.alphabetical => 'A → Z',
      };
}

class _ActorDashboardPageState extends State<ActorDashboardPage> {
  static const double _wideBreakpoint = 900;
  static const double _xWideBreakpoint = 1280;
  static const double _maxContentWidth = 1240;

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<ActorAuditionCard> _all = const <ActorAuditionCard>[];

  String _searchQuery = '';
  String _typeFilter = 'Any';
  String _statusFilter = 'Any';
  _ActorSortMode _sort = _ActorSortMode.newest;
  bool _filtersOpenOnPhone = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_searchCtrl.text == _searchQuery) return;
      setState(() => _searchQuery = _searchCtrl.text);
    });
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final firstLoad = _all.isEmpty && _loadError == null;
    if (firstLoad) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadError = null);
    }
    try {
      final cards = await widget.auditionsRepository.loadActorDashboard(
        actorToken: widget.actorToken,
      );
      if (!mounted) return;
      setState(() {
        _all = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = firstLoad
            ? 'Could not load your submissions (${e.runtimeType}). Pull to retry.'
            : 'Could not refresh (${e.runtimeType}). Pull to retry.';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _typeFilter = 'Any';
      _statusFilter = 'Any';
      _sort = _ActorSortMode.newest;
    });
  }

  int get _activeFilterCount {
    var n = 0;
    if (_typeFilter != 'Any') n++;
    if (_statusFilter != 'Any') n++;
    if (_sort != _ActorSortMode.newest) n++;
    return n;
  }

  int get _totalSubmissions => _all.length;
  int get _acceptedCount => _all
      .where((c) => c.submissionStatus == AuditionSubmissionStatus.accepted)
      .length;
  int get _callbackCount => _all.where((c) => c.hasCallback).length;

  List<ActorAuditionCard> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _all.where((c) {
      if (_typeFilter != 'Any' &&
          c.type.toLowerCase() != _typeFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter != 'Any') {
        final want = _statusFilter.toLowerCase();
        final have = switch (c.submissionStatus) {
          AuditionSubmissionStatus.pending => 'pending',
          AuditionSubmissionStatus.underReview => 'under_review',
          AuditionSubmissionStatus.accepted => 'accepted',
          AuditionSubmissionStatus.rejected => 'rejected',
          AuditionSubmissionStatus.unknown => '',
        };
        if (have != want) return false;
      }
      if (q.isEmpty) return true;
      final hay = <String>[
        c.title,
        c.audition.description,
        c.type,
        c.directorDisplayName ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _ActorSortMode.newest:
          final at = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        case _ActorSortMode.oldest:
          final at = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return at.compareTo(bt);
        case _ActorSortMode.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return filtered;
  }

  Future<void> _openMeet(String? url) async {
    final link = url?.trim() ?? '';
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Meet link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ScenolyticsColors.pageBackdropGradientFor(
                theme.brightness,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= _wideBreakpoint;
                  final hPad = c.maxWidth >= _xWideBreakpoint ? 36.0 : 16.0;
                  final layoutW = c.maxWidth;
                  final sidePad = hPad +
                      (layoutW > _maxContentWidth
                          ? (layoutW - _maxContentWidth) / 2
                          : 0.0);
                  return _buildBody(isWide: isWide, sidePad: sidePad);
                },
              ),
            ),
          ),
        ),
        const ScenolyticsFooter(),
      ],
    );
  }

  Widget _buildBody({required bool isWide, required double sidePad}) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final phoneFiltersInline = !isWide && _filtersOpenOnPhone;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(sidePad, 14, sidePad, 8),
          sliver: SliverToBoxAdapter(
            child: _ActorHero(
              actorName: widget.actorDisplayName,
              totalSubmissions: _totalSubmissions,
              acceptedCount: _acceptedCount,
              callbackCount: _callbackCount,
              isWide: isWide,
              onExplore: widget.onExploreAuditions,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(sidePad, 12, sidePad, 8),
          sliver: SliverToBoxAdapter(
            child: _ActorSearchAndToolbar(
              controller: _searchCtrl,
              isWide: isWide,
              activeFilterCount: _activeFilterCount,
              filtersOpenOnPhone: _filtersOpenOnPhone,
              onTogglePhoneFilters: () =>
                  setState(() => _filtersOpenOnPhone = !_filtersOpenOnPhone),
              onReset: _resetFilters,
              onRefresh: _refresh,
            ),
          ),
        ),
        if (isWide || phoneFiltersInline)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, 8),
            sliver: SliverToBoxAdapter(
              child: _ActorFilterBar(
                stacked: !isWide,
                typeFilter: _typeFilter,
                onType: (v) => setState(() => _typeFilter = v),
                statusFilter: _statusFilter,
                onStatus: (v) => setState(() => _statusFilter = v),
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
              ),
            ),
          ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 36, color: theme.colorScheme.error),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _ActorEmptyState(
                  hasFilters:
                      _activeFilterCount > 0 || _searchQuery.isNotEmpty,
                  hasAny: _all.isNotEmpty,
                  onResetFilters: _resetFilters,
                  onExplore: widget.onExploreAuditions,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 28),
            sliver: isWide
                ? SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 290,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ActorSubmissionCard(
                        card: filtered[i],
                        onOpen: () =>
                            widget.onOpenSubmission(filtered[i].audition),
                        onOpenMeet: () => _openMeet(filtered[i].meetLink),
                      ),
                      childCount: filtered.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ActorSubmissionCard(
                      card: filtered[i],
                      onOpen: () =>
                          widget.onOpenSubmission(filtered[i].audition),
                      onOpenMeet: () => _openMeet(filtered[i].meetLink),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class _ActorHero extends StatelessWidget {
  const _ActorHero({
    required this.actorName,
    required this.totalSubmissions,
    required this.acceptedCount,
    required this.callbackCount,
    required this.isWide,
    required this.onExplore,
  });

  final String? actorName;
  final int totalSubmissions;
  final int acceptedCount;
  final int callbackCount;
  final bool isWide;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final onHero = ScenolyticsColors.onPrimary;
    final name = actorName?.trim();
    final greeting = name == null || name.isEmpty
        ? 'Welcome back, Actor'
        : 'Welcome back, $name';

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradientFor(b),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onHero.withValues(alpha: ScenolyticsColors.heroBorderAlpha(b)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: onHero, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isWide)
                FilledButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore auditions'),
                  style: FilledButton.styleFrom(
                    backgroundColor: onHero,
                    foregroundColor: ScenolyticsColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            totalSubmissions == 0
                ? 'You have not submitted to any auditions yet. Browse open roles and upload your tape.'
                : 'Track every audition you submitted to — director decisions and callbacks.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onHero.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                icon: Icons.video_library_outlined,
                label: 'Submissions',
                value: '$totalSubmissions',
              ),
              _HeroMetric(
                icon: Icons.check_circle_outline,
                label: 'Accepted',
                value: '$acceptedCount',
              ),
              _HeroMetric(
                icon: Icons.phone_in_talk_outlined,
                label: 'Callbacks',
                value: '$callbackCount',
              ),
            ],
          ),
          if (!isWide) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore auditions'),
                style: FilledButton.styleFrom(
                  backgroundColor: onHero,
                  foregroundColor: ScenolyticsColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onHero = ScenolyticsColors.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onHero.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: onHero),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onHero,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onHero.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActorSearchAndToolbar extends StatelessWidget {
  const _ActorSearchAndToolbar({
    required this.controller,
    required this.isWide,
    required this.activeFilterCount,
    required this.onTogglePhoneFilters,
    required this.filtersOpenOnPhone,
    required this.onReset,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final bool isWide;
  final int activeFilterCount;
  final VoidCallback onTogglePhoneFilters;
  final bool filtersOpenOnPhone;
  final VoidCallback onReset;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search your auditions by title, director, or type…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => controller.clear(),
              ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );

    final refreshBtn = _ActorIconActionButton(
      tooltip: 'Refresh',
      icon: Icons.refresh_rounded,
      onPressed: () async {
        await onRefresh();
      },
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: search),
          const SizedBox(width: 10),
          refreshBtn,
          const SizedBox(width: 8),
          _ActorResetButton(
            enabled: activeFilterCount > 0 || controller.text.isNotEmpty,
            onTap: onReset,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActorFiltersToggle(
                count: activeFilterCount,
                open: filtersOpenOnPhone,
                onTap: onTogglePhoneFilters,
              ),
            ),
            const SizedBox(width: 8),
            refreshBtn,
            const SizedBox(width: 8),
            _ActorResetButton(
              enabled: activeFilterCount > 0 || controller.text.isNotEmpty,
              onTap: onReset,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActorIconActionButton extends StatelessWidget {
  const _ActorIconActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

class _ActorResetButton extends StatelessWidget {
  const _ActorResetButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
      label: const Text('Reset'),
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ActorFiltersToggle extends StatelessWidget {
  const _ActorFiltersToggle({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = 14.0;
    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: ScenolyticsColors.webRankingsFilterGradientEnd
          .withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: ScenolyticsColors.webRankingsFilterGradient,
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  open ? Icons.expand_less_rounded : Icons.tune_rounded,
                  size: 18,
                  color: ScenolyticsColors.webRankingsFilterForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  open ? 'Hide filters' : 'Filters & sort',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ScenolyticsColors.webRankingsFilterForeground,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: ScenolyticsColors.webRankingsFilterForeground,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActorFilterBar extends StatelessWidget {
  const _ActorFilterBar({
    required this.stacked,
    required this.typeFilter,
    required this.onType,
    required this.statusFilter,
    required this.onStatus,
    required this.sort,
    required this.onSort,
  });

  final bool stacked;
  final String typeFilter;
  final ValueChanged<String> onType;
  final String statusFilter;
  final ValueChanged<String> onStatus;
  final _ActorSortMode sort;
  final ValueChanged<_ActorSortMode> onSort;

  static const _statusOptions = <String>[
    'Any',
    'pending',
    'under_review',
    'accepted',
    'rejected',
  ];

  static String _statusLabel(String value) => switch (value) {
        'Any' => 'Any status',
        'pending' => 'Pending',
        'under_review' => 'Under review',
        'accepted' => 'Accepted',
        'rejected' => 'Rejected',
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeDropdown = _ActorLabeledDropdown<String>(
      icon: Icons.movie_filter_outlined,
      label: 'Type',
      value: typeFilter,
      items: const ['Any', 'Audio', 'Video'],
      itemLabel: (s) => s == 'Any' ? 'Any type' : s,
      onChanged: onType,
    );

    final statusDropdown = _ActorLabeledDropdown<String>(
      icon: Icons.flag_outlined,
      label: 'Status',
      value: statusFilter,
      items: _statusOptions,
      itemLabel: _statusLabel,
      onChanged: onStatus,
    );

    final sortDropdown = _ActorLabeledDropdown<_ActorSortMode>(
      icon: Icons.sort_rounded,
      label: 'Sort',
      value: sort,
      items: _ActorSortMode.values,
      itemLabel: (m) => m.label,
      onChanged: onSort,
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.25 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                typeDropdown,
                const SizedBox(height: 10),
                statusDropdown,
                const SizedBox(height: 10),
                sortDropdown,
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 200, child: typeDropdown),
                SizedBox(width: 220, child: statusDropdown),
                SizedBox(width: 280, child: sortDropdown),
              ],
            ),
    );
  }
}

class _ActorLabeledDropdown<T> extends StatelessWidget {
  const _ActorLabeledDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: items
          .map(
            (o) => DropdownMenuItem<T>(
              value: o,
              child: Text(itemLabel(o), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class _ActorEmptyState extends StatelessWidget {
  const _ActorEmptyState({
    required this.hasFilters,
    required this.hasAny,
    required this.onResetFilters,
    required this.onExplore,
  });

  final bool hasFilters;
  final bool hasAny;
  final VoidCallback onResetFilters;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: cs.primary),
        const SizedBox(height: 12),
        Text(
          hasFilters
              ? 'No auditions match your filters'
              : hasAny
                  ? 'Nothing here'
                  : 'No submissions yet',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Try clearing filters or broadening your search.'
              : 'Explore open auditions and submit your first self-tape.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (hasFilters)
          OutlinedButton(onPressed: onResetFilters, child: const Text('Reset filters'))
        else
          FilledButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore auditions'),
          ),
      ],
    );
  }
}

class _ActorSubmissionCard extends StatelessWidget {
  const _ActorSubmissionCard({
    required this.card,
    required this.onOpen,
    required this.onOpenMeet,
  });

  final ActorAuditionCard card;
  final VoidCallback onOpen;
  final VoidCallback onOpenMeet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final a = card.audition;
    final isVideo = a.type.toLowerCase() == 'video';
    final director = card.directorDisplayName?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.cardSheenFor(b),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isVideo
                            ? Icons.movie_creation_outlined
                            : Icons.mic_none_rounded,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title.isEmpty ? 'Untitled audition' : a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (director.isNotEmpty)
                            Text(
                              director,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.type,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SubmissionStatusChip(status: card.submissionStatus),
                    if (card.hasCallback &&
                        card.callbackStatus != null)
                      CallbackStatusChip(status: card.callbackStatus!),
                  ],
                ),
                const SizedBox(height: 10),
                _MiniStat(
                  icon: Icons.schedule_outlined,
                  label: 'Submitted',
                  value: _submittedLabel(card.submittedAt),
                ),
                if (card.callbackDatetime != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Callback ${_formatDt(card.callbackDatetime!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: onOpen,
                        child: const Text('View submission'),
                      ),
                    ),
                    if (card.meetLink != null &&
                        card.meetLink!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onOpenMeet,
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: 'Open Meet',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _submittedLabel(DateTime? when) {
    if (when == null) return '—';
    final l = when.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${p2(l.month)}-${p2(l.day)}';
  }

  static String _formatDt(DateTime dt) {
    final l = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${p2(l.month)}-${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }
}

class _SubmissionStatusChip extends StatelessWidget {
  const _SubmissionStatusChip({required this.status});

  final AuditionSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = auditionSubmissionStatusAccent(cs, status);
    final fg = auditionSubmissionStatusOnAccent(cs, status);
    if (bg == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        auditionSubmissionStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
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
