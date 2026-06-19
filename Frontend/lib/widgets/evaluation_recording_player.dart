import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/scenolytics_colors.dart';
import 'evaluation_playback_controller.dart';

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Real network video player for the director's full audition recording.
///
/// Probes [candidates] in order (first that initializes wins) so it tolerates
/// the different MinIO / gateway URL shapes the repository may resolve. Shows a
/// graceful placeholder when no playable URL is available.
class EvaluationVideoPlayer extends StatefulWidget {
  const EvaluationVideoPlayer({
    super.key,
    required this.candidates,
    this.playback,
  });

  final List<String> candidates;

  /// Optional shared controller so per-sentence cards can play their slice.
  final EvaluationPlaybackController? playback;

  @override
  State<EvaluationVideoPlayer> createState() => _EvaluationVideoPlayerState();
}

class _EvaluationVideoPlayerState extends State<EvaluationVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final urls = widget.candidates
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    for (final url in urls) {
      VideoPlayerController? c;
      try {
        c = VideoPlayerController.networkUrl(Uri.parse(url));
        await c.initialize();
        if (!mounted) {
          await c.dispose();
          return;
        }
        c.addListener(_onTick);
        widget.playback?.attach(
          seek: c.seekTo,
          play: c.play,
          pause: c.pause,
        );
        setState(() {
          _controller = c;
          _loading = false;
        });
        return;
      } catch (_) {
        await c?.dispose();
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onTick() {
    final c = _controller;
    if (c != null) {
      widget.playback?.reportPosition(c.value.position, c.value.duration);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.playback?.detach();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildSurface(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Full Recording',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressBar(controller: _controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface() {
    if (_loading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          ),
        ),
      );
    }
    final c = _controller;
    if (_failed || c == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 44),
              const SizedBox(height: 8),
              Text(
                'Recording unavailable',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            opacity: c.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final dur = c?.value.duration ?? Duration.zero;
    final pos = c?.value.position ?? Duration.zero;
    final progress = dur.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: c == null
                  ? null
                  : (d) {
                      final frac =
                          (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
                      c.seekTo(Duration(
                          milliseconds:
                              (frac * dur.inMilliseconds).round()));
                    },
              onHorizontalDragUpdate: c == null
                  ? null
                  : (d) {
                      final frac =
                          (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
                      c.seekTo(Duration(
                          milliseconds:
                              (frac * dur.inMilliseconds).round()));
                    },
              child: SizedBox(
                height: 18,
                child: Align(
                  child: Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(pos),
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
            Text(_fmt(dur),
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ],
    );
  }
}

/// Real network audio player for the director's full audition recording.
class EvaluationAudioPlayer extends StatefulWidget {
  const EvaluationAudioPlayer({
    super.key,
    required this.candidates,
    this.playback,
  });

  final List<String> candidates;

  /// Optional shared controller so per-sentence cards can play their slice.
  final EvaluationPlaybackController? playback;

  @override
  State<EvaluationAudioPlayer> createState() => _EvaluationAudioPlayerState();
}

class _EvaluationAudioPlayerState extends State<EvaluationAudioPlayer> {
  final ap.AudioPlayer _player = ap.AudioPlayer();
  bool _loading = true;
  bool _failed = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s == ap.PlayerState.playing;
        if (s == ap.PlayerState.completed) {
          _playing = false;
          _position = Duration.zero;
        }
      });
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      widget.playback?.reportPosition(p, _duration);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _init();
  }

  Future<void> _init() async {
    final urls = widget.candidates
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    for (final url in urls) {
      try {
        await _player.setSource(ap.UrlSource(url));
        if (!mounted) return;
        widget.playback?.attach(
          seek: _player.seek,
          play: _player.resume,
          pause: _player.pause,
        );
        setState(() => _loading = false);
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    widget.playback?.detach();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_failed) return;
    _playing ? await _player.pause() : await _player.resume();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full Recording',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                ),
              ),
            )
          else if (_failed)
            Row(
              children: [
                Icon(Icons.music_off_rounded,
                    color: Colors.white.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 8),
                Text('Recording unavailable',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
              ],
            )
          else
            Row(
              children: [
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            final frac = (d.localPosition.dx / box.maxWidth)
                                .clamp(0.0, 1.0);
                            _player.seek(Duration(
                                milliseconds:
                                    (frac * _duration.inMilliseconds).round()));
                          },
                          child: SizedBox(
                            height: 16,
                            child: Align(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85))),
                          Text(_fmt(_duration),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
