import 'package:flutter/material.dart';

import '../models/callback_status.dart';

/// Compact pill for one `callback_status` value (optionally with a count).
class CallbackStatusChip extends StatelessWidget {
  const CallbackStatusChip({
    super.key,
    required this.status,
    this.count,
    this.dense = false,
  });

  final CallbackStatus status;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (status == CallbackStatus.unknown) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final bg = callbackStatusAccent(cs, status);
    final fg = callbackStatusOnAccent(cs, status);
    final label = count != null
        ? '${callbackStatusLabel(status)} $count'
        : callbackStatusLabel(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 10 : 11,
            ),
      ),
    );
  }
}

/// Scheduled / accepted / rejected chips for dashboard cards and hero areas.
class CallbackStatusBreakdownRow extends StatelessWidget {
  const CallbackStatusBreakdownRow({
    super.key,
    required this.counts,
    this.dense = false,
    this.spacing = 4,
    this.runSpacing = 4,
  });

  final CallbackStatusCounts counts;
  final bool dense;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        CallbackStatusChip(
          status: CallbackStatus.scheduled,
          count: counts.scheduled,
          dense: dense,
        ),
        CallbackStatusChip(
          status: CallbackStatus.accepted,
          count: counts.accepted,
          dense: dense,
        ),
        CallbackStatusChip(
          status: CallbackStatus.rejected,
          count: counts.rejected,
          dense: dense,
        ),
      ],
    );
  }
}
