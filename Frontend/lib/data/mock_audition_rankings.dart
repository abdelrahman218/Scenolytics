import '../models/actor_audition_submission.dart';

/// Template submissions (unsorted). Scores and names are placeholders.
final List<ActorAuditionSubmission> kMockAuditionSubmissions = [
  ActorAuditionSubmission(
    id: 'sub_01',
    actorName: 'Maya Chen',
    auditionRole: 'Lead — Dr. Aris',
    score: 94.2,
    submittedAt: DateTime.utc(2026, 4, 2, 14, 30),
  ),
  ActorAuditionSubmission(
    id: 'sub_02',
    actorName: 'Jordan Okonkwo',
    auditionRole: 'Lead — Dr. Aris',
    score: 91.0,
    submittedAt: DateTime.utc(2026, 4, 1, 9, 15),
  ),
  ActorAuditionSubmission(
    id: 'sub_03',
    actorName: 'Elena Vasquez',
    auditionRole: 'Supporting — Riva',
    score: 88.5,
    submittedAt: DateTime.utc(2026, 4, 3, 18, 45),
  ),
  ActorAuditionSubmission(
    id: 'sub_04',
    actorName: 'Samir Haddad',
    auditionRole: 'Lead — Dr. Aris',
    score: 88.5,
    submittedAt: DateTime.utc(2026, 4, 2, 11, 0),
  ),
  ActorAuditionSubmission(
    id: 'sub_05',
    actorName: 'Priya Nair',
    auditionRole: 'Supporting — Riva',
    score: 86.0,
    submittedAt: DateTime.utc(2026, 4, 1, 16, 20),
  ),
  ActorAuditionSubmission(
    id: 'sub_06',
    actorName: 'Leo Martens',
    auditionRole: 'Lead — Dr. Aris',
    score: 82.3,
    submittedAt: DateTime.utc(2026, 3, 30, 10, 5),
  ),
  ActorAuditionSubmission(
    id: 'sub_07',
    actorName: 'Noah Brooks',
    auditionRole: 'Supporting — Riva',
    score: 79.8,
    submittedAt: DateTime.utc(2026, 4, 4, 8, 50),
  ),
  ActorAuditionSubmission(
    id: 'sub_08',
    actorName: 'Aisha Rahman',
    auditionRole: 'Lead — Dr. Aris',
    score: 76.4,
    submittedAt: DateTime.utc(2026, 4, 2, 20, 10),
  ),
  ActorAuditionSubmission(
    id: 'sub_09',
    actorName: 'Chris Dalton',
    auditionRole: 'Supporting — Riva',
    score: 71.2,
    submittedAt: DateTime.utc(2026, 3, 29, 13, 40),
  ),
];

/// Returns submissions sorted by [ActorAuditionSubmission.score] descending,
/// with competition-style ranks for ties.
List<RankedAuditionSubmission> mockRankedAuditionSubmissions() {
  final sorted = List<ActorAuditionSubmission>.from(kMockAuditionSubmissions)
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
