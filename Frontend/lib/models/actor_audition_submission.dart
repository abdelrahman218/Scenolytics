/// One actor's submission for a specific audition role (from casting + profile APIs).
class ActorAuditionSubmission {
  const ActorAuditionSubmission({
    required this.id,
    required this.actorName,
    required this.auditionRole,
    required this.score,
    required this.submittedAt,
    required this.age,
    required this.emotionalScore,
    required this.vocalToneScore,
    required this.scriptMatchScore,
    required this.eyesAnalysisScore,
    required this.toneAnalysisScore,
    this.recordedVideoUrl,
  });

  final String id;
  final String actorName;
  final String auditionRole;
  final double score;
  final DateTime submittedAt;

  /// Breakdown scores (0–100) for audition analytics UI.
  /// [emotionalScore] = facial emotions; [vocalToneScore] = vocal emotion; [scriptMatchScore] = script match.
  /// [eyesAnalysisScore] / [toneAnalysisScore] = optional breakdown rows when the API supplies them.
  final int age;
  final int emotionalScore;
  final int vocalToneScore;
  final int scriptMatchScore;
  final int eyesAnalysisScore;
  final int toneAnalysisScore;

  /// HTTPS URL to the uploaded audition recording, when known (director playback).
  final String? recordedVideoUrl;
}

/// [rank] uses competition ranking: tied scores share the same rank (1, 2, 2, 4, …).
class RankedAuditionSubmission {
  const RankedAuditionSubmission({
    required this.rank,
    required this.submission,
  });

  final int rank;
  final ActorAuditionSubmission submission;
}
