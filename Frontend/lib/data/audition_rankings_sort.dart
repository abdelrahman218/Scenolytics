import '../models/actor_audition_submission.dart';

/// Sorts submissions by score and applies competition-style ranks for ties.
List<RankedAuditionSubmission> rankAuditionSubmissions(
  List<ActorAuditionSubmission> submissions,
) {
  final sorted = List<ActorAuditionSubmission>.from(submissions)
    ..sort((a, b) => b.score.compareTo(a.score));

  final ranked = <RankedAuditionSubmission>[];
  for (var i = 0; i < sorted.length; i++) {
    final rank = (i == 0 || sorted[i].score != sorted[i - 1].score)
        ? i + 1
        : ranked.last.rank;
    ranked.add(RankedAuditionSubmission(rank: rank, submission: sorted[i]));
  }
  return ranked;
}
