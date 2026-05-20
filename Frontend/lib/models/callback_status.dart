import 'package:flutter/material.dart';

/// Mirrors casting `callbacks.callback_status` ENUM.
enum CallbackStatus {
  scheduled,
  accepted,
  rejected,
  unknown,
}

CallbackStatus parseCallbackStatus(Object? raw) {
  switch (raw?.toString().trim().toLowerCase()) {
    case 'scheduled':
      return CallbackStatus.scheduled;
    case 'accepted':
      return CallbackStatus.accepted;
    case 'rejected':
      return CallbackStatus.rejected;
    default:
      return CallbackStatus.unknown;
  }
}

String callbackStatusLabel(CallbackStatus s) {
  return switch (s) {
    CallbackStatus.scheduled => 'Scheduled',
    CallbackStatus.accepted => 'Accepted',
    CallbackStatus.rejected => 'Rejected',
    CallbackStatus.unknown => 'Unknown',
  };
}

Color? callbackStatusAccent(ColorScheme cs, CallbackStatus s) {
  return switch (s) {
    CallbackStatus.scheduled => cs.primaryContainer.withValues(alpha: 0.95),
    CallbackStatus.accepted => cs.secondaryContainer,
    CallbackStatus.rejected => cs.errorContainer,
    CallbackStatus.unknown => cs.surfaceContainerHighest,
  };
}

Color callbackStatusOnAccent(ColorScheme cs, CallbackStatus s) {
  return switch (s) {
    CallbackStatus.scheduled => cs.onPrimaryContainer,
    CallbackStatus.accepted => cs.onSecondaryContainer,
    CallbackStatus.rejected => cs.onErrorContainer,
    CallbackStatus.unknown => cs.onSurfaceVariant,
  };
}

/// Aggregated callback rows for dashboard cards and hero metrics.
class CallbackStatusCounts {
  const CallbackStatusCounts({
    this.scheduled = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.unknown = 0,
  });

  final int scheduled;
  final int accepted;
  final int rejected;
  final int unknown;

  int get total => scheduled + accepted + rejected + unknown;

  static CallbackStatusCounts fromCallbackRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    var scheduled = 0;
    var accepted = 0;
    var rejected = 0;
    var unknown = 0;
    for (final row in rows) {
      switch (parseCallbackStatus(row['callback_status'])) {
        case CallbackStatus.scheduled:
          scheduled++;
        case CallbackStatus.accepted:
          accepted++;
        case CallbackStatus.rejected:
          rejected++;
        case CallbackStatus.unknown:
          unknown++;
      }
    }
    return CallbackStatusCounts(
      scheduled: scheduled,
      accepted: accepted,
      rejected: rejected,
      unknown: unknown,
    );
  }

  CallbackStatusCounts operator +(CallbackStatusCounts other) {
    return CallbackStatusCounts(
      scheduled: scheduled + other.scheduled,
      accepted: accepted + other.accepted,
      rejected: rejected + other.rejected,
      unknown: unknown + other.unknown,
    );
  }
}
