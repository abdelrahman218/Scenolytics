import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/models/app_notification.dart';
import '../data/notification_feed_controller.dart';
import '../theme/scenolytics_colors.dart';
import 'notification_tile_card.dart';

/// Centered notifications panel (desktop / web header bell).
class ChromeNotificationsHeaderControl extends StatefulWidget {
  const ChromeNotificationsHeaderControl({
    super.key,
    required this.controller,
    required this.onOpenFullListing,
    this.dense = false,
  });

  final NotificationFeedController controller;
  final VoidCallback onOpenFullListing;
  final bool dense;

  @override
  State<ChromeNotificationsHeaderControl> createState() =>
      _ChromeNotificationsHeaderControlState();
}

class _ChromeNotificationsHeaderControlState
    extends State<ChromeNotificationsHeaderControl>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    widget.controller.addListener(_markOverlayDirty);
  }

  void _markOverlayDirty() {
    _overlay?.markNeedsBuild();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_markOverlayDirty);
    _overlay?.remove();
    _overlay = null;
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_overlay != null) {
      await _hide();
    } else {
      await _show();
    }
  }

  Future<void> _show() async {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    await _hide();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        final mq = MediaQuery.of(overlayContext);
        final panelW = (mq.size.width * 0.92).clamp(320.0, 440.0);
        final panelH = (mq.size.height * 0.72).clamp(380.0, 560.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_hide()),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 2 + _anim.value * 8,
                        sigmaY: 2 + _anim.value * 8,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.22 * _anim.value),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      elevation: 20,
                      color: Theme.of(overlayContext).colorScheme.surface,
                      shadowColor: Theme.of(overlayContext)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: Theme.of(overlayContext)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: panelW,
                        height: panelH,
                        child: _AlertsPanelShell(
                          feed: widget.controller,
                          onDismiss: () => unawaited(_hide()),
                          onOpenMissed: () {
                            unawaited(_hide().then<void>((_) {
                              widget.onOpenFullListing();
                            }));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(entry);
    _overlay = entry;
    await _anim.forward(from: 0);
  }

  Future<void> _hide() async {
    final entry = _overlay;
    if (entry == null) return;
    try {
      if (_anim.status != AnimationStatus.dismissed) {
        await _anim.reverse();
      }
    } catch (_) {}
    entry.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (_, __) {
        final unread = widget.controller.unreadCount;
        final badge = Badge(
          isLabelVisible: unread > 0,
          padding: unread > 99
              ? const EdgeInsetsDirectional.only(start: 4, end: 8)
              : const EdgeInsets.symmetric(horizontal: 9),
          label: Text(
            unread > 99 ? '99+' : '$unread',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: widget.dense ? 22 : 24,
          ),
        );

        return Tooltip(
          message: unread > 0
              ? '$unread unread notifications'
              : 'Notifications',
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: unread > 0 ? 1.04 : 1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dense ? 2 : 6),
              child: IconButton(
                splashRadius: 21,
                onPressed: _toggle,
                icon: badge,
                color: cs.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlertsPanelShell extends StatelessWidget {
  const _AlertsPanelShell({
    required this.feed,
    required this.onDismiss,
    required this.onOpenMissed,
  });

  final NotificationFeedController feed;
  final VoidCallback onDismiss;
  final VoidCallback onOpenMissed;

  Future<void> _handleTap(
    BuildContext context,
    AppNotification n,
    VoidCallback done,
  ) async {
    if (!n.isRead) {
      try {
        await feed.openAndMarkRead(n);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark notification as read.'),
          ),
        );
      }
    }
    done();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    const onHero = ScenolyticsColors.onPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: ScenolyticsColors.heroBarGradientFor(brightness),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onHero.withValues(alpha: 0.18),
                  border: Border.all(color: onHero.withValues(alpha: 0.36)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: onHero,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: onHero,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: feed,
                      builder: (_, __) => Text(
                        '${feed.unreadCount} unread · ${feed.notifications.length} total',
                        style: TextStyle(
                          color: onHero.withValues(alpha: 0.86),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _PanelCloseButton(onPressed: onDismiss),
            ],
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? cs.surface
                  : ScenolyticsColors.pageBackground.withValues(alpha: 0.6),
            ),
            child: ListenableBuilder(
              listenable: feed,
              builder: (_, __) {
                final slice = feed.notifications.take(52).toList();
                if (slice.isEmpty) {
                  return _PopoverEmptyState(theme: theme);
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: slice.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int i) {
                    final n = slice[i];
                    return AnimatedNotificationTile(
                      notification: n,
                      animationIndex: i,
                      enableHoverLift: false,
                      onTap: () => _handleTap(context, n, onDismiss),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(
                color: ScenolyticsColors.outlineSoftFor(brightness)
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: TextButton.icon(
            icon: Icon(
              Icons.open_in_full_rounded,
              color: cs.primary,
              size: 18,
            ),
            label: Text(
              'Open missed notifies',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.primary,
                letterSpacing: 0.05,
              ),
            ),
            onPressed: onOpenMissed,
          ),
        ),
      ],
    );
  }
}

/// Close control without [Tooltip] (avoids nested-overlay hover glitches on web).
class _PanelCloseButton extends StatelessWidget {
  const _PanelCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const onHero = ScenolyticsColors.onPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        hoverColor: onHero.withValues(alpha: 0.14),
        splashColor: onHero.withValues(alpha: 0.20),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.close_rounded,
            color: onHero,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PopoverEmptyState extends StatelessWidget {
  const _PopoverEmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ScenolyticsColors.cardSheenFor(theme.brightness),
                border: Border.all(
                  color: ScenolyticsColors.outlineSoftFor(theme.brightness)
                      .withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                color: cs.onSurfaceVariant,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'When something lands, it will surface here instantly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
