import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/app_env.dart';
import '../data/api/casting_api.dart';
import '../data/repositories/auditions_repository.dart';
import '../branding/scenolytics_branding.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

class AuditionVideoSubmissionPage extends StatefulWidget {
  const AuditionVideoSubmissionPage({
    super.key,
    required this.onSubmitted,
    required this.auditionsRepository,
    required this.actorToken,
    required this.auditionId,
  });

  final ValueChanged<ActorAuditionSubmission> onSubmitted;
  final AuditionsRepository auditionsRepository;
  final String actorToken;
  final String auditionId;

  @override
  State<AuditionVideoSubmissionPage> createState() =>
      _AuditionVideoSubmissionPageState();
}

class _AuditionVideoSubmissionPageState
    extends State<AuditionVideoSubmissionPage> {
  bool _isSubmitting = false;
  bool _isCheckingExistingSubmission = true;
  bool _isInitializingCamera = false;
  bool _isRecording = false;
  bool _isPreviewing = false;
  bool _isFullScreenRecorderOpen = false;
  bool _hasSubmittedForAudition = false;
  bool _disposeCameraAfterDialog = false;
  CameraController? _cameraController;
  VideoPlayerController? _videoController;
  XFile? _recordedFile;
  ActorAuditionSubmission? _lastSubmission;
  String _requestedEmotion = '';
  String _auditionTitle = '';
  String _auditionTheme = '';
  String _directorName = '';
  String _auditionDescription = '';
  String _scriptPlainText = '';
  int _mySubmissionCountForAudition = 0;
  String _actorDisplayName = '';
  int? _actorAge;

  @override
  void initState() {
    super.initState();
    _checkExistingSubmission();
    _loadAuditionAndActorFromBackend();
  }

  Future<void> _loadAuditionAndActorFromBackend() async {
    await Future.wait([_loadAuditionUi(), _loadActorProfileFromBackend()]);
  }

  Future<void> _loadAuditionUi() async {
    final configError = AppEnv.validateActorSubmissionConfig();
    if (configError != null) return;
    try {
      final ui = await widget.auditionsRepository.loadActorSubmissionAuditionUi(
        actorToken: widget.actorToken,
        auditionId: widget.auditionId,
      );
      if (!mounted) return;
      setState(() {
        _auditionTitle = ui.titleLine;
        _auditionTheme = ui.themeLine;
        _auditionDescription = ui.description;
        _scriptPlainText = ui.scriptPlainText;
        _mySubmissionCountForAudition = ui.mySubmissionCountForAudition;
        if (ui.emotionsCsv.trim().isNotEmpty) {
          _requestedEmotion = ui.emotionsCsv;
        }
        final dn = ui.directorDisplayName?.trim();
        if (dn != null && dn.isNotEmpty) {
          _directorName = dn;
        }
      });
    } catch (_) {
      // Leave labels empty when casting/user-management data is unavailable.
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSubmission() async {
    final configError = AppEnv.validateActorSubmissionConfig();
    if (configError != null) {
      if (!mounted) return;
      setState(() {
        _isCheckingExistingSubmission = false;
      });
      return;
    }
    try {
      final alreadySubmitted = await widget.auditionsRepository
          .hasActorSubmittedForAudition(
            actorToken: widget.actorToken,
            auditionId: widget.auditionId,
          );
      if (!mounted) return;
      setState(() {
        _hasSubmittedForAudition = alreadySubmitted;
        _isCheckingExistingSubmission = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingExistingSubmission = false;
      });
    }
  }

  Future<void> _loadActorProfileFromBackend() async {
    if (widget.actorToken.trim().isEmpty) return;
    try {
      final profile = await widget.auditionsRepository.loadActorProfileUi(
        widget.actorToken,
      );
      if (!mounted || profile == null) return;
      setState(() {
        final name = profile.displayName;
        if (name != null && name.isNotEmpty) {
          _actorDisplayName = name;
        }
        _actorAge = profile.age;
      });
    } catch (_) {}
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
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(file.path),
      );
      await videoController.initialize();
      videoController.setLooping(true);
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPreviewing = true;
        _recordedFile = file;
        _videoController?.dispose();
        _videoController = videoController;
      });

      // If we're inside fullscreen dialog, dispose after dialog closes to avoid
      // CameraPreview building on a disposed controller for one frame.
      if (_isFullScreenRecorderOpen) {
        _disposeCameraAfterDialog = true;
      } else {
        await controller.dispose();
        if (!mounted) return;
        setState(() {
          _cameraController = null;
        });
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to stop recording: ${e.description ?? e.code}'),
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

                        final width =
                            previewSize?.height ?? constraints.maxWidth;
                        final height =
                            previewSize?.width ?? constraints.maxHeight;
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
                                          child: ScenolyticsBranding.of(
                                            context,
                                          ).logo,
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
                                icon: const Icon(
                                  Icons.fiber_manual_record_rounded,
                                ),
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

    if (_disposeCameraAfterDialog && _cameraController != null) {
      final controller = _cameraController!;
      await controller.dispose();
      _disposeCameraAfterDialog = false;
      if (!mounted) return;
      setState(() {
        _cameraController = null;
      });
    }

    if (!mounted) return;
    setState(() => _isFullScreenRecorderOpen = false);
  }

  Future<void> _copyScriptToClipboard() async {
    final body = _scriptPlainText.trim();
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No script lines are available for this audition yet.'),
        ),
      );
      return;
    }
    final title = _auditionTitle.trim().isEmpty
        ? 'Audition script'
        : _auditionTitle.trim();
    final header = '$title\nID: ${widget.auditionId}';
    await Clipboard.setData(ClipboardData(text: '$header\n\n$body'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Script copied. Paste into a document to save or print.'),
      ),
    );
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
    final configError = AppEnv.validateActorSubmissionConfig();
    if (configError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$configError See AppEnv / .vscode/launch.json.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bytes = await _recordedFile!.readAsBytes();
      final submission = await widget.auditionsRepository
          .submitRecordedAudition(
            actorToken: widget.actorToken,
            auditionId: widget.auditionId,
            actorName: _actorDisplayName,
            actorAge: _actorAge ?? 0,
            auditionTitle: _auditionTitle,
            videoBytes: bytes,
          );

      if (!mounted) return;
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
      await _loadAuditionUi();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit video. Please try again.'),
        ),
      );
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubmissionHeroCard(
                    theme: theme,
                    auditionTitle: _auditionTitle,
                    heroBlurb: _auditionDescription.trim().isNotEmpty
                        ? _auditionDescription.trim()
                        : 'Upload your audition video for AI analysis and director review.',
                    auditionTheme: _auditionTheme,
                    requestedEmotion: _requestedEmotion,
                    directorName: _directorName,
                    mySubmissionCount: _mySubmissionCountForAudition,
                    onDownloadScript: () {
                      _copyScriptToClipboard();
                    },
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: b == Brightness.dark
                        ? const Color(0xFF0F1E2B).withValues(alpha: 0.92)
                        : cs.surface.withValues(alpha: 0.92),
                    elevation: b == Brightness.dark ? 0 : 3,
                    shadowColor: Colors.black.withValues(
                      alpha: b == Brightness.dark ? 0 : 0.08,
                    ),
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
                            _auditionDescription.trim().isNotEmpty
                                ? _auditionDescription.trim()
                                : 'Record your strongest take with confidence. Your performance will be analyzed and delivered to the director dashboard.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LoggedInActorSummary(
                            actorName: _actorDisplayName,
                            actorAge: _actorAge,
                          ),
                          const SizedBox(height: 14),
                          if (_isCheckingExistingSubmission)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
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
                          if (!_hasSubmittedForAudition &&
                              !_isCheckingExistingSubmission)
                            FilledButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(
                                _isSubmitting
                                    ? 'Analyzing...'
                                    : 'Submit for analysis',
                              ),
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
                ],
              ),
            ),
          ),
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
    required this.heroBlurb,
    required this.auditionTheme,
    required this.requestedEmotion,
    required this.directorName,
    required this.mySubmissionCount,
    required this.onDownloadScript,
  });

  final ThemeData theme;
  final String auditionTitle;
  final String heroBlurb;
  final String auditionTheme;
  final String requestedEmotion;
  final String directorName;
  final int mySubmissionCount;
  final VoidCallback onDownloadScript;

  String _subtitleLine() {
    final parts = <String>[];
    final themeT = auditionTheme.trim();
    final emo = requestedEmotion.trim();
    if (themeT.isNotEmpty) parts.add(themeT);
    if (emo.isNotEmpty) parts.add('Requested emotion: $emo');
    if (parts.isEmpty) return heroBlurb.trim();
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final b = theme.brightness;
    final cs = theme.colorScheme;
    final onHero = ScenolyticsColors.onPrimary;

    final decoration = BoxDecoration(
      gradient: b == Brightness.dark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF021A2E),
                ScenolyticsColors.heroGradientStart,
                Color(0xFF052F45),
              ],
            )
          : ScenolyticsColors.heroBarGradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: onHero.withValues(alpha: b == Brightness.dark ? 0.12 : 0.2),
      ),
      boxShadow: [
        BoxShadow(
          color: cs.shadow.withValues(
            alpha: b == Brightness.dark ? 0.35 : 0.12,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final subtitle = _subtitleLine();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: decoration,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.movie_filter_rounded, color: onHero, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Actor submission',
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
              if (directorName.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  directorName.trim(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onHero.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                auditionTitle.trim().isEmpty ? '—' : auditionTitle.trim(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
                    size: 18,
                    color: onHero.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle.isEmpty ? '—' : subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onHero.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Submissions: $mySubmissionCount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onHero.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _HeroScriptDownloadChip(onPressed: onDownloadScript),
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

/// Same chrome as director rankings filter: gradient pill + “Download script”
/// on every platform (web and phone).
class _HeroScriptDownloadChip extends StatelessWidget {
  const _HeroScriptDownloadChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return Tooltip(
      message: 'Download script',
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: ScenolyticsColors.webRankingsFilterGradientEnd.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: ScenolyticsColors.webRankingsFilterGradient,
              borderRadius: BorderRadius.all(Radius.circular(radius)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: ScenolyticsColors.webRankingsFilterForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Download script',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: ScenolyticsColors.webRankingsFilterForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmissionSuccessCard extends StatelessWidget {
  const _SubmissionSuccessCard({required this.submission});

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
  final int? actorAge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = actorName.trim().isEmpty ? '—' : actorName.trim();
    final agePart = actorAge != null ? ' • Age $actorAge' : '';
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
              '$name$agePart',
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
        isPreviewing &&
        videoController != null &&
        videoController!.value.isInitialized;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
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
                Icon(Icons.videocam_rounded, color: theme.colorScheme.primary),
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
