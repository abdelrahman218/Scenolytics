import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../theme/scenolytics_colors.dart';

/// Audio-only recording experience for audio auditions.
///
/// Owns its own mic state, amplitude history, waveform animation and preview
/// player. When the actor finishes recording, [onRecordingReady] receives the
/// raw bytes plus a playback URL/path the widget can also use internally.
///
/// Disabled while [enabled] is false (e.g. the audition is closed) — the card
/// still renders so the page can show a status banner above it.
class AudioRecorderCard extends StatefulWidget {
  const AudioRecorderCard({
    super.key,
    required this.enabled,
    required this.onRecordingReady,
    this.lockedReasonLabel,
  });

  /// When false the card shows a locked state with [lockedReasonLabel].
  final bool enabled;

  /// Called once the actor stops recording. Bytes are ready to submit.
  final ValueChanged<Uint8List> onRecordingReady;

  /// Optional copy explaining why recording is locked (e.g. existing pending
  /// review). Rendered as a small label when [enabled] is false.
  final String? lockedReasonLabel;

  @override
  State<AudioRecorderCard> createState() => _AudioRecorderCardState();
}

class _AudioRecorderCardState extends State<AudioRecorderCard>
    with SingleTickerProviderStateMixin {
  static const int _waveBarCount = 36;

  final AudioRecorder _recorder = AudioRecorder();
  final ap.AudioPlayer _player = ap.AudioPlayer();

  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<ap.PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<Duration>? _playerDurationSub;
  Timer? _elapsedTicker;
  late final AnimationController _pulseController;

  final List<double> _amplitudes =
      List<double>.filled(_waveBarCount, 0.0, growable: false);

  bool _isRecording = false;
  bool _isPreparing = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Uint8List? _recordingBytes;
  Duration _elapsed = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == ap.PlayerState.playing;
        if (state == ap.PlayerState.completed) {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        }
      });
    });
    _playerPositionSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _playbackPosition = p);
    });
    _playerDurationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _playbackDuration = d);
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _elapsedTicker?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording control
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_isRecording || _isPreparing) return;
    setState(() {
      _isPreparing = true;
      _error = null;
    });
    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _isPreparing = false;
          _error = 'Microphone permission was denied.';
        });
        return;
      }
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );
      // Web ignores `path`; native writes a temp file at that path.
      await _recorder.start(config, path: _generateTempPath());

      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        _pushAmplitude(amp.current);
      });

      _elapsedTicker?.cancel();
      _elapsed = Duration.zero;
      _elapsedTicker =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed += const Duration(milliseconds: 200);
        });
      });

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isPreparing = false;
        _hasRecording = false;
        _recordingPath = null;
        _recordingBytes = null;
        for (var i = 0; i < _amplitudes.length; i++) {
          _amplitudes[i] = 0.0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPreparing = false;
        _error = 'Could not start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      Uint8List? bytes;
      if (path != null && path.isNotEmpty) {
        try {
          bytes = await XFile(path).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      setState(() {
        _isRecording = false;
        _hasRecording = path != null && path.isNotEmpty;
        _recordingPath = path;
        _recordingBytes = bytes;
      });
      if (bytes != null) widget.onRecordingReady(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _error = 'Could not save recording: $e';
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (!_hasRecording) return;
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    try {
      final path = _recordingPath ?? '';
      if (path.isEmpty) {
        if (_recordingBytes != null) {
          await _player.play(ap.BytesSource(_recordingBytes!));
        }
        return;
      }
      // Web returns a blob:/ URL; native returns a file path.
      if (path.startsWith('blob:') ||
          path.startsWith('http:') ||
          path.startsWith('https:')) {
        await _player.play(ap.UrlSource(path));
      } else {
        await _player.play(ap.DeviceFileSource(path));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not play back: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _generateTempPath() {
    // Native: a path under temp; web ignores the value.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'scenolytics_audition_$stamp.m4a';
  }

  void _pushAmplitude(double db) {
    // `record` reports amplitude in dB (negative). -45 ≈ silence, 0 ≈ max.
    final norm = ((db + 45) / 45).clamp(0.0, 1.0);
    setState(() {
      for (var i = 0; i < _amplitudes.length - 1; i++) {
        _amplitudes[i] = _amplitudes[i + 1];
      }
      _amplitudes[_amplitudes.length - 1] = norm.toDouble();
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
          _CardTitle(
            icon: Icons.graphic_eq_rounded,
            label: 'Audio recording',
            isRecording: _isRecording,
          ),
          const SizedBox(height: 14),
          _buildBody(theme, cs, isDark),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs, bool isDark) {
    if (!widget.enabled) {
      return _LockedState(label: widget.lockedReasonLabel ?? 'Recording locked');
    }

    if (_hasRecording) {
      return _buildPreview(theme, cs, isDark);
    }

    return _buildRecorder(theme, cs, isDark);
  }

  Widget _buildRecorder(ThemeData theme, ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _AnimatedWaveform(
                amplitudes: _amplitudes,
                isRecording: _isRecording,
              ),
              _PulsingMic(
                controller: _pulseController,
                isRecording: _isRecording,
                onTap: _isRecording ? _stopRecording : _startRecording,
                isPreparing: _isPreparing,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording) ...[
              _RecordingDot(controller: _pulseController),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_elapsed),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ] else
              Text(
                _isPreparing ? 'Preparing microphone…' : 'Tap the mic to start',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isRecording)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            onPressed: _isPreparing ? null : _startRecording,
            icon: const Icon(Icons.mic_rounded),
            label: Text(_isPreparing ? 'Preparing…' : 'Start recording'),
          ),
        const SizedBox(height: 6),
        Text(
          'Record indoors in a quiet space. We capture audio only — no camera is used.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme, ColorScheme cs, bool isDark) {
    final total = _playbackDuration > Duration.zero
        ? _playbackDuration
        : _elapsed;
    final positionMs = _playbackPosition.inMilliseconds.toDouble();
    final totalMs = total.inMilliseconds.toDouble();
    final progress =
        totalMs <= 0 ? 0.0 : (positionMs / totalMs).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF0B1F2E),
                      const Color(0xFF103047),
                    ]
                  : [
                      cs.primaryContainer.withValues(alpha: 0.45),
                      cs.tertiaryContainer.withValues(alpha: 0.35),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 72,
                child: _StaticWaveform(
                  amplitudes: _amplitudes,
                  progress: progress,
                  activeColor: cs.primary,
                  inactiveColor: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    iconSize: 28,
                    onPressed: _togglePlayback,
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
                          'Your take',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDuration(_playbackPosition)} / '
                          '${_formatDuration(total)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white70
                                : cs.onPrimaryContainer
                                    .withValues(alpha: 0.85),
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
        const SizedBox(height: 10),
        Text(
          'Preview ready. Tap Submit below to send your audition.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal pieces
// ---------------------------------------------------------------------------

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.label,
    required this.isRecording,
  });

  final IconData icon;
  final String label;
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
          child: Icon(icon, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
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
                _BlinkingDot(),
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

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
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

class _PulsingMic extends StatelessWidget {
  const _PulsingMic({
    required this.controller,
    required this.isRecording,
    required this.onTap,
    required this.isPreparing,
  });

  final AnimationController controller;
  final bool isRecording;
  final bool isPreparing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        final scale = isRecording ? 1.0 + 0.04 * t : 1.0;
        final glowAlpha = isRecording ? 0.25 + 0.25 * t : 0.18;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isRecording
                    ? const [Color(0xFFFF5252), Color(0xFFE53935)]
                    : [cs.primary, ScenolyticsColors.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording
                          ? const Color(0xFFE53935)
                          : cs.primary)
                      .withValues(alpha: glowAlpha),
                  blurRadius: 28,
                  spreadRadius: isRecording ? 4 : 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isPreparing ? null : onTap,
                child: Center(
                  child: isPreparing
                      ? const SizedBox.square(
                          dimension: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFE53935)
                .withValues(alpha: 0.55 + 0.45 * controller.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935)
                    .withValues(alpha: 0.45 * controller.value),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedWaveform extends StatelessWidget {
  const _AnimatedWaveform({
    required this.amplitudes,
    required this.isRecording,
  });

  final List<double> amplitudes;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _WavePainter(
        amplitudes: amplitudes,
        idle: !isRecording,
        accent: cs.primary,
        accentSecondary: ScenolyticsColors.accentCyan,
      ),
      size: const Size.fromHeight(double.infinity),
    );
  }
}

class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StaticWavePainter(
        amplitudes: amplitudes,
        progress: progress,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
      ),
      size: const Size.fromHeight(double.infinity),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.amplitudes,
    required this.idle,
    required this.accent,
    required this.accentSecondary,
  });

  final List<double> amplitudes;
  final bool idle;
  final Color accent;
  final Color accentSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final n = amplitudes.length;
    final gap = 4.0;
    final barWidth = math.max(2.0, (size.width - gap * (n - 1)) / n);
    final centerY = size.height / 2;
    final maxBar = size.height * 0.85;
    final minIdle = size.height * 0.06;

    for (var i = 0; i < n; i++) {
      final v = amplitudes[i].clamp(0.0, 1.0);
      // Render a soft baseline when idle so the canvas doesn't look empty.
      final height = idle
          ? minIdle * (0.6 + 0.4 * math.sin(i * 0.7))
          : math.max(minIdle, v * maxBar);
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      final t = i / math.max(1, n - 1);
      final color = Color.lerp(accent, accentSecondary, t)!
          .withValues(alpha: idle ? 0.45 : 0.9);
      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) {
    if (old.idle != idle) return true;
    for (var i = 0; i < amplitudes.length; i++) {
      if (old.amplitudes[i] != amplitudes[i]) return true;
    }
    return false;
  }
}

class _StaticWavePainter extends CustomPainter {
  _StaticWavePainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final n = amplitudes.length;
    final gap = 3.0;
    final barWidth = math.max(2.0, (size.width - gap * (n - 1)) / n);
    final centerY = size.height / 2;
    final maxBar = size.height * 0.85;
    final minBar = size.height * 0.08;
    final cutoff = (progress * n).clamp(0.0, n.toDouble());

    for (var i = 0; i < n; i++) {
      final v = amplitudes[i].clamp(0.0, 1.0);
      final height = math.max(minBar, v * maxBar);
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - height / 2, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      final isPast = i < cutoff;
      canvas.drawRRect(
        rect,
        Paint()..color = isPast ? activeColor : inactiveColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticWavePainter old) {
    if (old.progress != progress) return true;
    for (var i = 0; i < amplitudes.length; i++) {
      if (old.amplitudes[i] != amplitudes[i]) return true;
    }
    return false;
  }
}

class _LockedState extends StatelessWidget {
  const _LockedState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, color: cs.onSurfaceVariant, size: 36),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
