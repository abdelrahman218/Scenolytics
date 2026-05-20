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

  /// One callback per submission — reschedules and link regeneration must not
  /// inflate the dashboard total (API may return duplicate rows historically).
  static CallbackStatusCounts fromCallbackRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final latestBySubmission = <String, Map<String, dynamic>>{};
    final orphans = <Map<String, dynamic>>[];

    for (final row in rows) {
      final submissionId = row['audition_submission_id']?.toString().trim() ?? '';
      if (submissionId.isEmpty) {
        orphans.add(row);
        continue;
      }
      final existing = latestBySubmission[submissionId];
      if (existing == null || _callbackRowIsNewer(row, existing)) {
        latestBySubmission[submissionId] = row;
      }
    }

    var scheduled = 0;
    var accepted = 0;
    var rejected = 0;
    var unknown = 0;

    void tally(Map<String, dynamic> row) {
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

    for (final row in latestBySubmission.values) {
      tally(row);
    }
    for (final row in orphans) {
      tally(row);
    }

    return CallbackStatusCounts(
      scheduled: scheduled,
      accepted: accepted,
      rejected: rejected,
      unknown: unknown,
    );
  }

  static bool _callbackRowIsNewer(
    Map<String, dynamic> row,
    Map<String, dynamic> existing,
  ) {
    final a = _parseCallbackCreatedAt(row['created_at']);
    final b = _parseCallbackCreatedAt(existing['created_at']);
    if (a != null && b != null) return a.isAfter(b);
    final aId = row['id']?.toString();
    final bId = existing['id']?.toString();
    if (aId != null && bId != null) {
      final ai = int.tryParse(aId);
      final bi = int.tryParse(bId);
      if (ai != null && bi != null) return ai > bi;
    }
    return false;
  }

  static DateTime? _parseCallbackCreatedAt(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
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
