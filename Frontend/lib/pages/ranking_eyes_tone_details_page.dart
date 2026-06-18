import 'package:flutter/material.dart';

import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import 'director_actor_profile_details_page.dart';
import 'eyes_analysis_page.dart';
import 'facial_emotion_score.dart';
import 'script_alignemnt_score_page.dart';
import 'vocal_emotion_score.dart';

class SubmissionEvaluationDetailsPage extends StatefulWidget {
  const SubmissionEvaluationDetailsPage({
    super.key,
    required this.submission,
    this.auditionTitle,
    this.auditionSubtitle,
    this.auditionType = '',
    this.rank,
    this.onBack,
  });

  final ActorAuditionSubmission submission;

  final int? rank;

  final String? auditionTitle;

  final String? auditionSubtitle;

  final String auditionType;

  bool get isAudioOnly => auditionType.trim().toLowerCase() == 'audio';

  final VoidCallback? onBack;

  @override
  State<SubmissionEvaluationDetailsPage> createState() =>
      _SubmissionEvaluationDetailsPageState();
}

class _SubmissionEvaluationDetailsPageState
    extends State<SubmissionEvaluationDetailsPage>
    with SingleTickerProviderStateMixin {
  static const _actorProfileTab = _DetailTab(
    kind: _EvaluationTabKind.actorProfile,
    label: 'Actor profile',
    icon: Icons.person_outline_rounded,
  );

  static const _videoTabs = <_DetailTab>[
    _actorProfileTab,
    _DetailTab(
      kind: _EvaluationTabKind.facial,
      label: 'Facial',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.vocal,
      label: 'Vocal',
      icon: Icons.graphic_eq_rounded,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.script,
      label: 'Script',
      icon: Icons.menu_book_rounded,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.eyes,
      label: 'Eyes',
      icon: Icons.remove_red_eye_outlined,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.tone,
      label: 'Tone',
      icon: Icons.equalizer_rounded,
    ),
  ];

  static const _audioTabs = <_DetailTab>[
    _actorProfileTab,
    _DetailTab(
      kind: _EvaluationTabKind.vocal,
      label: 'Vocal',
      icon: Icons.graphic_eq_rounded,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.script,
      label: 'Script',
      icon: Icons.menu_book_rounded,
    ),
    _DetailTab(
      kind: _EvaluationTabKind.tone,
      label: 'Tone',
      icon: Icons.equalizer_rounded,
    ),
  ];

  late final List<_DetailTab> _tabs;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabs = widget.isAudioOnly ? _audioTabs : _videoTabs;
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleBack() {
    final cb = widget.onBack;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _tabBody(_EvaluationTabKind kind) {
    final submission = widget.submission;
    switch (kind) {
      case _EvaluationTabKind.actorProfile:
        return ActorProfileTabBody(
          submission: submission,
          isAudioOnly: widget.isAudioOnly,
        );
      case _EvaluationTabKind.facial:
        return FacialEmotionScorePage(submission: submission, nested: true);
      case _EvaluationTabKind.vocal:
        return VocalEmotionScorePage(submission: submission, nested: true);
      case _EvaluationTabKind.script:
        return ScriptAlignmentScorePage(submission: submission, nested: true);
      case _EvaluationTabKind.eyes:
        return EyesAnalysisPage(
          data: eyesAnalysisResultFromEvaluation(submission),
          pending: !submission.evaluationCompleted,
          nested: true,
        );
      case _EvaluationTabKind.tone:
        return _ToneAnalysisTabBody(submission: submission);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final pageBg = brightness == Brightness.dark
        ? ScenolyticsColors.darkPageBackground
        : ScenolyticsColors.pageBackground;

    return ColoredBox(
      color: pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SubmissionSummaryHeader(
            submission: widget.submission,
            auditionTitle: widget.auditionTitle,
            auditionSubtitle: widget.auditionSubtitle,
            isAudioOnly: widget.isAudioOnly,
            rank: widget.rank,
            onBack: _handleBack,
          ),
          _DetailTabBar(controller: _tabController, tabs: _tabs),
          Expanded(
            child: Container(
              color: cs.surface,
              child: TabBarView(
                controller: _tabController,
                children: [for (final tab in _tabs) _tabBody(tab.kind)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _EvaluationTabKind { actorProfile, facial, vocal, script, eyes, tone }

typedef RankingEyesToneDetailsPage = SubmissionEvaluationDetailsPage;

class _DetailTab {
  const _DetailTab({
    required this.kind,
    required this.label,
    required this.icon,
  });

  final _EvaluationTabKind kind;
  final String label;
  final IconData icon;
}

class _SubmissionSummaryHeader extends StatelessWidget {
  const _SubmissionSummaryHeader({
    required this.submission,
    required this.onBack,
    this.auditionTitle,
    this.auditionSubtitle,
    this.isAudioOnly = false,
    this.rank,
  });

  final ActorAuditionSubmission submission;
  final String? auditionTitle;
  final String? auditionSubtitle;
  final bool isAudioOnly;
  final int? rank;
  final VoidCallback onBack;

  String get _displayName {
    final name = submission.actorName.trim();
    return name.isEmpty ? 'Actor' : name;
  }

  String? get _contextLine {
    final role = submission.auditionRole.trim();
    final title = auditionTitle?.trim() ?? '';
    final parts = <String>[
      if (role.isNotEmpty) role,
      if (title.isNotEmpty) title,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? get _subContextLine {
    final sub = auditionSubtitle?.trim() ?? '';
    return sub.isEmpty ? null : sub;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final gradient = ScenolyticsColors.heroBarGradientFor(brightness);
    final overallScore = submission.score.round();
    final evaluationReady = submission.evaluationCompleted;
    final context2 = _contextLine;
    final sub = _subContextLine;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 520;
          final scoreChip = evaluationReady
              ? _OverallScoreChip(score: overallScore)
              : const _OverallScorePendingChip();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeaderCircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
                tooltip: 'Back to rankings',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI evaluation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        if (isAudioOnly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Audio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (context2 != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        context2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    if (rank != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rank #$rank',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              scoreChip,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _OverallScorePendingChip extends StatelessWidget {
  const _OverallScorePendingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Overall',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverallScoreChip extends StatelessWidget {
  const _OverallScoreChip({required this.score});

  final int score;

  Color _bandColor() {
    if (score >= 85) return ScenolyticsColors.success;
    if (score >= 60) return ScenolyticsColors.warning;
    return ScenolyticsColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _bandColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Overall',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(bottom: 6, right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                ' / 100',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sticky themed tab strip. Uses icon + label, scrolls horizontally on narrow widths.
class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({required this.controller, required this.tabs});

  final TabController controller;
  final List<_DetailTab> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final surface = brightness == Brightness.dark
        ? ScenolyticsColors.darkSurfaceCard
        : ScenolyticsColors.surfaceCard;
    final outline = brightness == Brightness.dark
        ? ScenolyticsColors.darkOutlineSoft.withValues(alpha: 0.45)
        : ScenolyticsColors.outlineSoft.withValues(alpha: 0.5);

    return Material(
      color: surface,
      elevation: brightness == Brightness.dark ? 0 : 1.5,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: outline, width: 1)),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: cs.primary, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 14),
          ),
          dividerColor: Colors.transparent,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            for (final tab in tabs)
              Tab(
                height: 52,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(tab.label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tone analysis tab body — themed score card with a gauge.
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final score = submission.toneAnalysisScore.clamp(0, 100);
    final color = _scoreColor(score);
    final pageBg = brightness == Brightness.dark
        ? ScenolyticsColors.darkPageBackground
        : ScenolyticsColors.pageBackground;
    final cardSurface = brightness == Brightness.dark
        ? ScenolyticsColors.darkSurfaceCard
        : ScenolyticsColors.surfaceCard;
    final outline = brightness == Brightness.dark
        ? ScenolyticsColors.darkOutlineSoft.withValues(alpha: 0.5)
        : ScenolyticsColors.outlineSoft.withValues(alpha: 0.6);
    final mutedText = brightness == Brightness.dark
        ? ScenolyticsColors.darkTextMuted
        : ScenolyticsColors.textMuted;

    return ColoredBox(
      color: pageBg,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 16,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ToneHeroBanner(color: ScenolyticsColors.metricToneAnalysis),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: outline),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _ToneGauge(score: score, color: color),
                          SizedBox(
                            width: wide ? 28 : 0,
                            height: wide ? 0 : 18,
                          ),
                          Expanded(
                            flex: wide ? 1 : 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Speech tone & prosody',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Measures rhythm, stress, and intonation patterns in the actor’s '
                                  'voice relative to the script. Higher scores indicate clearer prosodic '
                                  'expression and richer tonal variety.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: mutedText,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _ToneBandRow(score: score),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToneHeroBanner extends StatelessWidget {
  const _ToneHeroBanner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.equalizer_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Tone analysis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneGauge extends StatelessWidget {
  const _ToneGauge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

class _ToneBandRow extends StatelessWidget {
  const _ToneBandRow({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final bands = <_ToneBand>[
      _ToneBand('Needs work', ScenolyticsColors.error, max: 60),
      _ToneBand('Decent', ScenolyticsColors.warning, max: 85),
      _ToneBand('Excellent', ScenolyticsColors.success, max: 100),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final band in bands)
          _ToneBandPill(
            band: band,
            active: score < band.max &&
                (bands.indexOf(band) == 0 ||
                    score >= bands[bands.indexOf(band) - 1].max),
          ),
      ],
    );
  }
}

class _ToneBand {
  const _ToneBand(this.label, this.color, {required this.max});
  final String label;
  final Color color;
  final int max;
}

class _ToneBandPill extends StatelessWidget {
  const _ToneBandPill({required this.band, required this.active});

  final _ToneBand band;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? band.color.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: band.color.withValues(alpha: active ? 0.8 : 0.4),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: band.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            band.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: band.color,
            ),
          ),
        ],
      ),
    );
  }
}
