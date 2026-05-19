import 'package:flutter/material.dart';

import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import 'eyes_analysis_page.dart';

/// Director drill-down: eyes analysis layout + tone analysis layout in one place.
class RankingEyesToneDetailsPage extends StatelessWidget {
  const RankingEyesToneDetailsPage({super.key, required this.submission});

  final ActorAuditionSubmission submission;

  @override
  Widget build(BuildContext context) {
    final eyesData = eyesAnalysisResultFromSubmission(submission);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Eyes & tone analysis'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Eyes analysis'),
              Tab(text: 'Tone analysis'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EyesAnalysisPage(data: eyesData, nested: true),
            _ToneAnalysisTabBody(submission: submission),
          ],
        ),
      ),
    );
  }
}

class _ToneAnalysisTabBody extends StatelessWidget {
  const _ToneAnalysisTabBody({required this.submission});

  final ActorAuditionSubmission submission;

  Color _scoreColor(int score) {
    if (score >= 85) return ScenolyticsColors.success;
    if (score >= 60) return ScenolyticsColors.warning;
    return ScenolyticsColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final score = submission.toneAnalysisScore.clamp(0, 100);
    final color = _scoreColor(score);
    return ColoredBox(
      color: ScenolyticsColors.pageBackground,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ScenolyticsColors.metricToneAnalysis,
                  ScenolyticsColors.metricToneAnalysis.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.graphic_eq_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Speech tone & prosody',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ScenolyticsColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.7),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: ScenolyticsColors.textMuted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Measures rhythm, stress, and intonation patterns in the actor’s '
                    'voice relative to the script. Higher scores mean clearer prosodic '
                    'expression and tonal variety.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ScenolyticsColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                color: color.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toString(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            submission.actorName.trim().isEmpty
                ? 'Participant'
                : submission.actorName.trim(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
