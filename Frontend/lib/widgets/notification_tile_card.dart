import 'package:flutter/material.dart';

import '../data/models/app_notification.dart';

String compactNotificationTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final dy = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final t =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$dy · $t';
}

class AnimatedNotificationTile extends StatefulWidget {
  const AnimatedNotificationTile({
    super.key,
    required this.notification,
    required this.animationIndex,
    this.onTap,
  });

  final AppNotification notification;
  final int animationIndex;
  final VoidCallback? onTap;

  @override
  State<AnimatedNotificationTile> createState() =>
      _AnimatedNotificationTileState();
}

class _AnimatedNotificationTileState extends State<AnimatedNotificationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: 360 + widget.animationIndex.clamp(0, 12) * 28),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = widget.notification;

    final read = n.isRead;
    final stamp = compactNotificationTimestamp(n.createdAt);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _fade.drive(Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color:
                    read ? cs.outline.withValues(alpha: 0.35) : cs.primary,
                width: 4,
              ),
            ),
            color: read
                ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                : cs.surfaceContainerHighest.withValues(alpha: 0.65),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!read)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8,
                                    spreadRadius: 0.5,
                                    color: cs.primary.withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            n.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  read ? FontWeight.w500 : FontWeight.w700,
                              color: read
                                  ? cs.onSurface.withValues(alpha: 0.75)
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (stamp.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        stamp,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              cs.onSurfaceVariant.withValues(alpha: read ? 0.5 : 0.75),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      n.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: read
                            ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _typeLabel(n.notificationType),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary.withValues(alpha: read ? 0.55 : 0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _typeLabel(String raw) {
    switch (raw) {
      case 'Submission Notification':
        return 'Submission';
      case 'Invitation Notification':
        return 'Invitation';
      default:
        return raw.isEmpty ? 'Update' : raw;
    }
  }
}
