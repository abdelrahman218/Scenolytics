import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/actor_audition_submission.dart';
import '../models/actor_profile_details.dart';
import '../theme/scenolytics_colors.dart';

/// Actor casting profile content for the evaluation details tab strip.
class ActorProfileTabBody extends StatelessWidget {
  const ActorProfileTabBody({
    super.key,
    required this.submission,
    this.isAudioOnly = false,
  });

  final ActorAuditionSubmission submission;
  final bool isAudioOnly;

  @override
  Widget build(BuildContext context) {
    final profile = ActorProfileDetails.fromMap(submission.actorProfile);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final pad = wide ? 32.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubmissionSnapshotCard(
                    submission: submission,
                    isAudioOnly: isAudioOnly,
                  ),
                  const SizedBox(height: 16),
                          if (!profile.hasProfileContent)
                            _EmptyProfileCard(
                              actorName: submission.actorName,
                            )
                          else ...[
                            _ProfileSectionCard(
                              icon: Icons.badge_outlined,
                              title: 'About',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (profile.displayName != null &&
                                      profile.displayName!.trim().isNotEmpty)
                                    _ProfileField(
                                      label: 'Display name',
                                      value: profile.displayName!,
                                    ),
                                  if (profile.bio != null &&
                                      profile.bio!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _ProfileField(
                                      label: 'Bio',
                                      value: profile.bio!,
                                      multiline: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ProfileSectionCard(
                              icon: Icons.person_outline_rounded,
                              title: 'Personal details',
                              child: _ProfileFieldGrid(
                                fields: [
                                  if (profile.age != null)
                                    _ProfileFieldData(
                                      'Age',
                                      '${profile.age}',
                                    ),
                                  if (profile.heightCm != null)
                                    _ProfileFieldData(
                                      'Height',
                                      '${profile.heightCm} cm',
                                    ),
                                  if (profile.gender != null &&
                                      profile.gender!.isNotEmpty)
                                    _ProfileFieldData(
                                      'Gender',
                                      profile.gender!,
                                    ),
                                  if (profile.bodyType != null &&
                                      profile.bodyType!.isNotEmpty)
                                    _ProfileFieldData(
                                      'Body type',
                                      profile.bodyType!,
                                    ),
                                  if (profile.ethnicity != null &&
                                      profile.ethnicity!.isNotEmpty)
                                    _ProfileFieldData(
                                      'Ethnicity',
                                      profile.ethnicity!,
                                    ),
                                ],
                              ),
                            ),
                            if (profile.personalityTraits.isNotEmpty ||
                                profile.genres.isNotEmpty ||
                                profile.experienceYears != null ||
                                (profile.portfolioUrl?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 14),
                              _ProfileSectionCard(
                                icon: Icons.theater_comedy_outlined,
                                title: 'Acting profile',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (profile.personalityTraits.isNotEmpty) ...[
                                      Text(
                                        'Personality traits',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final t
                                              in profile.personalityTraits)
                                            _TagChip(label: t),
                                        ],
                                      ),
                                    ],
                                    if (profile.genres.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        'Genres',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final g in profile.genres)
                                            _TagChip(
                                              label: g,
                                              color: ScenolyticsColors
                                                  .secondaryContainer,
                                              onColor: ScenolyticsColors
                                                  .onSecondaryContainer,
                                            ),
                                        ],
                                      ),
                                    ],
                                    if (profile.experienceYears != null) ...[
                                      const SizedBox(height: 14),
                                      _ProfileField(
                                        label: 'Experience',
                                        value:
                                            '${profile.experienceYears} years',
                                      ),
                                    ],
                                    if (profile.portfolioUrl != null &&
                                        profile.portfolioUrl!
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      _PortfolioLink(url: profile.portfolioUrl!),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubmissionSnapshotCard extends StatelessWidget {
  const _SubmissionSnapshotCard({
    required this.submission,
    this.isAudioOnly = false,
  });

  final ActorAuditionSubmission submission;
  final bool isAudioOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final outline = ScenolyticsColors.outlineSoftFor(brightness);

    final evaluationReady = submission.evaluationCompleted;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'This audition',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileFieldGrid(
              fields: [
                _ProfileFieldData(
                  'Overall score',
                  evaluationReady
                      ? '${submission.score.round()} / 100'
                      : 'Pending',
                ),
                _ProfileFieldData(
                  'Submitted',
                  _formatSubmitted(submission.submittedAt),
                ),
                if (evaluationReady) ...[
                  if (!isAudioOnly)
                    _ProfileFieldData(
                      'Facial emotions',
                      '${submission.emotionalScore}',
                    ),
                  _ProfileFieldData(
                    'Vocal emotion',
                    '${submission.vocalToneScore}',
                  ),
                  _ProfileFieldData(
                    'Script match',
                    '${submission.scriptMatchScore}',
                  ),
                ],
              ],
            ),
            if (!evaluationReady) ...[
              const SizedBox(height: 12),
              _AnalysisPendingNotice(),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyProfileCard extends StatelessWidget {
  const _EmptyProfileCard({required this.actorName});

  final String actorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ProfileSectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Profile not on file',
      child: Text(
        '${actorName.trim().isEmpty ? 'This actor' : actorName.trim()} has not '
        'completed a full casting profile yet. Submission scores and status '
        'are still available below.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;
    final outline = ScenolyticsColors.outlineSoftFor(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldData {
  const _ProfileFieldData(this.label, this.value);
  final String label;
  final String value;
}

class _ProfileFieldGrid extends StatelessWidget {
  const _ProfileFieldGrid({required this.fields});

  final List<_ProfileFieldData> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= 420;
        if (!twoCol) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ProfileField(label: fields[i].label, value: fields[i].value),
              ],
            ],
          );
        }
        final rows = <List<_ProfileFieldData>>[];
        for (var i = 0; i < fields.length; i += 2) {
          rows.add(fields.sublist(i, (i + 2).clamp(0, fields.length)));
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ProfileField(
                      label: rows[r][0].label,
                      value: rows[r][0].value,
                    ),
                  ),
                  if (rows[r].length > 1) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: rows[r][1].label,
                        value: rows[r][1].value,
                      ),
                    ),
                  ] else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: multiline ? 1.45 : 1.2,
          ),
        ),
      ],
    );
  }
}

class _AnalysisPendingNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI evaluation pending — scores will appear once analysis completes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.color,
    this.onColor,
  });

  final String label;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.primaryContainer;
    final fg = onColor ?? cs.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _PortfolioLink extends StatelessWidget {
  const _PortfolioLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url.trim());
        if (uri == null) return;
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!context.mounted || ok) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open portfolio link.')),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

String _formatSubmitted(DateTime utc) {
  final local = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
