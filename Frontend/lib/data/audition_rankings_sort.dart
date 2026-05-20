import '../models/actor_audition_submission.dart';

/// How director rankings sort / assign competition ranks.
enum AuditionRankingsSortBy {
  overall,
  facialEmotion,
  vocalEmotion,
  scriptMatch,
}

extension AuditionRankingsSortByUi on AuditionRankingsSortBy {
  /// Short label for the rank-by dropdown.
  String get menuLabel => switch (this) {
        AuditionRankingsSortBy.overall => 'Overall',
        AuditionRankingsSortBy.facialEmotion => 'Facial emotion',
        AuditionRankingsSortBy.vocalEmotion => 'Vocal emotion',
        AuditionRankingsSortBy.scriptMatch => 'Script match',
      };

  String get statsAverageLabel => switch (this) {
        AuditionRankingsSortBy.overall => 'Average score',
        AuditionRankingsSortBy.facialEmotion => 'Avg facial emotion',
        AuditionRankingsSortBy.vocalEmotion => 'Avg vocal emotion',
        AuditionRankingsSortBy.scriptMatch => 'Avg script match',
      };

  String get statsTopLabel => switch (this) {
        AuditionRankingsSortBy.overall => 'Top score',
        AuditionRankingsSortBy.facialEmotion => 'Top facial emotion',
        AuditionRankingsSortBy.vocalEmotion => 'Top vocal emotion',
        AuditionRankingsSortBy.scriptMatch => 'Top script match',
      };
}

/// Numeric key used to sort submissions (higher is better).
double auditionRankingSortMetric(
  ActorAuditionSubmission s,
  AuditionRankingsSortBy sortBy,
) =>
    switch (sortBy) {
      AuditionRankingsSortBy.overall => s.score,
      AuditionRankingsSortBy.facialEmotion => s.emotionalScore.toDouble(),
      AuditionRankingsSortBy.vocalEmotion => s.vocalToneScore.toDouble(),
      AuditionRankingsSortBy.scriptMatch => s.scriptMatchScore.toDouble(),
    };

/// Sorts submissions by [sortBy] and applies competition-style ranks for ties.
List<RankedAuditionSubmission> rankAuditionSubmissions(
  List<ActorAuditionSubmission> submissions, {
  AuditionRankingsSortBy sortBy = AuditionRankingsSortBy.overall,
}) {
  double key(ActorAuditionSubmission s) =>
      auditionRankingSortMetric(s, sortBy);

  final sorted = List<ActorAuditionSubmission>.from(submissions)
    ..sort((a, b) => key(b).compareTo(key(a)));

  final ranked = <RankedAuditionSubmission>[];
  for (var i = 0; i < sorted.length; i++) {
    final k = key(sorted[i]);
    final prevK = i > 0 ? key(sorted[i - 1]) : null;
    final rank = (i == 0 || k != prevK) ? i + 1 : ranked.last.rank;
    ranked.add(RankedAuditionSubmission(rank: rank, submission: sorted[i]));
  }
  return ranked;
}
