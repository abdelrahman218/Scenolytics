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
  final String auditionType;
  bool get isAudioOnly => auditionType.trim().toLowerCase() == 'audio';
  final String description;
  final String scriptPlainText;
  final int mySubmissionCountForAudition;
  final AuditionSubmissionStatus? myLatestSubmissionStatus;
  final bool hasSubmissionRecord;
}
