import 'package:flutter/material.dart';

/// Mirrors casting `audition_submissions.submission_status` ENUM.
enum AuditionSubmissionStatus {
  pending,
  underReview,
  accepted,
  rejected,
  unknown,
}

AuditionSubmissionStatus parseAuditionSubmissionStatus(Object? raw) {
  final s = raw?.toString().trim().toLowerCase() ?? '';
  switch (s) {
    case 'pending':
      return AuditionSubmissionStatus.pending;
    case 'under_review':
      return AuditionSubmissionStatus.underReview;
    case 'accepted':
      return AuditionSubmissionStatus.accepted;
    case 'rejected':
      return AuditionSubmissionStatus.rejected;
    default:
      return AuditionSubmissionStatus.unknown;
  }
}

/// Short labels for chips and hero banners.
String auditionSubmissionStatusLabel(AuditionSubmissionStatus s) {
  return switch (s) {
    AuditionSubmissionStatus.pending => 'Pending',
    AuditionSubmissionStatus.underReview => 'Under review',
    AuditionSubmissionStatus.accepted => 'Accepted',
    AuditionSubmissionStatus.rejected => 'Rejected',
    AuditionSubmissionStatus.unknown => 'Status unavailable',
  };
}

Color? auditionSubmissionStatusAccent(
  ColorScheme cs,
  AuditionSubmissionStatus s,
) {
  return switch (s) {
    AuditionSubmissionStatus.pending =>
      cs.tertiaryContainer.withValues(alpha: 0.95),
    AuditionSubmissionStatus.underReview =>
      cs.primaryContainer.withValues(alpha: 0.9),
    AuditionSubmissionStatus.accepted => cs.secondaryContainer,
    AuditionSubmissionStatus.rejected => cs.errorContainer,
    AuditionSubmissionStatus.unknown => cs.surfaceContainerHighest,
  };
}

Color auditionSubmissionStatusOnAccent(
  ColorScheme cs,
  AuditionSubmissionStatus s,
) {
  return switch (s) {
    AuditionSubmissionStatus.pending => cs.onTertiaryContainer,
    AuditionSubmissionStatus.underReview => cs.onPrimaryContainer,
    AuditionSubmissionStatus.accepted => cs.onSecondaryContainer,
    AuditionSubmissionStatus.rejected => cs.onErrorContainer,
    AuditionSubmissionStatus.unknown => cs.onSurfaceVariant,
  };
}
