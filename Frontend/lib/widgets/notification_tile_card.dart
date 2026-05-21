import 'package:flutter/material.dart';

import '../data/models/app_notification.dart';
import '../theme/scenolytics_colors.dart';

String compactNotificationTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final dy = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final t =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$dy · $t';
}

String relativeNotificationTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt.toLocal());
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return compactNotificationTimestamp(dt);
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.icon,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final Color accent;
}

_NotificationVisual _visualFor(String rawType) {
  switch (rawType) {
    case 'Submission Notification':
      return const _NotificationVisual(
        icon: Icons.movie_filter_outlined,
        label: 'Submission',
        accent: ScenolyticsColors.accentCyan,
      );
    case 'Invitation Notification':
      return const _NotificationVisual(
        icon: Icons.celebration_outlined,
        label: 'Invitation',
        accent: ScenolyticsColors.tertiary,
      );
    default:
      return _NotificationVisual(
        icon: Icons.notifications_active_outlined,
        label: rawType.isEmpty ? 'Update' : rawType,
        accent: ScenolyticsColors.primary,
      );
  }
}

class AnimatedNotificationTile extends StatefulWidget {
  const AnimatedNotificationTile({
    super.key,
    required this.notification,
    required this.animationIndex,
    this.onTap,
    this.enableHoverLift = true,
  });

  final AppNotification notification;
  final int animationIndex;
  final VoidCallback? onTap;

  /// When false (e.g. header popover), skips [MouseRegion] hover rebuilds.
  final bool enableHoverLift;

  @override
  State<AnimatedNotificationTile> createState() =>
      _AnimatedNotificationTileState();
}

class _AnimatedNotificationTileState extends State<AnimatedNotificationTile>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final AnimationController _pulse;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: 380 + widget.animationIndex.clamp(0, 12) * 26),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _entry.forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final n = widget.notification;
    final read = n.isRead;
    final visual = _visualFor(n.notificationType);
    final stamp = relativeNotificationTimestamp(n.createdAt);

    final outline = ScenolyticsColors.outlineSoftFor(brightness)
        .withValues(alpha: read ? 0.45 : 0.7);
    final bg = read
        ? (brightness == Brightness.dark
            ? cs.surface
            : ScenolyticsColors.surfaceCard)
        : null;

    final tileBody = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      transform: widget.enableHoverLift
          ? (Matrix4.identity()
            ..translate(0.0, _hover ? -1.5 : 0.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: bg,
        gradient: read ? null : ScenolyticsColors.cardSheenFor(brightness),
        border: Border.all(
          color: widget.enableHoverLift && _hover
              ? visual.accent.withValues(alpha: 0.55)
              : outline,
          width: widget.enableHoverLift && _hover ? 1.2 : 1,
        ),
        boxShadow: [
          if (!read || (widget.enableHoverLift && _hover))
            BoxShadow(
              color: visual.accent.withValues(
                alpha: brightness == Brightness.dark ? 0.22 : 0.12,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: visual.accent.withValues(alpha: 0.10),
          highlightColor: visual.accent.withValues(alpha: 0.06),
          child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: read
                                ? [
                                    cs.outline.withValues(alpha: 0.25),
                                    cs.outline.withValues(alpha: 0.10),
                                  ]
                                : [
                                    visual.accent,
                                    ScenolyticsColors.heroGradientEnd,
                                  ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IconAvatar(
                            icon: visual.icon,
                            color: visual.accent,
                            faded: read,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title.isEmpty
                                            ? 'Notification'
                                            : n.title,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: read
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                          color: read
                                              ? cs.onSurface
                                                  .withValues(alpha: 0.75)
                                              : cs.onSurface,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    if (!read) ...[
                                      const SizedBox(width: 8),
                                      _UnreadDot(
                                        animation: _pulse,
                                        color: visual.accent,
                                      ),
                                    ],
                                  ],
                                ),
                                if (n.message.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    n.message,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                      color: read
                                          ? cs.onSurfaceVariant
                                              .withValues(alpha: 0.7)
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _TypePill(
                                      label: visual.label,
                                      color: visual.accent,
                                      faded: read,
                                    ),
                                    if (stamp.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          stamp,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: cs.onSurfaceVariant
                                                .withValues(
                                                    alpha:
                                                        read ? 0.55 : 0.85),
                                            letterSpacing: 0.2,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );

    final wrapped = widget.enableHoverLift
        ? MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: tileBody,
          )
        : tileBody;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _fade.drive(
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero),
        ),
        child: wrapped,
      ),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  const _IconAvatar({
    required this.icon,
    required this.color,
    required this.faded,
  });

  final IconData icon;
  final Color color;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final tint = faded ? color.withValues(alpha: 0.55) : color;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: faded ? 0.10 : 0.20),
            color.withValues(alpha: faded ? 0.05 : 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: faded ? 0.20 : 0.40),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: tint, size: 22),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = 0.55 + animation.value * 0.45;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45 * t),
                blurRadius: 9 + 5 * t,
                spreadRadius: 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.color,
    required this.faded,
  });

  final String label;
  final Color color;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final tint = faded ? color.withValues(alpha: 0.60) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: faded ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: faded ? 0.20 : 0.38),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontSize: 11,
        ),
      ),
    );
  }
}
