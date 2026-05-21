import 'audition_listing.dart';
import 'audition_submission_status.dart';
import 'callback_status.dart';

/// One row on the actor dashboard: an audition the actor submitted to, plus
/// submission scores/status and optional callback details.
class ActorAuditionCard {
  const ActorAuditionCard({
    required this.audition,
    required this.submissionId,
    required this.submissionStatus,
    this.submittedAt,
    this.overallScore,
    this.callbackStatus,
    this.callbackDatetime,
    this.meetLink,
  });

  final AuditionListing audition;
  final String submissionId;
  final AuditionSubmissionStatus submissionStatus;
  final DateTime? submittedAt;
  final double? overallScore;
  final CallbackStatus? callbackStatus;
  final DateTime? callbackDatetime;
  final String? meetLink;

  String get auditionId => audition.id;
  String get title => audition.title;
  String get type => audition.type;
  String? get directorDisplayName => audition.directorDisplayName;

  bool get hasCallback =>
      callbackStatus != null && callbackStatus != CallbackStatus.unknown;
}
