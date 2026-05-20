import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/app_notification.dart';
import '../data/notification_feed_controller.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/notification_tile_card.dart';

enum _NotifyFilter { all, unread, submissions, invitations }

extension _NotifyFilterX on _NotifyFilter {
  String get label => switch (this) {
        _NotifyFilter.all => 'All',
        _NotifyFilter.unread => 'Unread',
        _NotifyFilter.submissions => 'Submissions',
        _NotifyFilter.invitations => 'Invitations',
      };

  IconData get icon => switch (this) {
        _NotifyFilter.all => Icons.inbox_outlined,
        _NotifyFilter.unread => Icons.mark_email_unread_outlined,
        _NotifyFilter.submissions => Icons.movie_filter_outlined,
        _NotifyFilter.invitations => Icons.celebration_outlined,
      };
}

/// Full-page history for anything you might have missed.
class MissedNotificationsPage extends StatefulWidget {
  const MissedNotificationsPage({
    super.key,
    required this.feed,
    this.embeddedInShell = false,
  });

  final NotificationFeedController feed;
  final bool embeddedInShell;

  @override
  State<MissedNotificationsPage> createState() =>
      _MissedNotificationsPageState();
}

class _MissedNotificationsPageState extends State<MissedNotificationsPage> {
  static const double _maxContentWidth = 820;

  _NotifyFilter _filter = _NotifyFilter.all;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    widget.feed.addListener(_onFeed);
    unawaited(widget.feed.refreshAllQuiet());
  }

  @override
  void dispose() {
    widget.feed.removeListener(_onFeed);
    super.dispose();
  }

  void _onFeed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.feed.refreshAllQuiet();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<AppNotification> _applyFilter(List<AppNotification> all) {
    switch (_filter) {
      case _NotifyFilter.all:
        return all;
      case _NotifyFilter.unread:
        return all.where((n) => !n.isRead).toList();
      case _NotifyFilter.submissions:
        return all
            .where((n) => n.notificationType == 'Submission Notification')
            .toList();
      case _NotifyFilter.invitations:
        return all
            .where((n) => n.notificationType == 'Invitation Notification')
            .toList();
    }
  }

  Future<void> _markAllAsRead() async {
    final unread =
        widget.feed.notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    int failures = 0;
    for (final n in unread) {
      try {
        await widget.feed.openAndMarkRead(n);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? 'Marked ${unread.length} as read.'
              : 'Marked ${unread.length - failures} as read · $failures failed.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final body = ListenableBuilder(
      listenable: widget.feed,
      builder: (_, __) {
        final all = widget.feed.notifications;
        final filtered = _applyFilter(all);

        return RefreshIndicator(
          onRefresh: _refresh,
          displacement: widget.embeddedInShell ? 80 : 40,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroBanner(
                  total: all.length,
                  unread: all.where((n) => !n.isRead).length,
                  refreshing: _refreshing,
                  onMarkAll: all.any((n) => !n.isRead) ? _markAllAsRead : null,
                ),
              ),
              SliverToBoxAdapter(
                child: _FilterBar(
                  selected: _filter,
                  counts: <_NotifyFilter, int>{
                    _NotifyFilter.all: all.length,
                    _NotifyFilter.unread:
                        all.where((n) => !n.isRead).length,
                    _NotifyFilter.submissions: all
                        .where((n) =>
                            n.notificationType == 'Submission Notification')
                        .length,
                    _NotifyFilter.invitations: all
                        .where((n) =>
                            n.notificationType == 'Invitation Notification')
                        .length,
                  },
                  onSelect: (f) => setState(() => _filter = f),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(filter: _filter),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext ctx, int index) {
                      final n = filtered[index];
                      return AnimatedNotificationTile(
                        animationIndex: index,
                        notification: n,
                        onTap: () async {
                          try {
                            await widget.feed.openAndMarkRead(n);
                          } catch (_) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not update notification.',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.pageBackdropGradientFor(brightness),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: body,
        ),
      ),
    );

    if (widget.embeddedInShell) {
      return framed;
    }

    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? ScenolyticsColors.darkPageBackground
          : ScenolyticsColors.pageBackground,
      appBar: AppBar(
        title: const Text('Missed notifies'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: cs.shadow.withValues(alpha: 0.12),
      ),
      body: framed,
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.total,
    required this.unread,
    required this.refreshing,
    required this.onMarkAll,
  });

  final int total;
  final int unread;
  final bool refreshing;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    const onHero = ScenolyticsColors.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.heroBarGradientFor(b),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: onHero.withValues(alpha: ScenolyticsColors.heroBorderAlpha(b)),
          ),
          boxShadow: [
            BoxShadow(
              color: ScenolyticsColors.heroGradientStart.withValues(
                alpha: ScenolyticsColors.heroGlowShadowAlpha(b),
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onHero.withValues(alpha: 0.18),
                border: Border.all(
                  color: onHero.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_active_outlined,
                color: onHero,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missed notifies',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unread > 0
                        ? '$unread unread of $total total'
                        : total > 0
                            ? 'All caught up · $total in history'
                            : 'You are all caught up',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onHero.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onMarkAll != null)
                        _HeroAction(
                          icon: Icons.done_all_rounded,
                          label: 'Mark all read',
                          onTap: onMarkAll!,
                        ),
                      if (refreshing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: onHero.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: onHero.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: onHero,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Syncing…',
                                style: TextStyle(
                                  color: onHero,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const onHero = ScenolyticsColors.onPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: onHero.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: onHero.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onHero),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: onHero,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final _NotifyFilter selected;
  final Map<_NotifyFilter, int> counts;
  final ValueChanged<_NotifyFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final f in _NotifyFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  filter: f,
                  count: counts[f] ?? 0,
                  active: f == selected,
                  onTap: () => onSelect(f),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final _NotifyFilter filter;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [
                      ScenolyticsColors.primary,
                      ScenolyticsColors.accentCyan,
                    ],
                  )
                : null,
            color: active
                ? null
                : (brightness == Brightness.dark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
                    : ScenolyticsColors.surfaceMuted.withValues(alpha: 0.65)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : ScenolyticsColors.outlineSoftFor(brightness)
                      .withValues(alpha: 0.6),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ScenolyticsColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 15,
                color: active ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                filter.label,
                style: TextStyle(
                  color: active ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.22)
                        : cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: active ? Colors.white : cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final _NotifyFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;

    final (String title, String body, IconData icon) = switch (filter) {
      _NotifyFilter.all => (
          'No notifications yet',
          'When auditions, submissions, or invitations arrive, they will show up here instantly.',
          Icons.notifications_off_outlined,
        ),
      _NotifyFilter.unread => (
          'All caught up',
          'You have read every notification. Nice work staying on top of things.',
          Icons.task_alt_rounded,
        ),
      _NotifyFilter.submissions => (
          'No submission updates',
          'Submission progress and director feedback will surface here.',
          Icons.movie_filter_outlined,
        ),
      _NotifyFilter.invitations => (
          'No invitations yet',
          'Casting prompts will land here the moment a director invites you.',
          Icons.celebration_outlined,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: ScenolyticsColors.cardSheenFor(brightness),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ScenolyticsColors.outlineSoftFor(brightness)
                      .withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: ScenolyticsColors.primary.withValues(alpha: 0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
