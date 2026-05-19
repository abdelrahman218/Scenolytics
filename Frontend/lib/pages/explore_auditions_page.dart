import 'package:flutter/material.dart';

import '../config/casting_audition_form_constants.dart';
import '../data/api/casting_api.dart';
import '../data/repositories/auditions_repository.dart';
import '../models/audition_listing.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

/// Actor-facing discovery page. Loads every audition from
/// `GET /api/v1/casting/actor/auditions` (casting `Audition.findAll`), enriches
/// director names and invitation/submission state, then search & filter locally.
class ExploreAuditionsPage extends StatefulWidget {
  const ExploreAuditionsPage({
    super.key,
    required this.auditionsRepository,
    required this.actorToken,
    required this.onApply,
    this.extraAuditionIds = const <String>[],
  });

  final AuditionsRepository auditionsRepository;
  final String actorToken;

  /// Compile-time / shell-provided audition ids to include even when the actor
  /// has no invitation or submission for them (e.g. `SCENO_AUDITION_ID`).
  final List<String> extraAuditionIds;

  /// Invoked when the actor taps "Apply" — receives the audition row so the
  /// parent shell can route to [AuditionVideoSubmissionPage] for that id.
  final ValueChanged<AuditionListing> onApply;

  @override
  State<ExploreAuditionsPage> createState() => _ExploreAuditionsPageState();
}

class _ExploreAuditionsPageState extends State<ExploreAuditionsPage> {
  // Same breakpoint family as MainShell / DirectorAuditionCreationPage so the
  // grid switches at the same place navigation/header layouts switch.
  static const double _wideBreakpoint = 900;
  static const double _xWideBreakpoint = 1280;
  static const double _maxContentWidth = 1240;

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<AuditionListing> _all = const <AuditionListing>[];

  // Filter state
  String _searchQuery = '';
  String _mediaType = 'Any'; // Any | Audio | Video
  String _gender = 'Any';    // Any | Male | Female | Both
  String _ethnicity = 'Any'; // Any | enum
  String _bodyType = 'Any';  // Any | enum
  RangeValues _ageRange = const RangeValues(18, 65);
  bool _filtersOpenOnPhone = false;

  static const _minAge = 5.0;
  static const _maxAge = 100.0;
  static const _ageRangeDefault = RangeValues(18, 65);

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
      final list = await widget.auditionsRepository.loadExploreAuditions(
        actorToken: widget.actorToken,
        extraAuditionIds: widget.extraAuditionIds,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final detail = e is ApiException
          ? (e.statusCode != null
              ? 'HTTP ${e.statusCode}: ${e.message}'
              : e.message)
          : e is FormatException
              ? 'Invalid response from server (not JSON). Check API base URL.'
              : '${e.runtimeType}';
      setState(() {
        _loading = false;
        _loadError = 'Could not load auditions ($detail). Pull to retry.';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _mediaType = 'Any';
      _gender = 'Any';
      _ethnicity = 'Any';
      _bodyType = 'Any';
      _ageRange = _ageRangeDefault;
    });
  }

  int get _activeFilterCount {
    var n = 0;
    if (_mediaType != 'Any') n++;
    if (_gender != 'Any') n++;
    if (_ethnicity != 'Any') n++;
    if (_bodyType != 'Any') n++;
    if (_ageRange != _ageRangeDefault) n++;
    return n;
  }

  List<AuditionListing> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _all.where((a) {
      if (_mediaType != 'Any' && a.type.toLowerCase() != _mediaType.toLowerCase()) {
        return false;
      }
      // Gender: 'Both' on an audition row matches any selected actor gender.
      if (_gender != 'Any' &&
          a.gender.toLowerCase() != 'both' &&
          a.gender.toLowerCase() != _gender.toLowerCase()) {
        return false;
      }
      // Ethnicity / body type: 'Any' on the audition matches anything.
      if (_ethnicity != 'Any' &&
          a.ethnicity.toLowerCase() != 'any' &&
          a.ethnicity.toLowerCase() != _ethnicity.toLowerCase()) {
        return false;
      }
      if (_bodyType != 'Any' &&
          a.bodyType.toLowerCase() != 'any' &&
          a.bodyType.toLowerCase() != _bodyType.toLowerCase()) {
        return false;
      }
      // Age: keep rows whose accepted age window intersects the selected window.
      final selectedMin = _ageRange.start.round();
      final selectedMax = _ageRange.end.round();
      if (a.maxAge < selectedMin || a.minAge > selectedMax) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = <String>[
        a.title,
        a.description,
        a.directorDisplayName ?? '',
        a.type,
        a.gender,
        a.ethnicity,
        a.bodyType,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
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
            child: _ExploreHero(
              total: _all.length,
              showing: filtered.length,
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
            ),
          ),
        ),
        if (isWide)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, 8),
            sliver: SliverToBoxAdapter(
              child: _FilterBar(
                mediaType: _mediaType,
                onMediaType: (v) => setState(() => _mediaType = v),
                gender: _gender,
                onGender: (v) => setState(() => _gender = v),
                ethnicity: _ethnicity,
                onEthnicity: (v) => setState(() => _ethnicity = v),
                bodyType: _bodyType,
                onBodyType: (v) => setState(() => _bodyType = v),
                ageRange: _ageRange,
                onAge: (r) => setState(() => _ageRange = r),
              ),
            ),
          )
        else if (phoneFiltersInline)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, 8),
            sliver: SliverToBoxAdapter(
              child: _FilterBar(
                mediaType: _mediaType,
                onMediaType: (v) => setState(() => _mediaType = v),
                gender: _gender,
                onGender: (v) => setState(() => _gender = v),
                ethnicity: _ethnicity,
                onEthnicity: (v) => setState(() => _ethnicity = v),
                bodyType: _bodyType,
                onBodyType: (v) => setState(() => _bodyType = v),
                ageRange: _ageRange,
                onAge: (r) => setState(() => _ageRange = r),
                stacked: true,
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
                  onResetFilters: _resetFilters,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePad, 8, sidePad, 28),
            sliver: isWide
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 268,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _AuditionCard(
                        audition: filtered[i],
                        onApply: () => widget.onApply(filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _AuditionCard(
                      audition: filtered[i],
                      onApply: () => widget.onApply(filtered[i]),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _ExploreHero extends StatelessWidget {
  const _ExploreHero({required this.total, required this.showing});

  final int total;
  final int showing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final cs = theme.colorScheme;
    final onHero = ScenolyticsColors.onPrimary;

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
                children: [
                  Icon(Icons.explore_outlined, color: onHero, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Explore auditions',
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
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? 'No auditions are open right now. Pull to refresh.'
                    : showing == total
                        ? 'Browse $total open auditions, filter by genre, age, and more, or jump straight to apply.'
                        : 'Showing $showing of $total auditions — adjust filters to widen results.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.92),
                  height: 1.35,
                ),
              ),
            ],
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search + toolbar (top row, both layouts)
// ---------------------------------------------------------------------------

class _SearchAndToolbar extends StatelessWidget {
  const _SearchAndToolbar({
    required this.controller,
    required this.isWide,
    required this.activeFilterCount,
    required this.onTogglePhoneFilters,
    required this.filtersOpenOnPhone,
    required this.onReset,
  });

  final TextEditingController controller;
  final bool isWide;
  final int activeFilterCount;
  final VoidCallback onTogglePhoneFilters;
  final bool filtersOpenOnPhone;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final search = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by audition, director, or description…',
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

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: search),
          const SizedBox(width: 10),
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
            const SizedBox(width: 10),
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

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.refresh_rounded, size: 18),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  open ? 'Hide filters' : 'Filters',
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

/// Returns a list with exactly one 'Any' at the head, deduping case-insensitively.
List<String> _withAny(List<String> source) {
  final seen = <String>{'any'};
  final out = <String>['Any'];
  for (final raw in source) {
    final v = raw.trim();
    if (v.isEmpty) continue;
    if (seen.add(v.toLowerCase())) {
      out.add(v);
    }
  }
  return out;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.mediaType,
    required this.onMediaType,
    required this.gender,
    required this.onGender,
    required this.ethnicity,
    required this.onEthnicity,
    required this.bodyType,
    required this.onBodyType,
    required this.ageRange,
    required this.onAge,
    this.stacked = false,
  });

  final String mediaType;
  final ValueChanged<String> onMediaType;
  final String gender;
  final ValueChanged<String> onGender;
  final String ethnicity;
  final ValueChanged<String> onEthnicity;
  final String bodyType;
  final ValueChanged<String> onBodyType;
  final RangeValues ageRange;
  final ValueChanged<RangeValues> onAge;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // `kAuditionEthnicities` and `kAuditionBodyTypes` already contain 'Any';
    // [_withAny] guarantees a single 'Any' entry no matter the source list so
    // `DropdownButtonFormField` never trips its "exactly one item" assertion.
    final mediaOptions = _withAny(kAuditionMediaTypes);
    final genderOptions = _withAny(const <String>['Male', 'Female', 'Both']);
    final ethnicityOptions = _withAny(kAuditionEthnicities);
    final bodyOptions = _withAny(kAuditionBodyTypes);

    final ageWidget = _AgeRangeField(
      value: ageRange,
      onChanged: onAge,
    );

    final dropdowns = <Widget>[
      _FilterDropdown(
        icon: Icons.movie_filter_outlined,
        label: 'Type',
        value: mediaType,
        options: mediaOptions,
        onChanged: onMediaType,
      ),
      _FilterDropdown(
        icon: Icons.wc_outlined,
        label: 'Gender',
        value: gender,
        options: genderOptions,
        onChanged: onGender,
      ),
      _FilterDropdown(
        icon: Icons.diversity_3_outlined,
        label: 'Ethnicity',
        value: ethnicity,
        options: ethnicityOptions,
        onChanged: onEthnicity,
      ),
      _FilterDropdown(
        icon: Icons.accessibility_new_rounded,
        label: 'Body type',
        value: bodyType,
        options: bodyOptions,
        onChanged: onBodyType,
      ),
    ];

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
                for (var i = 0; i < dropdowns.length; i++) ...[
                  dropdowns[i],
                  const SizedBox(height: 10),
                ],
                ageWidget,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < dropdowns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: dropdowns[i]),
                ],
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ageWidget,
                ),
              ],
            ),
    );

    return card;
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: options
          .map(
            (o) => DropdownMenuItem<String>(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
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
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
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

class _AgeRangeField extends StatelessWidget {
  const _AgeRangeField({required this.value, required this.onChanged});

  final RangeValues value;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cake_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Age',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${value.start.round()} – ${value.end.round()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          RangeSlider(
            min: _ExploreAuditionsPageState._minAge,
            max: _ExploreAuditionsPageState._maxAge,
            divisions:
                (_ExploreAuditionsPageState._maxAge - _ExploreAuditionsPageState._minAge).round(),
            labels: RangeLabels(
              '${value.start.round()}',
              '${value.end.round()}',
            ),
            values: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _AuditionCard extends StatelessWidget {
  const _AuditionCard({required this.audition, required this.onApply});

  final AuditionListing audition;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final isVideo = audition.type.toLowerCase() == 'video';
    final director = audition.directorDisplayName?.trim();
    final desc = audition.description.trim();

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
          onTap: onApply,
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
                            audition.title.isEmpty
                                ? 'Untitled audition'
                                : audition.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            director == null || director.isEmpty
                                ? 'Director profile coming soon'
                                : 'By $director',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _TypePill(type: audition.type),
                        if (audition.relationship != null) ...[
                          const SizedBox(height: 4),
                          _StatusPill(relationship: audition.relationship!),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TagChip(
                      icon: Icons.cake_outlined,
                      label: 'Age ${audition.ageLabel}',
                    ),
                    _TagChip(
                      icon: Icons.wc_outlined,
                      label: audition.gender,
                    ),
                    if (audition.ethnicity.toLowerCase() != 'any')
                      _TagChip(
                        icon: Icons.diversity_3_outlined,
                        label: audition.ethnicity,
                      ),
                    if (audition.bodyType.toLowerCase() != 'any')
                      _TagChip(
                        icon: Icons.accessibility_new_rounded,
                        label: audition.bodyType,
                      ),
                    if (audition.hasHeightRequirement)
                      _TagChip(
                        icon: Icons.height_rounded,
                        label: audition.heightLabel,
                      ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _relativeTimeLabel(audition.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onApply,
                      icon: Icon(
                        audition.isSubmitted
                            ? Icons.visibility_outlined
                            : Icons.send_rounded,
                        size: 18,
                      ),
                      label: Text(
                        audition.isSubmitted ? 'View' : 'Apply',
                      ),
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
    if (when == null) return 'Open audition';
    final now = DateTime.now().toUtc();
    final t = when.toUtc();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Posted just now';
    if (diff.inHours < 1) return 'Posted ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Posted ${diff.inHours}h ago';
    if (diff.inDays < 30) return 'Posted ${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return 'Posted ${months}mo ago';
    return 'Posted ${(diff.inDays / 365).floor()}y ago';
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.relationship});

  final AuditionRelationship relationship;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = relationship == AuditionRelationship.submitted;
    final color = isSubmitted
        ? ScenolyticsColors.success
        : ScenolyticsColors.info;
    final label = isSubmitted ? 'Submitted' : 'Invited';
    final icon = isSubmitted
        ? Icons.check_circle_outline_rounded
        : Icons.mark_email_unread_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
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
    required this.onResetFilters,
  });

  final bool hasFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasFilters ? Icons.filter_alt_off_outlined : Icons.theater_comedy_outlined,
          size: 44,
          color: cs.primary,
        ),
        const SizedBox(height: 10),
        Text(
          hasFilters ? 'No auditions match your filters' : 'No auditions yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasFilters
              ? 'Try widening your filters or clearing the search.'
              : 'New auditions appear here when a director invites you, or after '
                  'you submit one. Pull to refresh.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        if (hasFilters) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onResetFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset filters'),
          ),
        ],
      ],
    );
  }
}
