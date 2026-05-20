import 'audition_submission_status.dart';

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
    this.mediaId,
    this.submissionStatus = AuditionSubmissionStatus.pending,
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

  /// Casting tape UUID — `uploads/{media_id}.mp4` (used when probing playback URLs).
  final String? mediaId;

  /// HTTPS URL to the uploaded audition recording, when known (director playback).
  final String? recordedVideoUrl;

  /// Casting `submission_status` (`pending`, `under_review`, `accepted`, `rejected`).
  final AuditionSubmissionStatus submissionStatus;

  ActorAuditionSubmission copyWith({
    String? id,
    String? actorName,
    String? auditionRole,
    double? score,
    DateTime? submittedAt,
    int? age,
    int? emotionalScore,
    int? vocalToneScore,
    int? scriptMatchScore,
    int? eyesAnalysisScore,
    int? toneAnalysisScore,
    String? recordedVideoUrl,
    String? mediaId,
    AuditionSubmissionStatus? submissionStatus,
  }) {
    return ActorAuditionSubmission(
      id: id ?? this.id,
      actorName: actorName ?? this.actorName,
      auditionRole: auditionRole ?? this.auditionRole,
      score: score ?? this.score,
      submittedAt: submittedAt ?? this.submittedAt,
      age: age ?? this.age,
      emotionalScore: emotionalScore ?? this.emotionalScore,
      vocalToneScore: vocalToneScore ?? this.vocalToneScore,
      scriptMatchScore: scriptMatchScore ?? this.scriptMatchScore,
      eyesAnalysisScore: eyesAnalysisScore ?? this.eyesAnalysisScore,
      toneAnalysisScore: toneAnalysisScore ?? this.toneAnalysisScore,
      recordedVideoUrl: recordedVideoUrl ?? this.recordedVideoUrl,
      mediaId: mediaId ?? this.mediaId,
      submissionStatus: submissionStatus ?? this.submissionStatus,
    );
  }
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
