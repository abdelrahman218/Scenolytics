import 'dart:async';

import 'package:camera/camera.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../config/app_env.dart';
import '../data/api/casting_api.dart';
import '../data/repositories/auditions_repository.dart';
import '../branding/scenolytics_branding.dart';
import '../models/actor_audition_submission.dart';
import '../models/actor_callback.dart';
import '../models/callback_status.dart';
import '../widgets/audio_recorder_card.dart';
import '../widgets/callback_status_chips.dart';
import '../models/audition_submission_status.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';

enum _SubmissionRecordingGate {
  open,
  pendingReview,
  accepted,
  rejected,
}

class AuditionVideoSubmissionPage extends StatefulWidget {
  const AuditionVideoSubmissionPage({
    super.key,
    required this.onSubmitted,
    required this.auditionsRepository,
    required this.actorToken,
    required this.auditionId,
    this.accountEmail,
  });

  final ValueChanged<ActorAuditionSubmission> onSubmitted;
  final AuditionsRepository auditionsRepository;
  final String actorToken;
  final String auditionId;

  /// From Identity sign-in; used when User Management has no actor profile yet.
  final String? accountEmail;

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

  Duration _videoRecordElapsed = Duration.zero;
  Timer? _videoRecordTicker;

  Uint8List? _recordedAudioBytes;

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

  /// Casting `auditions.type` ('Audio' or 'Video'). Empty until the casting
  /// detail loads. Empty defaults to video for backwards compatibility.
  String _auditionType = '';

  bool get _isAudioOnly => _auditionType.trim().toLowerCase() == 'audio';

  /// From casting list API for this audition (when returning to the page).
  AuditionSubmissionStatus? _serverSubmissionStatus;

  /// Resolved from [AuditionVideoSubmissionPage.auditionId], casting API, then
  /// optional compile-time [AppEnv.auditionId].
  String _effectiveAuditionId = '';

  bool _isResolvingAuditionId = false;

  List<ActorCallbackInfo> _actorCallbacks = const [];

  _SubmissionRecordingGate get _recordingGate {
    if (!_hasSubmittedForAudition) return _SubmissionRecordingGate.open;
    final s = _lastSubmission?.submissionStatus ??
        _serverSubmissionStatus ??
        AuditionSubmissionStatus.pending;
    if (s == AuditionSubmissionStatus.rejected) {
      return _SubmissionRecordingGate.rejected;
    }
    if (s == AuditionSubmissionStatus.accepted) {
      return _SubmissionRecordingGate.accepted;
    }
    return _SubmissionRecordingGate.pendingReview;
  }

  ActorCallbackInfo? get _callbackForThisAudition {
    final aid = _effectiveAuditionId.trim();
    if (aid.isEmpty) return null;
    final matches =
        _actorCallbacks.where((c) => c.auditionId == aid).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return matches.first;
  }

  String _formatCallbackDate(DateTime dt) {
    String p2(int n) => n.toString().padLeft(2, '0');
    final l = dt.toLocal();
    return '${l.year}-${p2(l.month)}-${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  Future<void> _openMeetLink(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !(uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid meeting link is available yet.'),
        ),
      );
      return;
    }
    final ok =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _effectiveAuditionId = widget.auditionId.trim();
    final needsResolve =
        _effectiveAuditionId.isEmpty && widget.actorToken.trim().isNotEmpty;
    _isResolvingAuditionId = needsResolve;
    if (needsResolve) {
      _resolveAuditionThenContinue();
      return;
    }
    _applyCompileTimeAuditionFallbackIfNeeded();
    _afterAuditionIdReady();
  }

  /// When the shell had no audition id yet, casting supplies one (invite → catalog → submissions).
  Future<void> _resolveAuditionThenContinue() async {
    try {
      final id = await widget.auditionsRepository.resolveDefaultActorAuditionId(
        actorToken: widget.actorToken,
      );
      if (!mounted) return;
      final trimmed = id?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        _effectiveAuditionId = trimmed;
      } else {
        _applyCompileTimeAuditionFallbackIfNeeded();
      }
    } catch (_) {
      if (!mounted) return;
      _applyCompileTimeAuditionFallbackIfNeeded();
    }
    if (!mounted) return;
    setState(() => _isResolvingAuditionId = false);
    await _afterAuditionIdReady();
  }

  void _applyCompileTimeAuditionFallbackIfNeeded() {
    if (_effectiveAuditionId.isNotEmpty) return;
    final envId = AppEnv.auditionId.trim();
    if (envId.isNotEmpty) {
      _effectiveAuditionId = envId;
    }
  }

  Future<void> _afterAuditionIdReady() async {
    await Future.wait([
      _checkExistingSubmission(),
      _loadAuditionAndActorFromBackend(),
    ]);
  }

  Future<void> _loadAuditionAndActorFromBackend() async {
    await Future.wait([
      _loadAuditionUi(),
      _loadActorProfileFromBackend(),
      _loadActorCallbacks(),
    ]);
  }

  Future<void> _loadActorCallbacks() async {
    if (widget.actorToken.trim().isEmpty) return;
    try {
      final list = await widget.auditionsRepository.loadActorCallbacks(
        actorToken: widget.actorToken,
      );
      if (!mounted) return;
      setState(() => _actorCallbacks = list);
    } catch (_) {}
  }

  Future<void> _loadAuditionUi() async {
    final configError = AppEnv.validateActorSubmissionFor(
      actorToken: widget.actorToken,
      auditionId: _effectiveAuditionId,
    );
    if (configError != null) return;
    try {
      final ui = await widget.auditionsRepository.loadActorSubmissionAuditionUi(
        actorToken: widget.actorToken,
        auditionId: _effectiveAuditionId,
      );
      if (!mounted) return;
      setState(() {
        _auditionTitle = ui.titleLine;
        _auditionTheme = ui.themeLine;
        _auditionDescription = ui.description;
        _scriptPlainText = ui.scriptPlainText;
        _mySubmissionCountForAudition = ui.mySubmissionCountForAudition;
        _serverSubmissionStatus = ui.myLatestSubmissionStatus;
        _auditionType = ui.auditionType;
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

  Widget? _buildPipelineStatusBanner(ThemeData theme, ColorScheme cs) {
    if (_isSubmitting) {
      return _pipelineStatusCard(
        theme,
        cs,
        title: 'Uploading your video',
        subtitle:
            'Your file is being transferred securely. Keep this screen open.',
        leading: Icons.cloud_upload_rounded,
        fg: cs.onPrimaryContainer,
        bg: cs.primaryContainer,
      );
    }
    final status =
        _lastSubmission?.submissionStatus ?? _serverSubmissionStatus;
    if (status == null) return null;

    final (String title, String subtitle, IconData icon, Color fg, Color bg) =
        switch (status) {
      AuditionSubmissionStatus.pending => (
          'Pending',
          'Your recording is ingested; automated scoring runs next.',
          Icons.hourglass_top_rounded,
          cs.onTertiaryContainer,
          cs.tertiaryContainer,
        ),
      AuditionSubmissionStatus.underReview => (
          'Under review',
          'The casting team is reviewing your performance.',
          Icons.visibility_rounded,
          cs.onPrimaryContainer,
          cs.primaryContainer,
        ),
      AuditionSubmissionStatus.accepted => (
          'Accepted',
          'The director accepted your audition.',
          Icons.verified_rounded,
          cs.onSecondaryContainer,
          cs.secondaryContainer,
        ),
      AuditionSubmissionStatus.rejected => (
          'Rejected',
          'This audition was not selected. You can explore other roles.',
          Icons.highlight_off_rounded,
          cs.onErrorContainer,
          cs.errorContainer,
        ),
      AuditionSubmissionStatus.unknown => (
          'Submission',
          'Status will update when the server finishes processing.',
          Icons.info_outline_rounded,
          cs.onSurfaceVariant,
          cs.surfaceContainerHighest,
        ),
    };

    return _pipelineStatusCard(
      theme,
      cs,
      title: title,
      subtitle: subtitle,
      leading: icon,
      fg: fg,
      bg: bg,
    );
  }

  Widget _pipelineStatusCard(
    ThemeData theme,
    ColorScheme cs, {
    required String title,
    required String subtitle,
    required IconData leading,
    required Color fg,
    required Color bg,
  }) {
    return Material(
      color: bg,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(leading, color: fg, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg.withValues(alpha: 0.92),
                      height: 1.35,
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

  @override
  void dispose() {
    _videoRecordTicker?.cancel();
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _startVideoTimer() {
    _videoRecordTicker?.cancel();
    _videoRecordElapsed = Duration.zero;
    _videoRecordTicker =
        Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _videoRecordElapsed += const Duration(milliseconds: 200);
      });
    });
  }

  void _stopVideoTimer() {
    _videoRecordTicker?.cancel();
    _videoRecordTicker = null;
  }

  Future<void> _checkExistingSubmission() async {
    final configError = AppEnv.validateActorSubmissionFor(
      actorToken: widget.actorToken,
      auditionId: _effectiveAuditionId,
    );
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
            auditionId: _effectiveAuditionId,
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
    String? displayName;
    int? age;
    try {
      final profile = await widget.auditionsRepository.loadActorProfileUi(
        widget.actorToken,
      );
      if (profile != null) {
        displayName = profile.displayName;
        age = profile.age;
      }
    } catch (_) {}
    final email = widget.accountEmail?.trim() ?? '';
    if ((displayName == null || displayName.isEmpty) && email.isNotEmpty) {
      displayName = _displayNameFromAccountEmail(email);
    }
    if (!mounted) return;
    setState(() {
      if (displayName != null && displayName.isNotEmpty) {
        _actorDisplayName = displayName;
      }
      if (age != null) {
        _actorAge = age;
      }
    });
  }

  /// Local part of email when there is no `actor_profiles` row yet.
  String _displayNameFromAccountEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) {
      return email;
    }
    return email.substring(0, at);
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
      _startVideoTimer();
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
      _stopVideoTimer();
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
    if (_recordingGate != _SubmissionRecordingGate.open) return;
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

  String _sanitizedScriptPdfBasename() {
    var base = _auditionTitle
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (base.isEmpty) base = 'audition_script';
    if (base.length > 64) base = base.substring(0, 64);
    return base;
  }

  Future<void> _downloadScriptAsPdf() async {
    final configError = AppEnv.validateActorSubmissionFor(
      actorToken: widget.actorToken,
      auditionId: _effectiveAuditionId,
    );
    if (configError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(configError)));
      return;
    }

    try {
      final bytes =
          await widget.auditionsRepository.downloadActorAuditionScriptPdf(
        actorToken: widget.actorToken,
        auditionId: _effectiveAuditionId,
      );
      final base = _sanitizedScriptPdfBasename();

      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Script downloaded as PDF.'),
          action: SnackBarAction(
            label: 'Copy text',
            onPressed: _copyPlainScriptToClipboard,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download script (${e.runtimeType}).'),
        ),
      );
    }
  }

  Future<void> _copyPlainScriptToClipboard() async {
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
    final header = '$title\nID: $_effectiveAuditionId';
    await Clipboard.setData(ClipboardData(text: '$header\n\n$body'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Plain script copied — paste elsewhere if you need the raw text.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_recordingGate != _SubmissionRecordingGate.open) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a submission on file for this audition.'),
        ),
      );
      return;
    }
    final Uint8List? bytes = _isAudioOnly
        ? _recordedAudioBytes
        : (await _recordedFile?.readAsBytes());

    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAudioOnly
                ? 'Record your audition audio first.'
                : 'Record your audition video first.',
          ),
        ),
      );
      return;
    }
    final configError = AppEnv.validateActorSubmissionFor(
      actorToken: widget.actorToken,
      auditionId: _effectiveAuditionId,
    );
    if (!mounted) return;
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
      final outcome = await widget.auditionsRepository.submitRecordedAudition(
        actorToken: widget.actorToken,
        auditionId: _effectiveAuditionId,
        actorName: _actorDisplayName,
        actorAge: _actorAge ?? 0,
        auditionTitle: _auditionTitle,
        videoBytes: bytes,
      );

      if (!mounted) return;
      widget.onSubmitted(outcome.submission);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _hasSubmittedForAudition = true;
        _lastSubmission = outcome.submission;
        _isPreviewing = false;
        _recordedFile = null;
        _recordedAudioBytes = null;
        _videoController?.dispose();
        _videoController = null;
      });

      await _loadAuditionUi();
      await _loadActorCallbacks();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (s) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;
    final pipelineBanner = _buildPipelineStatusBanner(theme, cs);

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
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubmissionHeroCard(
                    theme: theme,
                    auditionTitle: _auditionTitle,
                    heroBlurb: _auditionDescription.trim().isNotEmpty
                        ? _auditionDescription.trim()
                        : (_isAudioOnly
                            ? 'Upload your audition audio for AI analysis and director review.'
                            : 'Upload your audition video for AI analysis and director review.'),
                    auditionTheme: _auditionTheme,
                    requestedEmotion: _requestedEmotion,
                    directorName: _directorName,
                    mySubmissionCount: _mySubmissionCountForAudition,
                    onDownloadScript: _downloadScriptAsPdf,
                    isAudioOnly: _isAudioOnly,
                  ),
                  if (pipelineBanner != null) ...[
                    const SizedBox(height: 16),
                    pipelineBanner,
                  ],
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
                          Row(
                            children: [
                              _SubmissionModeBadge(isAudioOnly: _isAudioOnly),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isAudioOnly
                                      ? 'Audio submission'
                                      : 'Video submission',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _auditionDescription.trim().isNotEmpty
                                ? _auditionDescription.trim()
                                : (_isAudioOnly
                                    ? 'Record your strongest vocal take. Your performance will be analyzed for tone and emotion, then sent to the director.'
                                    : 'Record your strongest take with confidence. Your performance will be analyzed and delivered to the director dashboard.'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _LoggedInActorSummary(
                            actorName: _actorDisplayName,
                            actorAge: _actorAge,
                          ),
                          const SizedBox(height: 14),
                          if (_isResolvingAuditionId ||
                              _isCheckingExistingSubmission)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_effectiveAuditionId.trim().isEmpty &&
                              widget.actorToken.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Could not resolve an audition from the server '
                                '(no invitations or catalog rows). Pick one '
                                'under Explore Auditions, or set compile-time '
                                'SCENO_AUDITION_ID.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          else if (_isAudioOnly)
                            _recordingGate ==
                                    _SubmissionRecordingGate.open
                                ? AudioRecorderCard(
                                    enabled: true,
                                    onRecordingReady: (bytes) {
                                      setState(
                                          () => _recordedAudioBytes = bytes);
                                    },
                                  )
                                : _SubmissionPostRecordPanel(
                                    recordingGate: _recordingGate,
                                    isAudioOnly: true,
                                    callbackScheduledAt:
                                        _callbackForThisAudition
                                            ?.callbackDatetime,
                                    callbackStatus: _callbackForThisAudition
                                        ?.callbackStatus,
                                    callbackMeetLink:
                                        _callbackForThisAudition?.link,
                                    formatCallbackDate: _formatCallbackDate,
                                    onOpenMeetLink: () {
                                      final link = _callbackForThisAudition
                                              ?.link
                                              ?.trim() ??
                                          '';
                                      if (link.isNotEmpty) {
                                        _openMeetLink(link);
                                      }
                                    },
                                  )
                          else
                            _RecordingCard(
                              cameraController: _cameraController,
                              videoController: _videoController,
                              isInitializing: _isInitializingCamera,
                              isRecording: _isRecording,
                              isPreviewing: _isPreviewing,
                              recordingGate: _recordingGate,
                              recordingElapsed: _videoRecordElapsed,
                              callbackScheduledAt:
                                  _callbackForThisAudition?.callbackDatetime,
                              callbackStatus:
                                  _callbackForThisAudition?.callbackStatus,
                              callbackMeetLink:
                                  _callbackForThisAudition?.link,
                              onStartRecording: _startRecording,
                              onStopRecording: _stopRecording,
                              onRequestFullScreen: _openFullScreenRecorder,
                              formatCallbackDate: _formatCallbackDate,
                              onOpenMeetLink: () {
                                final link =
                                    _callbackForThisAudition?.link?.trim() ??
                                        '';
                                if (link.isNotEmpty) _openMeetLink(link);
                              },
                            ),
                          const SizedBox(height: 18),
                          if (_recordingGate ==
                                  _SubmissionRecordingGate.open &&
                              !_isResolvingAuditionId &&
                              !_isCheckingExistingSubmission &&
                              _effectiveAuditionId.trim().isNotEmpty)
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
    this.isAudioOnly = false,
  });

  final ThemeData theme;
  final String auditionTitle;
  final String heroBlurb;
  final String auditionTheme;
  final String requestedEmotion;
  final String directorName;
  final int mySubmissionCount;
  final VoidCallback onDownloadScript;
  final bool isAudioOnly;

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
                  Icon(
                    isAudioOnly
                        ? Icons.graphic_eq_rounded
                        : Icons.movie_filter_rounded,
                    color: onHero,
                    size: 30,
                  ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: onHero.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: onHero.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAudioOnly
                              ? Icons.mic_rounded
                              : Icons.videocam_rounded,
                          color: onHero,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAudioOnly ? 'AUDIO' : 'VIDEO',
                          style: TextStyle(
                            color: onHero,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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
            isAudioOnly
                ? Icons.graphic_eq_rounded
                : Icons.movie_filter_rounded,
            size: 96,
            color: onHero.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

/// Same chrome as director rankings filter: gradient pill — saves script as PDF.
class _HeroScriptDownloadChip extends StatelessWidget {
  const _HeroScriptDownloadChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return Tooltip(
      message: 'Download audition script as a PDF',
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
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: ScenolyticsColors.webRankingsFilterForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Download script (PDF)',
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

/// Shown after submit when recording is closed — callback time, Meet link, etc.
/// Used for both audio and video submission pages.
class _SubmissionPostRecordPanel extends StatelessWidget {
  const _SubmissionPostRecordPanel({
    required this.recordingGate,
    required this.isAudioOnly,
    this.callbackScheduledAt,
    this.callbackStatus,
    this.callbackMeetLink,
    required this.formatCallbackDate,
    required this.onOpenMeetLink,
  });

  final _SubmissionRecordingGate recordingGate;
  final bool isAudioOnly;
  final DateTime? callbackScheduledAt;
  final CallbackStatus? callbackStatus;
  final String? callbackMeetLink;
  final String Function(DateTime dt) formatCallbackDate;
  final VoidCallback onOpenMeetLink;

  String get _callbackHeadline {
    switch (callbackStatus) {
      case CallbackStatus.accepted:
        return 'Callback accepted';
      case CallbackStatus.rejected:
        return 'Callback declined';
      case CallbackStatus.scheduled:
      case CallbackStatus.unknown:
      case null:
        return 'Callback scheduled';
    }
  }

  String get _callbackBodyText {
    switch (callbackStatus) {
      case CallbackStatus.rejected:
        return 'This callback was declined or cancelled. You can explore other '
            'roles from Explore Auditions.';
      case CallbackStatus.accepted:
        if (callbackScheduledAt != null) {
          return 'Your callback is confirmed. Join at the scheduled time below.';
        }
        return 'Your callback was accepted.';
      case CallbackStatus.scheduled:
      case CallbackStatus.unknown:
      case null:
        if (callbackScheduledAt != null) {
          return 'Scheduled for ${formatCallbackDate(callbackScheduledAt!)}';
        }
        return 'Your audition was accepted. Callback scheduling details will '
            'appear here once they are saved.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final meet =
        callbackMeetLink?.trim().isNotEmpty ?? false ? callbackMeetLink!.trim() : '';

    final bg = isDark
        ? const Color(0xFF0B1A26)
        : cs.surface.withValues(alpha: 0.92);
    final border = isDark
        ? cs.outline.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.18),
                      ScenolyticsColors.accentCyan.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAudioOnly
                      ? Icons.graphic_eq_rounded
                      : Icons.videocam_rounded,
                  color: cs.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAudioOnly ? 'Audio submission' : 'Video submission',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recordingGate == _SubmissionRecordingGate.rejected)
            _GateRow(
              icon: Icons.highlight_off_rounded,
              iconColor: cs.error,
              text:
                  'This audition was not selected. You can explore other roles from Explore Auditions.',
            )
          else if (recordingGate == _SubmissionRecordingGate.accepted)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.celebration_rounded,
                        color: cs.primary, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _callbackHeadline,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (callbackStatus != null &&
                        callbackStatus != CallbackStatus.unknown)
                      CallbackStatusChip(
                        status: callbackStatus!,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _callbackBodyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (callbackScheduledAt != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(
                        alpha: isDark ? 0.45 : 0.65,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          color: cs.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Callback time',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onPrimaryContainer
                                      .withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCallbackDate(callbackScheduledAt!),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (meet.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpenMeetLink,
                    icon: const Icon(Icons.video_camera_front_outlined),
                    label: const Text('Join Meet link'),
                  ),
                ] else if (callbackScheduledAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'A Google Meet link will show here after your director '
                    'connects Calendar and generates the invite.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            )
          else
            _GateRow(
              icon: Icons.hourglass_top_rounded,
              iconColor: cs.primary,
              text:
                  'Submission sent. The director is reviewing it now — you’ll see status updates above.',
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
    required this.recordingGate,
    required this.recordingElapsed,
    this.callbackScheduledAt,
    this.callbackStatus,
    this.callbackMeetLink,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onRequestFullScreen,
    required this.formatCallbackDate,
    required this.onOpenMeetLink,
  });

  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final bool isInitializing;
  final bool isRecording;
  final bool isPreviewing;
  final _SubmissionRecordingGate recordingGate;
  final Duration recordingElapsed;
  final DateTime? callbackScheduledAt;
  final CallbackStatus? callbackStatus;
  final String? callbackMeetLink;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onRequestFullScreen;
  final String Function(DateTime dt) formatCallbackDate;
  final VoidCallback onOpenMeetLink;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasPreview =
        isPreviewing &&
        videoController != null &&
        videoController!.value.isInitialized;

    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF0B1A26)
        : theme.colorScheme.surface.withValues(alpha: 0.92);
    final border = isDark
        ? cs.outline.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VideoCardTitle(isRecording: isRecording),
          const SizedBox(height: 14),
          if (recordingGate != _SubmissionRecordingGate.open)
            _SubmissionPostRecordPanel(
              recordingGate: recordingGate,
              isAudioOnly: false,
              callbackScheduledAt: callbackScheduledAt,
              callbackStatus: callbackStatus,
              callbackMeetLink: callbackMeetLink,
              formatCallbackDate: formatCallbackDate,
              onOpenMeetLink: onOpenMeetLink,
            )
          else if (isInitializing) ...[
            const SizedBox(
              height: 168,
              child: Center(
                child: SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ] else ...[
            _VideoStage(
              cameraController: cameraController,
              videoController: videoController,
              isRecording: isRecording,
              isPreviewing: isPreviewing,
              hasPreview: hasPreview,
              recordingElapsed: _formatDuration(recordingElapsed),
            ),
            const SizedBox(height: 14),
            _VideoActions(
              isRecording: isRecording,
              isPreviewing: isPreviewing,
              hasPreview: hasPreview,
              onRequestFullScreen: onRequestFullScreen,
              onStopRecording: onStopRecording,
            ),
            if (!isRecording && !isPreviewing) ...[
              const SizedBox(height: 8),
              Text(
                'Find a well-lit, quiet space and look into the camera for your take.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ] else if (hasPreview) ...[
              const SizedBox(height: 8),
              Text(
                'Preview ready. Tap Submit below to send your audition.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _VideoCardTitle extends StatelessWidget {
  const _VideoCardTitle({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.18),
                ScenolyticsColors.accentCyan.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.videocam_rounded, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Video recording',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFE53935).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _SmallBlinkingDot(),
                SizedBox(width: 6),
                Text(
                  'REC',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SmallBlinkingDot extends StatefulWidget {
  const _SmallBlinkingDot();

  @override
  State<_SmallBlinkingDot> createState() => _SmallBlinkingDotState();
}

class _SmallBlinkingDotState extends State<_SmallBlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE53935)
                .withValues(alpha: 0.5 + 0.5 * _ctrl.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.cameraController,
    required this.videoController,
    required this.isRecording,
    required this.isPreviewing,
    required this.hasPreview,
    required this.recordingElapsed,
  });

  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final bool isRecording;
  final bool isPreviewing;
  final bool hasPreview;
  final String recordingElapsed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = hasPreview
        ? _PreviewBody(controller: videoController!)
        : _IdleStage(isRecording: isRecording);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            if (isRecording)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SmallBlinkingDot(),
                      const SizedBox(width: 6),
                      Text(
                        recordingElapsed,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
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
  }
}

class _IdleStage extends StatelessWidget {
  const _IdleStage({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1A26), Color(0xFF103047)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording
                  ? Icons.fiber_manual_record_rounded
                  : Icons.videocam_outlined,
              color: Colors.white.withValues(alpha: 0.85),
              size: 56,
            ),
            const SizedBox(height: 10),
            Text(
              isRecording
                  ? 'Recording in full screen…'
                  : 'Tap “Start recording” to capture a take',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBody extends StatefulWidget {
  const _PreviewBody({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends State<_PreviewBody> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
        if (!c.value.isPlaying)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        Center(
          child: Material(
            color: Colors.black.withValues(alpha: 0.4),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (c.value.isPlaying) {
                  c.pause();
                } else {
                  c.play();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  c.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoActions extends StatelessWidget {
  const _VideoActions({
    required this.isRecording,
    required this.isPreviewing,
    required this.hasPreview,
    required this.onRequestFullScreen,
    required this.onStopRecording,
  });

  final bool isRecording;
  final bool isPreviewing;
  final bool hasPreview;
  final VoidCallback onRequestFullScreen;
  final VoidCallback onStopRecording;

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
        onPressed: onStopRecording,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Stop recording'),
      );
    }
    if (hasPreview || isPreviewing) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      onPressed: onRequestFullScreen,
      icon: const Icon(Icons.fiber_manual_record_rounded),
      label: const Text('Start recording'),
    );
  }
}

class _SubmissionModeBadge extends StatelessWidget {
  const _SubmissionModeBadge({required this.isAudioOnly});

  final bool isAudioOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.18),
            ScenolyticsColors.accentCyan.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isAudioOnly ? Icons.graphic_eq_rounded : Icons.videocam_rounded,
        color: cs.primary,
        size: 22,
      ),
    );
  }
}
