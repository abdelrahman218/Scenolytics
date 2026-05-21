import 'audition_listing.dart';
import 'callback_status.dart';

class DirectorAuditionCard {
  const DirectorAuditionCard({
    required this.audition,
    required this.submissionsCount,
    required this.pendingInvitationsCount,
    CallbackStatusCounts? callbackStatusCounts,
    this.topSubmissionScore,
  }) : callbackStatusCounts =
            callbackStatusCounts ?? const CallbackStatusCounts();

  int get callbacksCount => callbackStatusCounts.total;

  final AuditionListing audition;

  /// `GET /api/v1/casting/director/auditions/:id/submissions`.
  final int submissionsCount;

  /// `GET /api/v1/casting/director/auditions/:id/invitations/pending`.
  final int pendingInvitationsCount;

  /// `GET /api/v1/casting/director/auditions/:id/callbacks`.
  final CallbackStatusCounts callbackStatusCounts;

  final double? topSubmissionScore;
  String get id => audition.id;
  String get title => audition.title;
  String get type => audition.type;

  int get totalActivity =>
      submissionsCount + pendingInvitationsCount + callbackStatusCounts.total;
}
