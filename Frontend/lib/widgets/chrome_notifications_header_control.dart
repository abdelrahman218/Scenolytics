import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/models/app_notification.dart';
import '../data/notification_feed_controller.dart';
import 'notification_tile_card.dart';

/// Anchored alerts panel triggered from the app header (intended for desktop Chrome builds).
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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
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
        final maxW =
            mq.size.width < 420 ? mq.size.width - 28 : 392.0;
        final shellH =
            mq.size.height * 0.52 > 460 ? 460.0 : mq.size.height * 0.52;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  unawaited(_hide());
                },
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 2 + _anim.value * 6,
                        sigmaY: 2 + _anim.value * 6,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.1 * _anim.value),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topRight,
              showWhenUnlinked: false,
              offset: Offset(-maxW + (widget.dense ? 42 : 40), 6),
              child: SlideTransition(
                position: _anim.drive(
                  Tween<Offset>(
                    begin: const Offset(0, -0.035),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: FadeTransition(
                  opacity: _anim,
                  child: Material(
                    elevation: 16,
                    color: Theme.of(overlayContext).colorScheme.surface,
                    shadowColor:
                        Theme.of(overlayContext).colorScheme.shadow.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Theme.of(overlayContext)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (_, __) => _AlertsPanelShell(
                        maxWidth: maxW,
                        shellHeight: shellH,
                        feed: widget.controller,
                        onDismiss: () {
                          _hide();
                        },
                        onOpenMissed: () {
                          _hide().then<void>((_) {
                            widget.onOpenFullListing();
                          });
                        },
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
      await _anim.reverse();
    } catch (_) {}
    entry.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: ListenableBuilder(
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
            child:
                Icon(Icons.notifications_none_rounded, size: widget.dense ? 22 : 24),
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
                padding:
                    EdgeInsets.symmetric(horizontal: widget.dense ? 2 : 6),
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
      ),
    );
  }
}

class _AlertsPanelShell extends StatelessWidget {
  const _AlertsPanelShell({
    required this.maxWidth,
    required this.shellHeight,
    required this.feed,
    required this.onDismiss,
    required this.onOpenMissed,
  });

  final double maxWidth;
  final double shellHeight;
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
              content: Text('Could not mark notification as read.')),
        );
      }
    }
    done();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slice = feed.notifications.take(52).toList();

    final headerRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${feed.unreadCount} unread • ${feed.notifications.length} total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onDismiss,
          ),
        ],
      ),
    );

    return SizedBox(
      width: maxWidth,
      height: shellHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerRow,
          const Divider(height: 1),
          Expanded(
            child: slice.isEmpty
                ? Center(
                    child: Text(
                      'When something lands, it will surface here instantly.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    itemCount: slice.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int i) {
                      final n = slice[i];
                      return AnimatedNotificationTile(
                        notification: n,
                        animationIndex: i,
                        onTap: () => _handleTap(
                          context,
                          n,
                          onDismiss,
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: TextButton.icon(
              icon: Icon(
                Icons.open_in_full_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              label: Text(
                'Open missed notifies',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.05,
                ),
              ),
              onPressed: onOpenMissed,
            ),
          ),
        ],
      ),
    );
  }
}
