import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/app_env.dart';
import '../data/api/casting_api.dart';
import '../data/audition_rankings_sort.dart';
import '../data/repositories/auditions_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/actor_audition_submission.dart';
import '../models/actor_callback.dart';
import '../models/audition_submission_status.dart';
import '../models/callback_status.dart';
import '../widgets/callback_status_chips.dart';
import '../pages/ranking_eyes_tone_details_page.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/mysql_datetime.dart';
import '../widgets/scenolytics_footer.dart';

/// Playback fallbacks — gateway path may not have the object; MinIO `:9000` often does,
/// persisting hints from PUT responses is handled in [AuditionsRepository].
List<String> _directorTapePlaybackCandidates(ActorAuditionSubmission submission) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? raw) {
    final u = raw?.trim();
    if (u == null || u.isEmpty) return;
    if (!seen.add(u)) return;
    out.add(u);
  }

  add(submission.recordedVideoUrl);

  final id = submission.mediaId?.trim();
  if (id != null && id.isNotEmpty) {
    String tapeAtPublicBase(String rawBase) {
      var base = rawBase.trim();
      if (base.isEmpty) return '';
      if (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      return '$base/uploads/$id.mp4';
    }

    add(tapeAtPublicBase(AppEnv.minioVideosBase));
    add(tapeAtPublicBase(AppEnv.videoPublicBase));

    Uri? api;
    try {
      api = Uri.parse(AppEnv.apiBaseUrl);
    } catch (_) {
      api = null;
    }
    if (api != null &&
        (api.scheme == 'http' || api.scheme == 'https') &&
        api.host.isNotEmpty &&
        api.host.toLowerCase() != 'localhost' &&
        api.host != '127.0.0.1') {
      add('${api.scheme}://${api.host}:9000/videos/uploads/$id.mp4');
    }
  }

  return out;
}

/// Which slice of the leaderboard is shown below the stats row.
enum RankingsViewMode {
  /// Full list, competition ranks preserved.
  all,

  /// Highest-scoring ten rows (same ranks as in [all]).
  topTen,
}

/// Director-facing leaderboard of actor submissions for an audition, sorted by score.
/// Layout adapts from narrow (mobile) to wide (web / tablet landscape).
class AuditionRankingsPage extends StatefulWidget {
  const AuditionRankingsPage({
    super.key,
    this.submissions,
    required this.auditionTitle,
    required this.auditionSubtitle,
    this.auditionType = '',
    this.directorDisplayName,
    this.onRefresh,
    this.directorReviewToken,
    this.directorReviewAuditionId,
    this.directorReviewRepository,
    this.onBackToDashboard,
    this.onOpenSubmissionDetails,
  });

  final List<ActorAuditionSubmission>? submissions;
  final String auditionTitle;
  final String auditionSubtitle;

  /// Casting `auditions.type` ('Audio' / 'Video'). Drives the playback button
  /// label and icon and which media element renders inside the dialog.
  final String auditionType;

  bool get _isAudioOnly =>
      auditionType.trim().toLowerCase() == 'audio';

  /// From `GET /api/v1/directors/:id/profile` when the director JWT resolves.
  final String? directorDisplayName;
  final Future<void> Function()? onRefresh;

  /// When set with [directorReviewAuditionId] and [directorReviewRepository], the
  /// director can accept / reject pending or under-review rows.
  final String? directorReviewToken;
  final String? directorReviewAuditionId;
  final AuditionsRepository? directorReviewRepository;

  /// Returns to the director dashboard (shell navigation).
  final VoidCallback? onBackToDashboard;

  /// Opens the full AI-evaluation drill-down within the app shell, so the page
  /// inherits the top header instead of pushing a bare route.
  final ValueChanged<ActorAuditionSubmission>? onOpenSubmissionDetails;

  @override
  State<AuditionRankingsPage> createState() => _AuditionRankingsPageState();
}

class _AuditionRankingsPageState extends State<AuditionRankingsPage> {
  /// Aligns content width with director dashboard / create-audition pages.
  static const double _xWideBreakpoint = 1280;
  static const double _maxContentWidth = 1240;

  RankingsViewMode _viewMode = RankingsViewMode.all;
  AuditionRankingsSortBy _sortBy = AuditionRankingsSortBy.overall;

  /// While a PATCH submission review is in flight for this submission id.
  String? _busyReviewSubmissionId;

  /// While a PATCH callback review is in flight for this callback id.
  String? _busyCallbackReviewId;

  /// While `new_meeting` is in flight for this callback id.
  String? _busyRegenerateCallbackId;

  /// While `reschedule` is in flight for this callback id.
  String? _busyRescheduleCallbackId;

  Map<String, DirectorAuditionCallback> _callbacksBySubmissionId =
      const <String, DirectorAuditionCallback>{};

  static const int _topCandidateCount = 10;

  void _normalizeSortForAuditionType() {
    final next = auditionRankingsSortOrFallback(
      _sortBy,
      isAudioOnly: widget._isAudioOnly,
    );
    if (next != _sortBy) _sortBy = next;
  }

  @override
  void initState() {
    super.initState();
    _normalizeSortForAuditionType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCallbacks();
    });
  }

  @override
  void didUpdateWidget(covariant AuditionRankingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auditionType != widget.auditionType) {
      final next = auditionRankingsSortOrFallback(
        _sortBy,
        isAudioOnly: widget._isAudioOnly,
      );
      if (next != _sortBy) setState(() => _sortBy = next);
    }
  }

  Future<void> _refreshRankings() async {
    await widget.onRefresh?.call();
  }

  Future<void> _loadCallbacks() async {
    if (!_canConfigureDirectorReview) return;
    try {
      final map = await widget.directorReviewRepository!
          .loadDirectorCallbacksBySubmission(
        directorToken: widget.directorReviewToken!.trim(),
        auditionId: widget.directorReviewAuditionId!.trim(),
      );
      if (!mounted) return;
      setState(() => _callbacksBySubmissionId = map);
    } catch (_) {}
  }

  String _formatCallbackWhen(DateTime dt) {
    final l = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${p2(l.month)}-${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  List<RankedAuditionSubmission> _visibleRanked(
    List<RankedAuditionSubmission> ranked,
  ) {
    switch (_viewMode) {
      case RankingsViewMode.all:
        return ranked;
      case RankingsViewMode.topTen:
        if (ranked.length <= _topCandidateCount) return ranked;
        return ranked.sublist(0, _topCandidateCount);
    }
  }

  bool get _canConfigureDirectorReview =>
      widget.directorReviewRepository != null &&
      (widget.directorReviewToken?.trim().isNotEmpty ?? false) &&
      (widget.directorReviewAuditionId?.trim().isNotEmpty ?? false);

  Future<DateTime?> _pickCallbackDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final seed = initial?.toLocal() ?? now.add(const Duration(days: 7));
    final d = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: seed.hour, minute: seed.minute),
    );
    if (t == null || !mounted) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _applyDirectorReview(
    ActorAuditionSubmission submission,
    String status, {
    String? callbackDatetime,
  }) async {
    if (!_canConfigureDirectorReview) return;
    setState(() => _busyReviewSubmissionId = submission.id);
    try {
      await widget.directorReviewRepository!.reviewDirectorAuditionSubmission(
        directorToken: widget.directorReviewToken!.trim(),
        auditionId: widget.directorReviewAuditionId!.trim(),
        submissionId: submission.id,
        status: status,
        callbackDatetime: callbackDatetime,
      );
      if (!mounted) return;
      final msg = status == 'accepted'
          ? 'Submission accepted.'
          : 'Submission rejected.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _refreshRankings();
      await _loadCallbacks();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed (${e.runtimeType}).')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyReviewSubmissionId = null);
      }
    }
  }

  Future<void> _onDirectorAccept(ActorAuditionSubmission s) async {
    final when = await _pickCallbackDateTime();
    if (when == null) return;
    await _applyDirectorReview(
      s,
      'accepted',
      callbackDatetime: formatDateTimeForMysqlUtc(when),
    );
  }

  Future<void> _onDirectorReject(ActorAuditionSubmission s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this submission?'),
        content: const Text(
          'The actor will see this as rejected on their audition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _applyDirectorReview(s, 'rejected');
  }

  Future<void> _applyCallbackReview(
    DirectorAuditionCallback callback,
    String status,
  ) async {
    if (!_canConfigureDirectorReview) return;
    setState(() => _busyCallbackReviewId = callback.id);
    try {
      await widget.directorReviewRepository!.reviewDirectorCallback(
        directorToken: widget.directorReviewToken!.trim(),
        auditionId: widget.directorReviewAuditionId!.trim(),
        callbackId: callback.id,
        status: status,
      );
      if (!mounted) return;
      final msg = status == 'accepted'
          ? 'Callback accepted — actor will see the outcome.'
          : 'Callback rejected.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _refreshRankings();
      await _loadCallbacks();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Callback review failed (${e.runtimeType}).')),
      );
    } finally {
      if (mounted) setState(() => _busyCallbackReviewId = null);
    }
  }

  Future<void> _onCallbackConfirm(DirectorAuditionCallback callback) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept callback outcome?'),
        content: const Text(
          'The actor will see this callback as accepted in their audition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _applyCallbackReview(callback, 'accepted');
  }

  Future<void> _onRescheduleCallback(DirectorAuditionCallback callback) async {
    if (!_canConfigureDirectorReview) return;

    final when = await _pickCallbackDateTime(
      initial: callback.callbackDatetime,
    );
    if (when == null || !mounted) return;

    setState(() => _busyRescheduleCallbackId = callback.id);
    try {
      // Re-accept updates Meet/time without the broken reschedule route (frontend-only).
      await widget.directorReviewRepository!.reviewDirectorAuditionSubmission(
        directorToken: widget.directorReviewToken!.trim(),
        auditionId: widget.directorReviewAuditionId!.trim(),
        submissionId: callback.auditionSubmissionId,
        status: 'accepted',
        callbackDatetime: formatDateTimeForMysqlUtc(when),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Callback rescheduled to ${_formatCallbackWhen(when)}. '
            'The actor will see the updated time and Meet link.',
          ),
        ),
      );
      await _loadCallbacks();
      await _refreshRankings();
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase().contains('not found')
          ? 'Could not reschedule. Check the audition and try again.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reschedule (${e.runtimeType}).'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRescheduleCallbackId = null);
    }
  }

  Future<void> _onRegenerateMeetLink(DirectorAuditionCallback callback) async {
    if (!_canConfigureDirectorReview) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Meet link?'),
        content: const Text(
          'This creates a new Google Meet link for the same callback time. '
          'The actor will see the updated link on their audition page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyRegenerateCallbackId = callback.id);
    try {
      await widget.directorReviewRepository!.regenerateDirectorCallbackMeetingLink(
        directorToken: widget.directorReviewToken!.trim(),
        auditionId: widget.directorReviewAuditionId!.trim(),
        callbackId: callback.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meet link regenerated.')),
      );
      await _loadCallbacks();
      await _refreshRankings();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.contains('<html')
                ? 'Could not regenerate the Meet link. Connect Google Calendar in Settings, then try again.'
                : e.message,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not regenerate the Meet link. Connect Google Calendar in Settings, then try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRegenerateCallbackId = null);
    }
  }

  Future<void> _onCallbackDecline(DirectorAuditionCallback callback) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject after callback?'),
        content: const Text(
          'The actor will see this callback as rejected on their audition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _applyCallbackReview(callback, 'rejected');
  }

  Future<void> _openMeetLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Meet link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submissions = widget.submissions ?? const <ActorAuditionSubmission>[];
    final ranked =
        rankAuditionSubmissions(submissions, sortBy: _sortBy);
    final theme = Theme.of(context);
    final visible = _visibleRanked(ranked);
    final metricValues = ranked
        .map(
          (e) => auditionRankingSortMetric(e.submission, _sortBy),
        )
        .toList();
    final averageMetric = metricValues.isEmpty
        ? 0.0
        : metricValues.reduce((a, b) => a + b) / metricValues.length;
    final topMetric = metricValues.isEmpty ? 0.0 : metricValues.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ScenolyticsColors.pageBackdropGradientFor(
                theme.brightness,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layoutW = constraints.maxWidth;
                final hPad =
                    layoutW >= _xWideBreakpoint ? 36.0 : 16.0;
                final sidePad = hPad +
                    (layoutW > _maxContentWidth
                        ? (layoutW - _maxContentWidth) / 2
                        : 0.0);

                final slivers = <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(sidePad, 12, sidePad, 0),
                    sliver: SliverToBoxAdapter(
                      child: _RankingsHeaderCard(
                        auditionTitle: widget.auditionTitle,
                        auditionSubtitle: widget.auditionSubtitle,
                        directorDisplayName: widget.directorDisplayName,
                        onBackToDashboard: widget.onBackToDashboard,
                      ),
                    ),
                  ),
                ];

                if (ranked.isEmpty) {
                  slivers.add(
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(sidePad, 24, sidePad, 24),
                          child: Text(
                            'No submissions yet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  slivers.addAll([
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(sidePad, 16, sidePad, 12),
                      sliver: SliverToBoxAdapter(
                        child: _StatsSection(
                          totalSubmissions: ranked.length,
                          sortBy: _sortBy,
                          averageMetric: averageMetric,
                          topMetric: topMetric,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(sidePad, 0, sidePad, 12),
                      sliver: SliverToBoxAdapter(
                        child: _RankingsViewToolbar(
                          mode: _viewMode,
                          onModeChanged: (m) => setState(() => _viewMode = m),
                          sortBy: _sortBy,
                          isAudioOnly: widget._isAudioOnly,
                          onSortByChanged: (s) => setState(() => _sortBy = s),
                        ),
                      ),
                    ),
                    if (visible.isEmpty)
                      SliverPadding(
                        padding:
                            EdgeInsets.fromLTRB(sidePad, 32, sidePad, 24),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              'Nothing to show for this view.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            EdgeInsets.fromLTRB(sidePad, 0, sidePad, 28),
                        sliver: SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final submission = visible[index].submission;
                            final callback =
                                _callbacksBySubmissionId[submission.id];
                            return _CompactRankCard(
                              entry: visible[index],
                              sortBy: _sortBy,
                              isAudioOnly: widget._isAudioOnly,
                              directorCallback: callback,
                              formatCallbackWhen: _formatCallbackWhen,
                              onOpenMeetLink: _openMeetLink,
                              onDirectorAccept: _canConfigureDirectorReview
                                  ? _onDirectorAccept
                                  : null,
                              onDirectorReject: _canConfigureDirectorReview
                                  ? _onDirectorReject
                                  : null,
                              onCallbackConfirm:
                                  _canConfigureDirectorReview &&
                                          callback != null
                                      ? _onCallbackConfirm
                                      : null,
                              onCallbackDecline:
                                  _canConfigureDirectorReview &&
                                          callback != null
                                      ? _onCallbackDecline
                                      : null,
                              busyReviewSubmissionId: _busyReviewSubmissionId,
                              busyCallbackReviewId: _busyCallbackReviewId,
                              onRescheduleCallback:
                                  _canConfigureDirectorReview &&
                                          callback != null &&
                                          callback.status ==
                                              CallbackStatus.scheduled
                                      ? _onRescheduleCallback
                                      : null,
                              onRegenerateMeetLink:
                                  _canConfigureDirectorReview &&
                                          callback != null &&
                                          callback.status ==
                                              CallbackStatus.scheduled
                                      ? _onRegenerateMeetLink
                                      : null,
                              busyRescheduleCallbackId:
                                  _busyRescheduleCallbackId,
                              busyRegenerateCallbackId:
                                  _busyRegenerateCallbackId,
                              onOpenSubmissionDetails:
                                  widget.onOpenSubmissionDetails,
                              auditionType: widget.auditionType,
                            );
                          },
                        ),
                      ),
                  ]);
                }

                final kb = MediaQuery.viewInsetsOf(context).bottom;
                Widget scrollView = CustomScrollView(
                  physics: widget.onRefresh != null
                      ? const AlwaysScrollableScrollPhysics()
                      : null,
                  slivers: [
                    ...slivers,
                    SliverToBoxAdapter(child: SizedBox(height: kb)),
                  ],
                );

                if (widget.onRefresh != null) {
                  scrollView = RefreshIndicator(
                    onRefresh: _refreshRankings,
                    child: scrollView,
                  );
                }

                return scrollView;
              },
            ),
          ),
        ),
        const ScenolyticsFooter(),
      ],
    );
  }
}

class _RankingsViewToolbar extends StatelessWidget {
  const _RankingsViewToolbar({
    required this.mode,
    required this.onModeChanged,
    required this.sortBy,
    required this.isAudioOnly,
    required this.onSortByChanged,
  });

  final RankingsViewMode mode;
  final ValueChanged<RankingsViewMode> onModeChanged;
  final AuditionRankingsSortBy sortBy;
  final bool isAudioOnly;
  final ValueChanged<AuditionRankingsSortBy> onSortByChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        const gap = 12.0;
        const stackBreakpoint = 480.0;

        if (avail < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _SlidingRankingsSegmentedControl._height,
                child: _SlidingRankingsSegmentedControl(
                  mode: mode,
                  onModeChanged: onModeChanged,
                ),
              ),
              SizedBox(height: gap),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: avail < 260 ? avail : 260,
                  ),
                  child: _RankSortByDropdown(
                    value: sortBy,
                    sortOptions: auditionRankingsSortOptions(
                      isAudioOnly: isAudioOnly,
                    ),
                    onChanged: onSortByChanged,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: _SlidingRankingsSegmentedControl._height,
                child: _SlidingRankingsSegmentedControl(
                  mode: mode,
                  onModeChanged: onModeChanged,
                ),
              ),
            ),
            SizedBox(width: gap),
            _RankSortByDropdown(
              value: sortBy,
              sortOptions: auditionRankingsSortOptions(isAudioOnly: isAudioOnly),
              onChanged: onSortByChanged,
            ),
          ],
        );
      },
    );
  }
}

/// Rank-by criterion (overall / facet scores).
class _RankSortByDropdown extends StatelessWidget {
  const _RankSortByDropdown({
    required this.value,
    required this.sortOptions,
    required this.onChanged,
  });

  final AuditionRankingsSortBy value;
  final List<AuditionRankingsSortBy> sortOptions;
  final ValueChanged<AuditionRankingsSortBy> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;

    final h = _SlidingRankingsSegmentedControl._height;
    final borderSide = BorderSide(
      color: cs.outline.withValues(alpha: b == Brightness.dark ? 0.55 : 0.42),
    );

    // Soft lift on web/desktop so the control reads as a button, not a full field.
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: kIsWeb ? (b == Brightness.dark ? 0.24 : 0.08) : 0),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

    // Plain DecoratedBox — no Ink/Material wrapper. Ink + DropdownButton both
    // paint splash/focus on web and leave a stuck white crescent on the left.
    return Tooltip(
      message: 'Ranking: ${value.menuLabel}',
      waitDuration: const Duration(milliseconds: 550),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 164, maxWidth: 226),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surface.withValues(alpha: kIsWeb ? 0.94 : 1),
                cs.primaryContainer.withValues(alpha: b == Brightness.dark ? 0.14 : 0.42),
              ],
            ),
            border: Border.fromBorderSide(borderSide),
            boxShadow: shadow,
          ),
          child: Theme(
            data: theme.copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: SizedBox(
              height: h,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AuditionRankingsSortBy>(
                    value: value,
                    isDense: true,
                    focusColor: Colors.transparent,
                    elevation: kIsWeb ? 8 : 4,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: cs.surface,
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    iconSize: 22,
                    isExpanded: true,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                      fontSize: 13,
                    ),
                    items: sortOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.menuLabel),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                    selectedItemBuilder: (ctx) =>
                        sortOptions.map((e) {
                          return Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 17,
                                  color: cs.primary.withValues(alpha: 0.88),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e.menuLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One capsule control with a sliding pill (iOS-style); colors from [ScenolyticsColors].
class _SlidingRankingsSegmentedControl extends StatelessWidget {
  const _SlidingRankingsSegmentedControl({
    required this.mode,
    required this.onModeChanged,
  });

  final RankingsViewMode mode;
  final ValueChanged<RankingsViewMode> onModeChanged;

  static const double _height = 36;
  static const double _pillInset = 2.5;

  int get _selectedIndex => switch (mode) {
    RankingsViewMode.all => 0,
    RankingsViewMode.topTen => 1,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final track = ScenolyticsColors.rankingsSegmentTrack(b);
    final pill = ScenolyticsColors.rankingsSegmentPill(b);
    final selectedLabel = ScenolyticsColors.rankingsSegmentSelectedLabel(b);
    final unselectedLabel = ScenolyticsColors.rankingsSegmentUnselectedLabel(b);
    final pillRadius = (_height - 2 * _pillInset) / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w <= 0) return const SizedBox(height: _height);

        final segW = w / 2;
        final pillW = segW - 2 * _pillInset;
        final pillLeft = _pillInset + _selectedIndex * segW;

        return SizedBox(
          height: _height,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
                child: const SizedBox.expand(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: pillLeft,
                top: _pillInset,
                width: pillW,
                bottom: _pillInset,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pill,
                    borderRadius: BorderRadius.circular(pillRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: b == Brightness.dark ? 0.28 : 0.1,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SegmentTap(
                      label: 'All Rankings',
                      selected: mode == RankingsViewMode.all,
                      selectedColor: selectedLabel,
                      unselectedColor: unselectedLabel,
                      onTap: () => onModeChanged(RankingsViewMode.all),
                    ),
                  ),
                  Expanded(
                    child: _SegmentTap(
                      label: 'Top Candidates',
                      selected: mode == RankingsViewMode.topTen,
                      selectedColor: selectedLabel,
                      unselectedColor: unselectedLabel,
                      onTap: () => onModeChanged(RankingsViewMode.topTen),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentTap extends StatelessWidget {
  const _SegmentTap({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          _SlidingRankingsSegmentedControl._height / 2,
        ),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  fontSize: 12.5,
                  color: selected ? selectedColor : unselectedColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




/// Hero-style card: title, audition name, and round — gradients in light mode,
/// deeper hero tones in dark mode so it stays readable on the page backdrop.
class _RankingsHeaderCard extends StatelessWidget {
  const _RankingsHeaderCard({
    required this.auditionTitle,
    required this.auditionSubtitle,
    this.directorDisplayName,
    this.onBackToDashboard,
  });

  final String auditionTitle;
  final String auditionSubtitle;
  final String? directorDisplayName;
  final VoidCallback? onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final onHero = ScenolyticsColors.onPrimary;

    final decoration = BoxDecoration(
      gradient: ScenolyticsColors.heroBarGradientFor(b),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: onHero.withValues(alpha: ScenolyticsColors.heroBorderAlpha(b)),
      ),
      boxShadow: [
        BoxShadow(
          color: ScenolyticsColors.heroGradientStart.withValues(
            alpha: ScenolyticsColors.heroGlowShadowAlpha(b),
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: decoration,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBackToDashboard != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBackToDashboard,
                    style: TextButton.styleFrom(
                      foregroundColor: onHero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: Text(
                      'Back to dashboard',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.movie_filter_rounded, color: onHero, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Audition rankings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 8,
                            color: Color(0x55000000),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (directorDisplayName != null &&
                  directorDisplayName!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  directorDisplayName!.trim(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onHero.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                auditionTitle.trim().isEmpty ? '—' : auditionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
                    size: 18,
                    color: onHero.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auditionSubtitle.trim().isEmpty ? '—' : auditionSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onHero.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: -8,
          top: -12,
          child: Icon(
            Icons.movie_filter_rounded,
            size: 96,
            color: onHero.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.totalSubmissions,
    required this.sortBy,
    required this.averageMetric,
    required this.topMetric,
  });

  final int totalSubmissions;
  final AuditionRankingsSortBy sortBy;
  final double averageMetric;
  final double topMetric;

  static String _formatAverage(double v) => v.toStringAsFixed(1);

  static String _formatTop(AuditionRankingsSortBy sortBy, double v) =>
      sortBy == AuditionRankingsSortBy.overall
          ? v.toStringAsFixed(1)
          : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final cards = <Widget>[
      _StatCard(
        label: 'Total submissions',
        value: '$totalSubmissions',
        icon: Icons.groups_2_outlined,
      ),
      _StatCard(
        label: sortBy.statsAverageLabel,
        value: _formatAverage(averageMetric),
        icon: Icons.analytics_outlined,
      ),
      _StatCard(
        label: sortBy.statsTopLabel,
        value: _formatTop(sortBy, topMetric),
        icon: Icons.emoji_events_outlined,
      ),
    ];

    if (width >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: cards[i]),
            if (i < 2) const SizedBox(width: 12),
          ],
        ],
      );
    }

    // Phone and tablet: two cards side by side, then full-width top score.
    // (Avoid [Table] here — on some devices the first row collapsed to zero height.)
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: cards[2])],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;

    return Material(
      color: cs.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(b).withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _presentDirectorAuditionMedia(
  BuildContext context,
  ActorAuditionSubmission submission, {
  required bool isAudioOnly,
}) {
  final candidates = _directorTapePlaybackCandidates(submission);
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAudioOnly
              ? 'Audio is not available for this submission yet.'
              : 'Video is not available for this submission yet.',
        ),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DirectorAuditionMediaSheet(
      playbackCandidates: candidates,
      actorName: submission.actorName,
      age: submission.age,
      isAudioOnly: isAudioOnly,
    ),
  );
}

class _DirectorAuditionMediaSheet extends StatefulWidget {
  const _DirectorAuditionMediaSheet({
    required this.playbackCandidates,
    required this.actorName,
    required this.age,
    required this.isAudioOnly,
  });

  final List<String> playbackCandidates;
  final String actorName;
  final int age;
  final bool isAudioOnly;

  @override
  State<_DirectorAuditionMediaSheet> createState() =>
      _DirectorAuditionMediaSheetState();
}

class _DirectorAuditionMediaSheetState
    extends State<_DirectorAuditionMediaSheet> {
  VideoPlayerController? _videoController;

  // Audio playback (only used when widget.isAudioOnly is true).
  late final ap.AudioPlayer _audioPlayer;
  bool _audioReady = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? _error;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.isAudioOnly) {
      _audioPlayer = ap.AudioPlayer();
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state == ap.PlayerState.playing;
          if (state == ap.PlayerState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
          }
        });
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d);
      });
    }
    _init();
  }

  Future<void> _init() async {
    Object? lastError;
    final urls = widget.playbackCandidates;
    if (widget.isAudioOnly) {
      for (final uriStr in urls) {
        try {
          await _audioPlayer.setSource(ap.UrlSource(uriStr));
          if (!mounted) return;
          setState(() {
            _audioReady = true;
            _resolvedUrl = uriStr;
          });
          return;
        } catch (e) {
          lastError = e;
        }
      }
      if (mounted) {
        final tried = urls.join('\n');
        setState(() {
          _error = 'Could not load audio.\n$tried\n\n${lastError ?? ''}';
        });
      }
      return;
    }
    for (final uriStr in urls) {
      VideoPlayerController? c;
      try {
        c = VideoPlayerController.networkUrl(Uri.parse(uriStr));
        await c.initialize();
        if (!mounted) {
          await c.dispose();
          return;
        }
        setState(() {
          _videoController = c;
          _resolvedUrl = uriStr;
        });
        return;
      } catch (e, _) {
        lastError = e;
        await c?.dispose();
      }
    }
    if (mounted) {
      final tried = urls.join('\n');
      setState(() {
        _error = kIsWeb
            ? 'Could not load video in the browser.\n\n'
                  'URLs tried:\n$tried\n\n'
                  'Hint: the object URL must match where the PUT presign pointed '
                  '(see casting logs). We also probe SCENO_MINIO_VIDEOS_BASE — '
                  'pass --dart-define=SCENO_MINIO_VIDEOS_BASE=http://localhost:9000/videos '
                  'if your MinIO differs. Confirm GET returns MP4 bytes, not MinIO '
                  'XML NoSuchKey.'
            : 'Could not load video.\n$tried\n\n${lastError ?? ''}';
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    if (widget.isAudioOnly) _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (!_audioReady || _resolvedUrl == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildAudioPlayer(ThemeData theme, ColorScheme cs) {
    if (!_audioReady) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final total = _duration > Duration.zero ? _duration : Duration.zero;
    final positionMs = _position.inMilliseconds.toDouble();
    final totalMs = total.inMilliseconds.toDouble();
    final progress =
        totalMs <= 0 ? 0.0 : (positionMs / totalMs).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.92),
                ScenolyticsColors.accentCyan.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: CustomPaint(
                  size: const Size.fromHeight(double.infinity),
                  painter: _MockWavePainter(
                    progress: progress,
                    active: Colors.white,
                    inactive: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.all(14),
                    ),
                    iconSize: 28,
                    onPressed: _toggleAudio,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio take',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(total)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final controller = _videoController;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad + 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            color: cs.surfaceContainerHigh,
            elevation: 14,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ScenolyticsColors.accentCyan.withValues(alpha: 0.22),
                        cs.primaryContainer.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.isAudioOnly
                                ? Icons.graphic_eq_rounded
                                : Icons.movie_filter_rounded,
                            color: cs.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isAudioOnly
                                    ? 'Audition audio'
                                    : 'Audition recording',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.actorName.trim().isEmpty
                                    ? '—'
                                    : widget.actorName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.age > 0)
                                Text(
                                  'Age ${widget.age}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.start,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: (_resolvedUrl != null &&
                                                _resolvedUrl!.isNotEmpty)
                                            ? _resolvedUrl!
                                            : widget
                                                .playbackCandidates
                                                .first,
                                      ),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            widget.isAudioOnly
                                                ? 'Audio link copied.'
                                                : 'Video link copied.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    widget.isAudioOnly
                                        ? 'Copy audio link'
                                        : 'Copy video link',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : widget.isAudioOnly
                      ? _buildAudioPlayer(theme, cs)
                      : controller == null || !controller.value.isInitialized
                      ? const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: controller.value.aspectRatio == 0
                                  ? 16 / 9
                                  : controller.value.aspectRatio,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: GestureDetector(
                                  onTap: () {
                                    if (controller.value.isPlaying) {
                                      controller.pause();
                                    } else {
                                      controller.play();
                                    }
                                    setState(() {});
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ColoredBox(
                                        color: Colors.black,
                                        child: VideoPlayer(controller),
                                      ),
                                      ListenableBuilder(
                                        listenable: controller,
                                        builder: (context, _) {
                                          if (controller.value.isPlaying) {
                                            return const SizedBox.shrink();
                                          }
                                          return DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  18,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.play_arrow_rounded,
                                                  size: 52,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.95),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListenableBuilder(
                              listenable: controller,
                              builder: (context, _) {
                                return Row(
                                  children: [
                                    IconButton.filledTonal(
                                      onPressed: () {
                                        if (controller.value.isPlaying) {
                                          controller.pause();
                                        } else {
                                          controller.play();
                                        }
                                        setState(() {});
                                      },
                                      icon: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                    ),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        controller,
                                        allowScrubbing: true,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        colors: VideoProgressColors(
                                          playedColor: cs.primary,
                                          bufferedColor: cs.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          backgroundColor: cs.outline
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative static waveform behind the director audio playback dialog.
class _MockWavePainter extends CustomPainter {
  _MockWavePainter({
    required this.progress,
    required this.active,
    required this.inactive,
  });

  final double progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const int bars = 48;
    const double gap = 3.0;
    final barWidth = (size.width - gap * (bars - 1)) / bars;
    final centerY = size.height / 2;
    final maxBar = size.height * 0.95;
    final minBar = size.height * 0.18;
    final cutoff = (progress * bars).clamp(0.0, bars.toDouble());
    for (int i = 0; i < bars; i++) {
      final t = i / bars;
      // Pseudo-random but stable heights for a clean waveform look.
      final h = minBar +
          (maxBar - minBar) *
              (0.4 + 0.6 * ((1 + (i * 9301 + 49297) % 233) / 233.0)) *
              (0.6 + 0.4 * t.clamp(0.0, 1.0));
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - h / 2, barWidth, h),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i < cutoff ? active : inactive,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MockWavePainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.inactive != inactive;
}

/// Callback schedule + post-meeting accept/decline on director ranking cards.
class _CallbackManagementSection extends StatelessWidget {
  const _CallbackManagementSection({
    required this.callback,
    required this.formatCallbackWhen,
    required this.meetLink,
    this.onOpenMeetLink,
    required this.showReviewActions,
    required this.reviewBusy,
    required this.regenerateBusy,
    required this.rescheduleBusy,
    this.onRescheduleCallback,
    this.onRegenerateMeetLink,
    this.onConfirm,
    this.onDecline,
  });

  final DirectorAuditionCallback callback;
  final String Function(DateTime dt) formatCallbackWhen;
  final String meetLink;
  final Future<void> Function(String url)? onOpenMeetLink;
  final bool showReviewActions;
  final bool reviewBusy;
  final bool regenerateBusy;
  final bool rescheduleBusy;
  final Future<void> Function(DirectorAuditionCallback)? onRescheduleCallback;
  final Future<void> Function(DirectorAuditionCallback)? onRegenerateMeetLink;
  final Future<void> Function(DirectorAuditionCallback)? onConfirm;
  final Future<void> Function(DirectorAuditionCallback)? onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final when = callback.callbackDatetime;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Callback',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (when != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Scheduled ${formatCallbackWhen(when)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                if (onRescheduleCallback != null)
                  OutlinedButton.icon(
                    onPressed: reviewBusy || regenerateBusy || rescheduleBusy
                        ? null
                        : () => onRescheduleCallback!(callback),
                    icon: rescheduleBusy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: Text(
                      rescheduleBusy ? 'Rescheduling…' : 'Reschedule',
                    ),
                  ),
                if (onRegenerateMeetLink != null)
                  OutlinedButton.icon(
                    onPressed: reviewBusy || regenerateBusy || rescheduleBusy
                        ? null
                        : () => onRegenerateMeetLink!(callback),
                    icon: regenerateBusy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      regenerateBusy ? 'Regenerating…' : 'Regenerate link',
                    ),
                  ),
              ],
            ),
          ] else if (onRescheduleCallback != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: reviewBusy || regenerateBusy || rescheduleBusy
                    ? null
                    : () => onRescheduleCallback!(callback),
                icon: rescheduleBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(rescheduleBusy ? 'Rescheduling…' : 'Reschedule'),
              ),
            ),
          ],
          if (meetLink.isNotEmpty && onOpenMeetLink != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: reviewBusy ||
                        regenerateBusy ||
                        rescheduleBusy
                    ? null
                    : () => onOpenMeetLink!(meetLink),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Open Meet'),
              ),
            ),
          ],
          if (showReviewActions) ...[
            const SizedBox(height: 8),
            Text(
              'After the callback meeting',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: reviewBusy || onConfirm == null
                      ? null
                      : () => onConfirm!(callback),
                  icon: reviewBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  label: Text(reviewBusy ? 'Saving…' : 'Accept'),
                ),
                OutlinedButton.icon(
                  onPressed: reviewBusy || onDecline == null
                      ? null
                      : () => onDecline!(callback),
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ] else if (callback.status == CallbackStatus.accepted) ...[
            const SizedBox(height: 6),
            Text(
              'Outcome recorded — actor passed this callback.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ] else if (callback.status == CallbackStatus.rejected) ...[
            const SizedBox(height: 6),
            Text(
              'Outcome recorded — callback rejected.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactRankCard extends StatelessWidget {
  const _CompactRankCard({
    required this.entry,
    required this.sortBy,
    this.isAudioOnly = false,
    this.directorCallback,
    required this.formatCallbackWhen,
    this.onOpenMeetLink,
    this.onDirectorAccept,
    this.onDirectorReject,
    this.onCallbackConfirm,
    this.onCallbackDecline,
    this.onRescheduleCallback,
    this.onRegenerateMeetLink,
    this.onOpenSubmissionDetails,
    this.auditionType = '',
    this.busyReviewSubmissionId,
    this.busyCallbackReviewId,
    this.busyRescheduleCallbackId,
    this.busyRegenerateCallbackId,
  });

  final RankedAuditionSubmission entry;
  final AuditionRankingsSortBy sortBy;
  final bool isAudioOnly;
  final DirectorAuditionCallback? directorCallback;
  final String Function(DateTime dt) formatCallbackWhen;
  final Future<void> Function(String url)? onOpenMeetLink;
  final Future<void> Function(ActorAuditionSubmission)? onDirectorAccept;
  final Future<void> Function(ActorAuditionSubmission)? onDirectorReject;
  final Future<void> Function(DirectorAuditionCallback)? onCallbackConfirm;
  final Future<void> Function(DirectorAuditionCallback)? onCallbackDecline;
  final Future<void> Function(DirectorAuditionCallback)? onRescheduleCallback;
  final Future<void> Function(DirectorAuditionCallback)? onRegenerateMeetLink;
  final ValueChanged<ActorAuditionSubmission>? onOpenSubmissionDetails;
  final String auditionType;
  final String? busyReviewSubmissionId;
  final String? busyCallbackReviewId;
  final String? busyRescheduleCallbackId;
  final String? busyRegenerateCallbackId;

  static const double _radius = 14;
  static const double _accentWidth = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final s = entry.submission;

    final showDirectorReview = onDirectorAccept != null &&
        onDirectorReject != null &&
        (s.submissionStatus == AuditionSubmissionStatus.pending ||
            s.submissionStatus == AuditionSubmissionStatus.underReview);
    final reviewBusy = busyReviewSubmissionId == s.id;

    final callback = directorCallback;
    final callbackStatus = callback?.status;
    final showCallbackReview = onCallbackConfirm != null &&
        onCallbackDecline != null &&
        s.submissionStatus == AuditionSubmissionStatus.accepted &&
        callback != null &&
        callback.status == CallbackStatus.scheduled;
    final callbackBusy =
        callback != null && busyCallbackReviewId == callback.id;
    final regenerateBusy =
        callback != null && busyRegenerateCallbackId == callback.id;
    final rescheduleBusy =
        callback != null && busyRescheduleCallbackId == callback.id;
    final meetLink = callback?.link?.trim() ?? '';

    final cardBg = b == Brightness.dark
        ? ScenolyticsColors.actorCardSurfaceDark
        : ScenolyticsColors.actorCardSurfaceLight;
    final cardBorder = b == Brightness.dark
        ? ScenolyticsColors.actorCardBorderDark
        : ScenolyticsColors.actorCardBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: b == Brightness.dark ? 0.35 : 0.06,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _accentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _leftRankAccentGradient(entry.rank),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_accentWidth + 16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActorRankMedal(rank: entry.rank),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.actorName.trim().isEmpty ? '—' : s.actorName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (s.age > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Age: ${s.age}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _RankingSortChip(
                          sortBy: sortBy,
                          submission: s,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DirectorStatusLozenge(status: s.submissionStatus),
                        if (s.submissionStatus ==
                                AuditionSubmissionStatus.accepted &&
                            callbackStatus != null &&
                            callbackStatus != CallbackStatus.unknown)
                          CallbackStatusChip(status: callbackStatus),
                        if (showDirectorReview) ...[
                          FilledButton.icon(
                            onPressed: reviewBusy
                                ? null
                                : () => onDirectorAccept!.call(s),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: reviewBusy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded,
                                    size: 18),
                            label: Text(reviewBusy ? 'Saving…' : 'Accept'),
                          ),
                          OutlinedButton.icon(
                            onPressed: reviewBusy
                                ? null
                                : () => onDirectorReject!.call(s),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (s.submissionStatus == AuditionSubmissionStatus.accepted &&
                      callback != null) ...[
                    const SizedBox(height: 12),
                    _CallbackManagementSection(
                      callback: callback,
                      formatCallbackWhen: formatCallbackWhen,
                      meetLink: meetLink,
                      onOpenMeetLink: onOpenMeetLink,
                      showReviewActions: showCallbackReview,
                      reviewBusy: callbackBusy,
                      regenerateBusy: regenerateBusy,
                      rescheduleBusy: rescheduleBusy,
                      onRescheduleCallback: onRescheduleCallback,
                      onRegenerateMeetLink: onRegenerateMeetLink,
                      onConfirm: onCallbackConfirm,
                      onDecline: onCallbackDecline,
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final narrow = c.maxWidth < 360;
                      final metrics = isAudioOnly
                          ? <(String, int, Color)>[
                              (
                                'Vocal Emotion',
                                s.vocalToneScore,
                                ScenolyticsColors.metricVocalTone,
                              ),
                              (
                                'Script match',
                                s.scriptMatchScore,
                                ScenolyticsColors.metricScriptMatch,
                              ),
                            ]
                          : <(String, int, Color)>[
                              (
                                'Facial Emotions',
                                s.emotionalScore,
                                ScenolyticsColors.metricEmotional,
                              ),
                              (
                                'Vocal Emotion',
                                s.vocalToneScore,
                                ScenolyticsColors.metricVocalTone,
                              ),
                              (
                                'Script match',
                                s.scriptMatchScore,
                                ScenolyticsColors.metricScriptMatch,
                              ),
                            ];
                      final track = b == Brightness.dark
                          ? ScenolyticsColors.actorCardMetricTrackDark
                          : ScenolyticsColors.actorCardMetricTrackLight;

                      Widget cell(int i) {
                        final (label, value, color) = metrics[i];
                        return _ActorMetricBar(
                          label: label,
                          value: value,
                          barColor: color,
                          trackColor: track,
                        );
                      }

                      if (metrics.length == 2) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cell(0)),
                            const SizedBox(width: 10),
                            Expanded(child: cell(1)),
                          ],
                        );
                      }

                      if (narrow) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cell(0)),
                                const SizedBox(width: 10),
                                Expanded(child: cell(1)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cell(2)),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < metrics.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: cell(i)),
                          ],
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final open = onOpenSubmissionDetails;
                          if (open != null) {
                            open(s);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SubmissionEvaluationDetailsPage(
                                submission: s,
                                auditionType: auditionType,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.insights_outlined, size: 18),
                        label: const Text('More details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, fc) {
                      final stackFooter = fc.maxWidth < 320;
                      final submitted = Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatActorCardSubmitted(s.submittedAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      );
                      final watch = OutlinedButton.icon(
                        onPressed: () => _presentDirectorAuditionMedia(
                          context,
                          s,
                          isAudioOnly: isAudioOnly,
                        ),
                        icon: Icon(
                          isAudioOnly
                              ? Icons.headphones_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.65),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      if (stackFooter) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            submitted,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: watch,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: submitted),
                          watch,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static LinearGradient _leftRankAccentGradient(int rank) {
    return switch (rank) {
      1 => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD54F), Color(0xFFFF8C42)],
      ),
      2 => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ScenolyticsColors.rankSilver,
          ScenolyticsColors.rankSilver.withValues(alpha: 0.55),
        ],
      ),
      3 => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCD7F32), Color(0xFF8B5A2B)],
      ),
      _ => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [ScenolyticsColors.accentCyan, ScenolyticsColors.secondary],
      ),
    };
  }
}

String _formatActorCardSubmitted(DateTime utc) {
  final local = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Submitted: ${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _ActorRankMedal extends StatelessWidget {
  const _ActorRankMedal({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 48.0;

    if (rank <= 3) {
      final (Color iconColor, IconData icon) = switch (rank) {
        1 => (const Color(0xFFFFD700), Icons.emoji_events_rounded),
        2 => (const Color(0xFFC0C5CE), Icons.emoji_events_rounded),
        3 => (const Color(0xFFCD7F32), Icons.emoji_events_rounded),
        _ => (Colors.white, Icons.emoji_events_rounded),
      };

      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: ScenolyticsColors.rankMedalBackdrop,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 26),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _RankingSortChip extends StatelessWidget {
  const _RankingSortChip({
    required this.sortBy,
    required this.submission,
  });

  final AuditionRankingsSortBy sortBy;
  final ActorAuditionSubmission submission;

  @override
  Widget build(BuildContext context) {
    final tt = Tooltip(
      message: 'Ranking by ${sortBy.menuLabel}',
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: switch (sortBy) {
              AuditionRankingsSortBy.overall => ScenolyticsColors.overallScoreChip,
              AuditionRankingsSortBy.facialEmotion =>
                  ScenolyticsColors.metricEmotional,
              AuditionRankingsSortBy.vocalEmotion =>
                  ScenolyticsColors.metricVocalTone,
              AuditionRankingsSortBy.scriptMatch =>
                  ScenolyticsColors.metricScriptMatch,
            },
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            switch (sortBy) {
              AuditionRankingsSortBy.overall =>
                  submission.score.round().toString(),
              AuditionRankingsSortBy.facialEmotion =>
                  '${submission.emotionalScore}',
              AuditionRankingsSortBy.vocalEmotion =>
                  '${submission.vocalToneScore}',
              AuditionRankingsSortBy.scriptMatch =>
                  '${submission.scriptMatchScore}',
            },
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: sortBy == AuditionRankingsSortBy.scriptMatch
                  ? const Color(0xFF1E293B)
                  : ScenolyticsColors.overallScoreChipOn,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );

    return tt;
  }
}

class _DirectorStatusLozenge extends StatelessWidget {
  const _DirectorStatusLozenge({required this.status});

  final AuditionSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = auditionSubmissionStatusAccent(cs, status);
    final fg = auditionSubmissionStatusOnAccent(cs, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        auditionSubmissionStatusLabel(status),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ActorMetricBar extends StatelessWidget {
  const _ActorMetricBar({
    required this.label,
    required this.value,
    required this.barColor,
    required this.trackColor,
  });

  final String label;
  final int value;
  final Color barColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final v = value.clamp(0, 100) / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: trackColor,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
