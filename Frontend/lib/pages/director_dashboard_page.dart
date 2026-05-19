import 'package:flutter/material.dart';

import '../data/api/casting_api.dart';
import '../data/repositories/auditions_repository.dart';
import '../models/director_audition_card.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

/// Director-facing dashboard. Lists every audition the signed-in director
/// owns (`GET /api/v1/casting/director/auditions`) and decorates each row
/// with submission / pending-invite / callback counts plus a top score.
///
/// Layout matches the rest of the app: web ≥ [_wideBreakpoint] gets a grid
/// + horizontal filter toolbar, phone gets a stacked list + collapsible
/// filter sheet. Theme is shared with `ExploreAuditionsPage`.
class DirectorDashboardPage extends StatefulWidget {
  const DirectorDashboardPage({
    super.key,
    required this.auditionsRepository,
    required this.directorToken,
    required this.directorDisplayName,
    required this.onOpenRankings,
    required this.onCreateAudition,
  });

  final AuditionsRepository auditionsRepository;
  final String directorToken;
  final String? directorDisplayName;

  /// Called when the director taps "View rankings" on a card; the parent
  /// shell uses the id to route to [AuditionRankingsPage].
  final ValueChanged<DirectorAuditionCard> onOpenRankings;

  /// Called when the director taps the "Create audition" CTA in the empty
  /// state or hero — parent shell switches to the creation page.
  final VoidCallback onCreateAudition;

  @override
  State<DirectorDashboardPage> createState() => _DirectorDashboardPageState();
}

enum _SortMode {
  newest,
  oldest,
  mostSubmissions,
  mostPending,
  topScore,
  alphabetical,
}

extension _SortModeX on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.newest:
        return 'Newest first';
      case _SortMode.oldest:
        return 'Oldest first';
      case _SortMode.mostSubmissions:
        return 'Most submissions';
      case _SortMode.mostPending:
        return 'Most pending invites';
      case _SortMode.topScore:
        return 'Top score';
      case _SortMode.alphabetical:
        return 'A → Z';
    }
  }
}

class _DirectorDashboardPageState extends State<DirectorDashboardPage> {
  // Breakpoints aligned with MainShell / Explore so layout switches in lockstep.
  static const double _wideBreakpoint = 900;
  static const double _xWideBreakpoint = 1280;
  static const double _maxContentWidth = 1240;

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<DirectorAuditionCard> _all = const <DirectorAuditionCard>[];

  // Filter / sort state
  String _searchQuery = '';
  String _typeFilter = 'Any'; // Any | Audio | Video
  _SortMode _sort = _SortMode.newest;
  bool _activityOnly = false; // hide auditions with zero activity
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cards = await widget.auditionsRepository.loadDirectorDashboard(
        directorToken: widget.directorToken,
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
        _loadError =
            'Could not load your auditions (${e.runtimeType}). Pull to retry.';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _typeFilter = 'Any';
      _sort = _SortMode.newest;
      _activityOnly = false;
    });
  }

  int get _activeFilterCount {
    var n = 0;
    if (_typeFilter != 'Any') n++;
    if (_activityOnly) n++;
    if (_sort != _SortMode.newest) n++;
    return n;
  }

  // ---------------------------------------------------------------------------
  // Derived summary metrics (always over the unfiltered set so the hero stays
  // stable while the director plays with filters).
  // ---------------------------------------------------------------------------

  int get _totalAuditions => _all.length;
  int get _totalSubmissions =>
      _all.fold<int>(0, (acc, c) => acc + c.submissionsCount);
  int get _totalPending =>
      _all.fold<int>(0, (acc, c) => acc + c.pendingInvitationsCount);
  int get _totalCallbacks =>
      _all.fold<int>(0, (acc, c) => acc + c.callbacksCount);

  List<DirectorAuditionCard> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _all.where((c) {
      if (_typeFilter != 'Any' &&
          c.audition.type.toLowerCase() != _typeFilter.toLowerCase()) {
        return false;
      }
      if (_activityOnly && c.totalActivity == 0) return false;
      if (q.isEmpty) return true;
      final hay = <String>[
        c.audition.title,
        c.audition.description,
        c.audition.type,
        c.audition.gender,
        c.audition.ethnicity,
        c.audition.bodyType,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();

    int compareDate(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    filtered.sort((a, b) {
      switch (_sort) {
        case _SortMode.newest:
          return -compareDate(a.audition.createdAt, b.audition.createdAt);
        case _SortMode.oldest:
          return compareDate(a.audition.createdAt, b.audition.createdAt);
        case _SortMode.mostSubmissions:
          return b.submissionsCount.compareTo(a.submissionsCount);
        case _SortMode.mostPending:
          return b.pendingInvitationsCount.compareTo(a.pendingInvitationsCount);
        case _SortMode.topScore:
          final av = a.topSubmissionScore ?? -1;
          final bv = b.topSubmissionScore ?? -1;
          return bv.compareTo(av);
        case _SortMode.alphabetical:
          return a.audition.title
              .toLowerCase()
              .compareTo(b.audition.title.toLowerCase());
      }
    });

    return filtered;
  }

  Future<void> _confirmAndDelete(DirectorAuditionCard card) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: Icon(Icons.delete_forever_rounded, color: cs.error, size: 32),
          title: const Text('Delete this audition?'),
          content: Text(
            card.title.isEmpty
                ? 'This audition will be permanently removed along with its '
                    'submissions and callbacks.'
                : '“${card.title}” and all of its submissions, invitations, '
                    'and callbacks will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    // Optimistic removal — restore on failure.
    final snapshot = _all;
    setState(() {
      _all = _all.where((c) => c.id != card.id).toList();
    });
    try {
      await widget.auditionsRepository.deleteDirectorAudition(
        directorToken: widget.directorToken,
        auditionId: card.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audition deleted.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _all = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _all = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed (${e.runtimeType}).')),
      );
    }
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
            child: _DashboardHero(
              directorName: widget.directorDisplayName,
              totalAuditions: _totalAuditions,
              totalSubmissions: _totalSubmissions,
              totalPending: _totalPending,
              totalCallbacks: _totalCallbacks,
              onCreateAudition: widget.onCreateAudition,
              isWide: isWide,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(sidePad, 12, sidePad, 8),
          sliver: SliverToBoxAdapter(
            child: _SearchAndToolbar(
              controller: _searchCtrl,
              isWide: isWide,
              activeFilterCount: _activeFilterCount,
              onTogglePhoneFilters: () =>
                  setState(() => _filtersOpenOnPhone = !_filtersOpenOnPhone),
              filtersOpenOnPhone: _filtersOpenOnPhone,
              onReset: _resetFilters,
              onRefresh: _refresh,
            ),
          ),
        ),
        if (isWide || phoneFiltersInline)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, 8),
            sliver: SliverToBoxAdapter(
              child: _FilterBar(
                stacked: !isWide,
                typeFilter: _typeFilter,
                onType: (v) => setState(() => _typeFilter = v),
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
                activityOnly: _activityOnly,
                onActivityOnly: (v) => setState(() => _activityOnly = v),
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
                child: _EmptyState(
                  hasFilters: _activeFilterCount > 0 || _searchQuery.isNotEmpty,
                  hasAnyAuditions: _all.isNotEmpty,
                  onResetFilters: _resetFilters,
                  onCreateAudition: widget.onCreateAudition,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 28),
            sliver: isWide
                ? SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 300,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _DashboardAuditionCard(
                        card: filtered[i],
                        onOpenRankings: () =>
                            widget.onOpenRankings(filtered[i]),
                        onDelete: () => _confirmAndDelete(filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _DashboardAuditionCard(
                      card: filtered[i],
                      onOpenRankings: () => widget.onOpenRankings(filtered[i]),
                      onDelete: () => _confirmAndDelete(filtered[i]),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero (welcome + summary metrics + create CTA)
// ---------------------------------------------------------------------------

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.directorName,
    required this.totalAuditions,
    required this.totalSubmissions,
    required this.totalPending,
    required this.totalCallbacks,
    required this.onCreateAudition,
    required this.isWide,
  });

  final String? directorName;
  final int totalAuditions;
  final int totalSubmissions;
  final int totalPending;
  final int totalCallbacks;
  final VoidCallback onCreateAudition;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final cs = theme.colorScheme;
    final onHero = ScenolyticsColors.onPrimary;
    final name = directorName?.trim();
    final greeting = name == null || name.isEmpty
        ? 'Welcome back, Director'
        : 'Welcome back, $name';

    final tiles = <Widget>[
      _HeroMetricTile(
        icon: Icons.theater_comedy_outlined,
        label: 'Auditions',
        value: '$totalAuditions',
      ),
      _HeroMetricTile(
        icon: Icons.video_library_outlined,
        label: 'Submissions',
        value: '$totalSubmissions',
      ),
      _HeroMetricTile(
        icon: Icons.mark_email_unread_outlined,
        label: 'Pending invites',
        value: '$totalPending',
      ),
      _HeroMetricTile(
        icon: Icons.phone_in_talk_outlined,
        label: 'Callbacks',
        value: '$totalCallbacks',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
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
            color: cs.shadow.withValues(
              alpha: b == Brightness.dark ? 0.35 : 0.12,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_customize_outlined,
                      color: onHero, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  if (isWide)
                    FilledButton.icon(
                      onPressed: onCreateAudition,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Create audition'),
                      style: FilledButton.styleFrom(
                        backgroundColor: onHero,
                        foregroundColor: ScenolyticsColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                totalAuditions == 0
                    ? 'You haven\'t created any auditions yet. Spin one up to start collecting submissions.'
                    : 'Here\'s the pulse on every audition you own. Tap a card to '
                        'jump into rankings or manage casting.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.92),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final t in tiles) t],
              ),
              if (!isWide) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreateAudition,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Create new audition'),
                    style: FilledButton.styleFrom(
                      backgroundColor: onHero,
                      foregroundColor: ScenolyticsColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            right: -8,
            top: -12,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 96,
              color: onHero.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onHero,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onHero.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search + toolbar
// ---------------------------------------------------------------------------

class _SearchAndToolbar extends StatelessWidget {
  const _SearchAndToolbar({
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final search = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search your auditions by title, description, or tag…',
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

    final refreshBtn = _IconActionButton(
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
          _ResetButton(
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
              child: _FiltersToggle(
                count: activeFilterCount,
                open: filtersOpenOnPhone,
                onTap: onTogglePhoneFilters,
              ),
            ),
            const SizedBox(width: 8),
            refreshBtn,
            const SizedBox(width: 8),
            _ResetButton(
              enabled: activeFilterCount > 0 || controller.text.isNotEmpty,
              onTap: onReset,
            ),
          ],
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
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

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.enabled, required this.onTap});

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

class _FiltersToggle extends StatelessWidget {
  const _FiltersToggle({
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

// ---------------------------------------------------------------------------
// Filter bar (web: horizontal, phone: stacked)
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.stacked,
    required this.typeFilter,
    required this.onType,
    required this.sort,
    required this.onSort,
    required this.activityOnly,
    required this.onActivityOnly,
  });

  final bool stacked;
  final String typeFilter;
  final ValueChanged<String> onType;
  final _SortMode sort;
  final ValueChanged<_SortMode> onSort;
  final bool activityOnly;
  final ValueChanged<bool> onActivityOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeDropdown = _LabeledDropdown<String>(
      icon: Icons.movie_filter_outlined,
      label: 'Type',
      value: typeFilter,
      items: const ['Any', 'Audio', 'Video'],
      itemLabel: (s) => s,
      onChanged: onType,
    );

    final sortDropdown = _LabeledDropdown<_SortMode>(
      icon: Icons.sort_rounded,
      label: 'Sort',
      value: sort,
      items: _SortMode.values,
      itemLabel: (m) => m.label,
      onChanged: onSort,
    );

    final activitySwitch = _ActivityOnlySwitch(
      value: activityOnly,
      onChanged: onActivityOnly,
    );

    final card = Container(
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
                sortDropdown,
                const SizedBox(height: 10),
                activitySwitch,
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 200, child: typeDropdown),
                SizedBox(width: 260, child: sortDropdown),
                SizedBox(width: 260, child: activitySwitch),
              ],
            ),
    );

    return card;
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
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

class _ActivityOnlySwitch extends StatelessWidget {
  const _ActivityOnlySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Activity only',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _DashboardAuditionCard extends StatelessWidget {
  const _DashboardAuditionCard({
    required this.card,
    required this.onOpenRankings,
    required this.onDelete,
  });

  final DirectorAuditionCard card;
  final VoidCallback onOpenRankings;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final a = card.audition;
    final isVideo = a.type.toLowerCase() == 'video';
    final desc = a.description.trim();

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.cardSheenFor(b),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(
                alpha: b == Brightness.dark ? 0.28 : 0.06,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onOpenRankings,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _relativeTimeLabel(a.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TypePill(type: a.type),
                  ],
                ),
                const SizedBox(height: 10),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    'No description provided.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CountChip(
                        icon: Icons.video_library_outlined,
                        label: 'Submissions',
                        value: card.submissionsCount,
                        accent: ScenolyticsColors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _CountChip(
                        icon: Icons.mark_email_unread_outlined,
                        label: 'Pending',
                        value: card.pendingInvitationsCount,
                        accent: ScenolyticsColors.info,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _CountChip(
                        icon: Icons.phone_in_talk_outlined,
                        label: 'Callbacks',
                        value: card.callbacksCount,
                        accent: ScenolyticsColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TagChip(
                      icon: Icons.cake_outlined,
                      label: 'Age ${a.ageLabel}',
                    ),
                    _TagChip(
                      icon: Icons.wc_outlined,
                      label: a.gender,
                    ),
                    if (a.ethnicity.toLowerCase() != 'any')
                      _TagChip(
                        icon: Icons.diversity_3_outlined,
                        label: a.ethnicity,
                      ),
                    if (a.bodyType.toLowerCase() != 'any')
                      _TagChip(
                        icon: Icons.accessibility_new_rounded,
                        label: a.bodyType,
                      ),
                    if (a.hasHeightRequirement)
                      _TagChip(
                        icon: Icons.height_rounded,
                        label: a.heightLabel,
                      ),
                    if (card.topSubmissionScore != null)
                      _TagChip(
                        icon: Icons.emoji_events_outlined,
                        label:
                            'Top ${card.topSubmissionScore!.toStringAsFixed(1)}',
                        emphasis: true,
                      ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenRankings,
                        icon: const Icon(Icons.leaderboard_outlined, size: 18),
                        label: const Text('View rankings'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Delete audition',
                      child: Material(
                        color: cs.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(11),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(11),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTimeLabel(DateTime? when) {
    if (when == null) return 'Created date unknown';
    final now = DateTime.now().toUtc();
    final t = when.toUtc();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Created just now';
    if (diff.inHours < 1) return 'Created ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Created ${diff.inHours}h ago';
    if (diff.inDays < 30) return 'Created ${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return 'Created ${months}mo ago';
    return 'Created ${(diff.inDays / 365).floor()}y ago';
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final isVideo = type.toLowerCase() == 'video';
    final theme = Theme.of(context);
    final color = isVideo
        ? ScenolyticsColors.accentCyan
        : ScenolyticsColors.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        type.isEmpty ? '—' : type,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isZero = value == 0;
    final color = isZero ? cs.onSurfaceVariant : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isZero ? 0.25 : 0.55),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.icon,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = emphasis
        ? ScenolyticsColors.rankBronze
        : cs.primary;
    final bg = emphasis
        ? ScenolyticsColors.rankBronze.withValues(alpha: 0.18)
        : cs.surfaceContainerHighest.withValues(alpha: 0.6);
    final border = emphasis
        ? ScenolyticsColors.rankBronze.withValues(alpha: 0.55)
        : cs.outlineVariant.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: emphasis ? color : cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.hasAnyAuditions,
    required this.onResetFilters,
    required this.onCreateAudition,
  });

  /// Some filter/search is active and is currently hiding results.
  final bool hasFilters;

  /// Director has at least one audition in the system (just none after filters).
  final bool hasAnyAuditions;
  final VoidCallback onResetFilters;
  final VoidCallback onCreateAudition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (hasFilters && hasAnyAuditions) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 44, color: cs.primary),
          const SizedBox(height: 10),
          Text(
            'No auditions match your filters',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the search or filters to see your auditions again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onResetFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset filters'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.theater_comedy_outlined, size: 44, color: cs.primary),
        const SizedBox(height: 10),
        Text(
          'No auditions yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create your first audition to start collecting submissions, '
          'invitations, and callbacks here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCreateAudition,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Create audition'),
        ),
      ],
    );
  }
}
