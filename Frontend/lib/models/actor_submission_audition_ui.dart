import 'audition_submission_status.dart';

/// Audition hero copy for the actor submission page (from casting + director profile).
class ActorSubmissionAuditionUi {
  const ActorSubmissionAuditionUi({
    required this.titleLine,
    required this.themeLine,
    required this.emotionsCsv,
    this.directorDisplayName,
    this.description = '',
    this.scriptPlainText = '',
    this.mySubmissionCountForAudition = 0,
    this.myLatestSubmissionStatus,
    this.hasSubmissionRecord = false,
    this.auditionType = '',
  });

  final String titleLine;
  final String themeLine;
  final String emotionsCsv;
  final String? directorDisplayName;

  /// 'Audio' or 'Video' — mirrors the backend `auditions.type` ENUM. Used by
  /// the submission page to decide whether to record video or audio only.
  final String auditionType;

  bool get isAudioOnly => auditionType.trim().toLowerCase() == 'audio';

  /// Casting `auditions.description`.
  final String description;

  /// Lines built from casting `audition.script` (emotion + content) for download / display.
  final String scriptPlainText;

  /// Rows from `GET /api/v1/casting/actor/auditions/submissions` for this audition.
  final int mySubmissionCountForAudition;

  /// Newest submission row’s status for this audition (from casting API), if any.
  final AuditionSubmissionStatus? myLatestSubmissionStatus;

  /// True when at least one submission row exists for this audition id.
  final bool hasSubmissionRecord;
}
