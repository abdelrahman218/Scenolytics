import 'audition_listing.dart';

/// Composite row for the director dashboard: a single audition plus the
/// derived counts (submissions, pending invites, callbacks) and an optional
/// best-in-class overall score across submissions. Built by
/// `AuditionsRepository.loadDirectorDashboard` so the page can render rich
/// cards without touching the API itself.
class DirectorAuditionCard {
  const DirectorAuditionCard({
    required this.audition,
    required this.submissionsCount,
    required this.pendingInvitationsCount,
    required this.callbacksCount,
    this.topSubmissionScore,
  });

  final AuditionListing audition;

  /// Number of rows returned by
  /// `GET /api/v1/casting/director/auditions/:id/submissions`.
  final int submissionsCount;

  /// Number of pending invitations from
  /// `GET /api/v1/casting/director/auditions/:id/invitations/pending`.
  final int pendingInvitationsCount;

  /// Number of callbacks from
  /// `GET /api/v1/casting/director/auditions/:id/callbacks`.
  final int callbacksCount;

  /// Best `overall_performance_score` (0–100) seen across submissions, or
  /// null if there are no submissions / no score field on any row.
  final double? topSubmissionScore;

  /// Convenience pass-throughs to the wrapped audition so call sites don't
  /// reach through `card.audition.id` for the common cases.
  String get id => audition.id;
  String get title => audition.title;
  String get type => audition.type;

  /// Total of all three counts — handy for "X total interactions" summaries.
  int get totalActivity =>
      submissionsCount + pendingInvitationsCount + callbacksCount;
}
