import '../models/actor_audition_submission.dart';

/// Display name for the mock audition (replace with API later).
const String kMockAuditionTitle = 'The Horizon';

/// Round label shown on the rankings header (replace with API later).
const String kMockAuditionRound = 'Callback round';

/// Matches submissions with [ActorAuditionSubmission.receivedCallback] in mock data.
int mockCallbacksSentCount([List<ActorAuditionSubmission>? submissions]) =>
    (submissions ?? kMockAuditionSubmissions)
        .where((s) => s.receivedCallback)
        .length;

/// Template submissions (unsorted). Scores and names are placeholders.
final List<ActorAuditionSubmission> kMockAuditionSubmissions = [
  ActorAuditionSubmission(
    id: 'sub_01',
    actorName: 'Maya Chen',
    auditionRole: 'Lead — Dr. Aris',
    score: 94.2,
    submittedAt: DateTime.utc(2026, 4, 2, 14, 30),
    receivedCallback: true,
    age: 28,
    emotionalScore: 96,
    vocalToneScore: 92,
    bodyLanguageScore: 93,
    scriptMatchScore: 94,
  ),
  ActorAuditionSubmission(
    id: 'sub_02',
    actorName: 'Jordan Okonkwo',
    auditionRole: 'Lead — Dr. Aris',
    score: 91.0,
    submittedAt: DateTime.utc(2026, 4, 1, 9, 15),
    receivedCallback: true,
    age: 32,
    emotionalScore: 90,
    vocalToneScore: 91,
    bodyLanguageScore: 89,
    scriptMatchScore: 92,
  ),
  ActorAuditionSubmission(
    id: 'sub_03',
    actorName: 'Elena Vasquez',
    auditionRole: 'Supporting — Riva',
    score: 88.5,
    submittedAt: DateTime.utc(2026, 4, 3, 18, 45),
    receivedCallback: true,
    age: 26,
    emotionalScore: 89,
    vocalToneScore: 88,
    bodyLanguageScore: 90,
    scriptMatchScore: 87,
  ),
  ActorAuditionSubmission(
    id: 'sub_04',
    actorName: 'Samir Haddad',
    auditionRole: 'Lead — Dr. Aris',
    score: 88.5,
    submittedAt: DateTime.utc(2026, 4, 2, 11, 0),
    receivedCallback: true,
    age: 35,
    emotionalScore: 87,
    vocalToneScore: 90,
    bodyLanguageScore: 88,
    scriptMatchScore: 89,
  ),
  ActorAuditionSubmission(
    id: 'sub_05',
    actorName: 'Priya Nair',
    auditionRole: 'Supporting — Riva',
    score: 86.0,
    submittedAt: DateTime.utc(2026, 4, 1, 16, 20),
    receivedCallback: true,
    age: 24,
    emotionalScore: 88,
    vocalToneScore: 84,
    bodyLanguageScore: 85,
    scriptMatchScore: 86,
  ),
  ActorAuditionSubmission(
    id: 'sub_06',
    actorName: 'Leo Martens',
    auditionRole: 'Lead — Dr. Aris',
    score: 82.3,
    submittedAt: DateTime.utc(2026, 3, 30, 10, 5),
    receivedCallback: true,
    age: 41,
    emotionalScore: 82,
    vocalToneScore: 83,
    bodyLanguageScore: 81,
    scriptMatchScore: 82,
  ),
  ActorAuditionSubmission(
    id: 'sub_07',
    actorName: 'Noah Brooks',
    auditionRole: 'Supporting — Riva',
    score: 79.8,
    submittedAt: DateTime.utc(2026, 4, 4, 8, 50),
    receivedCallback: false,
    age: 22,
    emotionalScore: 80,
    vocalToneScore: 78,
    bodyLanguageScore: 82,
    scriptMatchScore: 79,
  ),
  ActorAuditionSubmission(
    id: 'sub_08',
    actorName: 'Aisha Rahman',
    auditionRole: 'Lead — Dr. Aris',
    score: 76.4,
    submittedAt: DateTime.utc(2026, 4, 2, 20, 10),
    receivedCallback: false,
    age: 29,
    emotionalScore: 78,
    vocalToneScore: 75,
    bodyLanguageScore: 77,
    scriptMatchScore: 74,
  ),
  ActorAuditionSubmission(
    id: 'sub_09',
    actorName: 'Chris Dalton',
    auditionRole: 'Supporting — Riva',
    score: 71.2,
    submittedAt: DateTime.utc(2026, 3, 29, 13, 40),
    receivedCallback: false,
    age: 38,
    emotionalScore: 72,
    vocalToneScore: 71,
    bodyLanguageScore: 70,
    scriptMatchScore: 72,
  ),
];

/// Returns submissions sorted by [ActorAuditionSubmission.score] descending,
/// with competition-style ranks for ties.
List<RankedAuditionSubmission> mockRankedAuditionSubmissions() {
  return rankAuditionSubmissions(kMockAuditionSubmissions);
}

/// Sorts submissions by score and applies competition-style ranks.
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
