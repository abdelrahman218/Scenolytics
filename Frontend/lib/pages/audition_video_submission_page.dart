import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../branding/scenolytics_branding.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

class AuditionVideoSubmissionPage extends StatefulWidget {
  const AuditionVideoSubmissionPage({
    super.key,
    required this.onSubmitted,
    required this.loggedInActorName,
    required this.loggedInActorAge,
    required this.auditionTitle,
    required this.auditionTheme,
    required this.directorName,
    required this.submissionCount,
    this.auditionWindowLabel = 'Open this week',
    this.slotLengthLabel = '2 min max',
  });

  final ValueChanged<ActorAuditionSubmission> onSubmitted;
  final String loggedInActorName;
  final int loggedInActorAge;
  final String auditionTitle;
  final String auditionTheme;
  final String directorName;
  final int submissionCount;
  final String auditionWindowLabel;
  final String slotLengthLabel;

  @override
  State<AuditionVideoSubmissionPage> createState() =>
      _AuditionVideoSubmissionPageState();
}

class _AuditionVideoSubmissionPageState extends State<AuditionVideoSubmissionPage> {
  bool _isSubmitting = false;
  bool _isInitializingCamera = false;
  bool _isRecording = false;
  bool _isPreviewing = false;
  bool _isFullScreenRecorderOpen = false;
  bool _hasSubmittedForAudition = false;
  CameraController? _cameraController;
  VideoPlayerController? _videoController;
  XFile? _recordedFile;
  ActorAuditionSubmission? _lastSubmission;

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraInitialized() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }
    setState(() {
      _isInitializingCamera = true;
    });
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      setState(() {
        _cameraController = controller;
        _isInitializingCamera = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: ${e.description ?? e.code}')),
      );
    }
  }

  Future<void> _startRecording() async {
    await _ensureCameraInitialized();
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isPreviewing = false;
        _recordedFile = null;
        _videoController?.dispose();
        _videoController = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start recording: ${e.description ?? e.code}',
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    try {
      final file = await controller.stopVideoRecording();
      await controller.dispose();
      final videoController = VideoPlayerController.networkUrl(Uri.parse(file.path));
      await videoController.initialize();
      videoController.setLooping(true);
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPreviewing = true;
        _recordedFile = file;
        _cameraController = null;
        _videoController?.dispose();
        _videoController = videoController;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to stop recording: ${e.description ?? e.code}',
          ),
        ),
      );
    }
  }

  Future<void> _openFullScreenRecorder() async {
    if (_hasSubmittedForAudition) return;
    if (_isFullScreenRecorderOpen) return;

    await _ensureCameraInitialized();
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isFullScreenRecorderOpen = true);

    if (!mounted) return;
    var dialogIsRecording = _isRecording;
    var countdown = 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDesktopLayout = MediaQuery.sizeOf(context).width >= 700;
            return Material(
              color: Colors.black,
              child: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isPhoneLayout = constraints.maxWidth < 700;
                        final controller = _cameraController!;
                        final previewSize = controller.value.previewSize;

                        if (!isPhoneLayout) {
                          // Desktop/laptop: preserve camera framing exactly.
                          return Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            ),
                          );
                        }

                        final width = previewSize?.height ?? constraints.maxWidth;
                        final height = previewSize?.width ?? constraints.maxHeight;
                        return ClipRect(
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: CameraPreview(controller),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (countdown > 0)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: Text(
                            '$countdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 84,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.62),
                              Colors.black.withValues(alpha: 0),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 26,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                child: isDesktopLayout
                                    ? DefaultTextStyle(
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        child: IconTheme(
                                          data: const IconThemeData(
                                            color: Colors.white,
                                          ),
                                          child: ScenolyticsBranding.of(context).logo,
                                        ),
                                      )
                                    : ScenolyticsBranding.of(context).logo,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Audition Recording',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: dialogIsRecording
                                    ? null
                                    : () async {
                                        for (var i = 5; i >= 1; i--) {
                                          setDialogState(() => countdown = i);
                                          await Future<void>.delayed(
                                            const Duration(seconds: 1),
                                          );
                                          if (!mounted) return;
                                        }
                                        setDialogState(() => countdown = 0);
                                        await _startRecording();
                                        if (!mounted) return;
                                        setDialogState(() {
                                          dialogIsRecording = true;
                                        });
                                      },
                                icon: const Icon(Icons.fiber_manual_record_rounded),
                                label: const Text('Start'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: dialogIsRecording
                                    ? () async {
                                        Navigator.of(ctx).pop();
                                        await _stopRecording();
                                      }
                                    : null,
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text('Stop'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _isFullScreenRecorderOpen = false);
  }

  Future<void> _submit() async {
    if (_hasSubmittedForAudition) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already submitted for this audition.'),
        ),
      );
      return;
    }
    if (_recordedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record your audition video first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    final submission = _buildSubmission();
    widget.onSubmitted(submission);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _hasSubmittedForAudition = true;
      _lastSubmission = submission;
      _isPreviewing = false;
      _recordedFile = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  ActorAuditionSubmission _buildSubmission() {
    final seedInput =
        '${widget.loggedInActorName}|${widget.auditionTitle}|${_recordedFile?.path ?? ''}';
    final seed = seedInput.codeUnits.fold<int>(0, (a, b) => a + b);
    final random = math.Random(seed);

    int nextMetric() => 65 + random.nextInt(34);
    final emotional = nextMetric();
    final vocalTone = nextMetric();
    final bodyLanguage = nextMetric();
    final scriptMatch = nextMetric();
    final score =
        (emotional * 0.3) + (vocalTone * 0.2) + (bodyLanguage * 0.25) + (scriptMatch * 0.25);

    return ActorAuditionSubmission(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      actorName: widget.loggedInActorName,
      auditionRole: widget.auditionTitle,
      score: score,
      submittedAt: DateTime.now().toUtc(),
      receivedCallback: score >= 88,
      age: widget.loggedInActorAge,
      emotionalScore: emotional,
      vocalToneScore: vocalTone,
      bodyLanguageScore: bodyLanguage,
      scriptMatchScore: scriptMatch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: b == Brightness.dark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF071019), Color(0xFF0A1A26)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3FBFE), Color(0xFFEAF5FB)],
              ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
        children: [
          _SubmissionHeroCard(
            theme: theme,
            auditionTitle: widget.auditionTitle,
            auditionTheme: widget.auditionTheme,
            directorName: widget.directorName,
            submissionCount: widget.submissionCount,
            auditionWindowLabel: widget.auditionWindowLabel,
            slotLengthLabel: widget.slotLengthLabel,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: b == Brightness.dark
                  ? const Color(0xFF0F1E2B).withValues(alpha: 0.92)
                  : cs.surface.withValues(alpha: 0.92),
              elevation: b == Brightness.dark ? 0 : 3,
              shadowColor: Colors.black.withValues(alpha: b == Brightness.dark ? 0 : 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(
                  color: b == Brightness.dark
                      ? cs.outline.withValues(alpha: 0.35)
                      : cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Video submission',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drop your best take. We will analyze it and send it to the director dashboard.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LoggedInActorSummary(
                      actorName: widget.loggedInActorName,
                      actorAge: widget.loggedInActorAge,
                    ),
                    const SizedBox(height: 14),
                    _RecordingCard(
                      cameraController: _cameraController,
                      videoController: _videoController,
                      isInitializing: _isInitializingCamera,
                      isRecording: _isRecording,
                      isPreviewing: _isPreviewing,
                      isLocked: _hasSubmittedForAudition,
                      onStartRecording: _startRecording,
                      onStopRecording: _stopRecording,
                      onRequestFullScreen: _openFullScreenRecorder,
                    ),
                    const SizedBox(height: 18),
                    if (!_hasSubmittedForAudition)
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_isSubmitting ? 'Analyzing...' : 'Submit for analysis'),
                      ),
                    if (_lastSubmission != null) ...[
                      const SizedBox(height: 14),
                      _SubmissionSuccessCard(
                        submission: _lastSubmission!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const ScenolyticsFooter(),
        ],
      ),
    );
  }
}

class _SubmissionHeroCard extends StatelessWidget {
  const _SubmissionHeroCard({
    required this.theme,
    required this.auditionTitle,
    required this.auditionTheme,
    required this.directorName,
    required this.submissionCount,
    required this.auditionWindowLabel,
    required this.slotLengthLabel,
  });

  final ThemeData theme;
  final String auditionTitle;
  final String auditionTheme;
  final String directorName;
  final int submissionCount;
  final String auditionWindowLabel;
  final String slotLengthLabel;

  @override
  Widget build(BuildContext context) {
    final onHero = ScenolyticsColors.onPrimary;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'AUDITION BRIEF',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, color: onHero.withValues(alpha: 0.9)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            auditionTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onHero,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload your audition video for AI analysis and director review.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onHero.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(icon: Icons.theater_comedy_outlined, label: auditionTheme),
              _HeroPill(icon: Icons.person_outline_rounded, label: 'Director: $directorName'),
              _HeroPill(icon: Icons.groups_2_outlined, label: '$submissionCount submissions'),
              _HeroPill(icon: Icons.schedule_outlined, label: auditionWindowLabel),
              _HeroPill(icon: Icons.timer_outlined, label: slotLengthLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Icon(Icons.person_rounded, size: 16, color: onHero),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Casting director: $directorName',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: textStyle?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionSuccessCard extends StatelessWidget {
  const _SubmissionSuccessCard({
    required this.submission,
  });

  final ActorAuditionSubmission submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.72),
            cs.tertiaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Submission sent',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your video was submitted successfully and shared with the director.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedInActorSummary extends StatelessWidget {
  const _LoggedInActorSummary({
    required this.actorName,
    required this.actorAge,
  });

  final String actorName;
  final int actorAge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$actorName • Age $actorAge',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.cameraController,
    required this.videoController,
    required this.isInitializing,
    required this.isRecording,
    required this.isPreviewing,
    required this.isLocked,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onRequestFullScreen,
  });

  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final bool isInitializing;
  final bool isRecording;
  final bool isPreviewing;
  final bool isLocked;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onRequestFullScreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview =
        isPreviewing && videoController != null && videoController!.value.isInitialized;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLocked)
            Text(
              'Submission sent. You have already submitted for this audition.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
          Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Record audition',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPreview) ...[
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(videoController!),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            videoController!.value.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            if (videoController!.value.isPlaying) {
                              videoController!.pause();
                            } else {
                              videoController!.play();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Builder(
            builder: (context) {
              if (!isRecording && !isPreviewing) {
                  return FilledButton.icon(
                    onPressed: onRequestFullScreen,
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: const Text('Start recording'),
                );
              }

              if (isRecording) {
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onStopRecording,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                );
              }

              // Preview: keep it single-line friendly, but allow wrapping.
              return Text(
                'Preview ready. Tap Submit below to send your audition.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                softWrap: true,
              );
            },
          ),
          ],
        ],
      ),
    );
  }
}

