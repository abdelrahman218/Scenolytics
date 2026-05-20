import 'dart:async';

import 'package:flutter/material.dart';

import '../data/notification_feed_controller.dart';
import '../widgets/notification_tile_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final listBody = ListenableBuilder(
      listenable: widget.feed,
      builder: (_, __) {
        if (widget.feed.notifications.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 44,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet.',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We continuously sync.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final count = widget.feed.notifications.length;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (BuildContext ctx, int index) {
            final n = widget.feed.notifications[index];
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
                      content: Text('Could not update notification.'),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );

    final bodyContent = RefreshIndicator(
      displacement: widget.embeddedInShell ? 64 : 32,
      onRefresh: widget.feed.refreshAllQuiet,
      child: listBody,
    );

    if (!widget.embeddedInShell) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Missed notifies'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.12),
        ),
        backgroundColor: theme.colorScheme.surface,
        body: bodyContent,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Missed notifies',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What arrived while you were away.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}
