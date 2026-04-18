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
  });

  final String titleLine;
  final String themeLine;
  final String emotionsCsv;
  final String? directorDisplayName;

  /// Casting `auditions.description`.
  final String description;

  /// Lines built from casting `audition.script` (emotion + content) for download / display.
  final String scriptPlainText;

  /// Rows from `GET /api/v1/casting/actor/auditions/submissions` for this audition.
  final int mySubmissionCountForAudition;
}
