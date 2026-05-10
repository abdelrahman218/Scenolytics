import 'dart:async';
import 'package:flutter/material.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';

// ═════════════════════════════════════════════════════════════════════════════
// BACKEND INTEGRATION GUIDE
// ─────────────────────────────────────────────────────────────────────────────
// When you connect a real video backend (e.g. video_player, better_player):
//
// 1. ADD your video plugin to pubspec.yaml, e.g.:
//      video_player: ^2.x.x
//
// 2. REPLACE _VideoController with a real implementation:
//    - _VideoController.play()    → _videoPlayerController.play()
//    - _VideoController.pause()   → _videoPlayerController.pause()
//    - _VideoController.seekTo()  → _videoPlayerController.seekTo(position)
//    - _VideoController.position  → _videoPlayerController.value.position
//    - _VideoController.duration  → _videoPlayerController.value.duration
//
// 3. REPLACE videoUrl placeholder in _OverallVideoPlayer and _SentenceVideoPlayer:
//    - Pass the real URL/path from your API response instead of 'VIDEO_URL_HERE'
//
// 4. SentenceEmotion model:
//    - The `videoUrl` field is ready — populate it from your API JSON.
//
// 5. FacialEmotionScorePage:
//    - Replace the hardcoded _sentences list with data fetched from your API.
//    - Replace 'Yousef', age: 20, score: 74 with real actor data from API.
//
// 6. Video preview surface:
//    - In _OverallVideoPlayer and _SentenceVideoPlayer, replace the placeholder
//      Container (marked "BACKEND: swap for VideoPlayer widget") with a real
//      VideoPlayer(controller) widget from the video_player package, wrapped
//      in AspectRatio(aspectRatio: 16/9, child: VideoPlayer(...)).
// ═════════════════════════════════════════════════════════════════════════════

const double _kMobileBreak = 600;
bool _isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= _kMobileBreak;

// ─────────────────────────────────────────────────────────────────────────────
// Shared video controller — swap internals for real player on backend hookup
// ─────────────────────────────────────────────────────────────────────────────

class _VideoController extends ChangeNotifier {
  // ── BACKEND: replace these with your player's streams/values ──
  final Duration totalDuration;
  final String videoUrl; // ← BACKEND: pass real URL from API

  _VideoController({required this.totalDuration, required this.videoUrl});

  bool _playing = false;
  bool _disposed = false;
  Duration _position = Duration.zero;
  Timer? _timer;

  bool get isPlaying => _playing;
  Duration get position => _position;
  Duration get duration => totalDuration;
  double get progress =>
      totalDuration.inMilliseconds == 0
          ? 0
          : (_position.inMilliseconds / totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

  // ── BACKEND: replace body with videoPlayerController.play() ──
  void play() {
    if (_playing || _disposed) return;
    _playing = true;
    notifyListeners();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_disposed) return;
      _position += const Duration(milliseconds: 200);
      if (_position >= totalDuration) {
        _position = Duration.zero;
        _playing = false;
        _timer?.cancel();
        _timer = null;
      }
      if (!_disposed) notifyListeners();
    });
  }

  // ── BACKEND: replace body with videoPlayerController.pause() ──
  void pause() {
    if (_disposed) return;
    _playing = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  // ── BACKEND: replace body with videoPlayerController.seekTo(position) ──
  void seekTo(Duration position) {
    _position = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        totalDuration.inMilliseconds,
      ),
    );
    notifyListeners();
  }

  void skipBack() => seekTo(_position - const Duration(seconds: 10));
  void skipForward() => seekTo(_position + const Duration(seconds: 10));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class SentenceEmotion {
  final String timestamp;
  final String text;
  final String emotion;
  final String emoji;
  final double confidence;
  final Duration duration;
  final String videoUrl; // ← BACKEND: populate from API response

  const SentenceEmotion({
    required this.timestamp,
    required this.text,
    required this.emotion,
    required this.emoji,
    required this.confidence,
    required this.duration,
    this.videoUrl = 'VIDEO_URL_HERE', // ← BACKEND: replace with real URL
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Page root — BACKEND: replace _sentences & actor data with API response
// ─────────────────────────────────────────────────────────────────────────────

class FacialEmotionScorePage extends StatelessWidget {
  const FacialEmotionScorePage({
    super.key,
    required this.submission,
    this.sentences = _sentences,
  });

  final ActorAuditionSubmission submission;
  final List<SentenceEmotion> sentences;

  // ── BACKEND: replace with data from your API ──
  static const _sentences = [
    SentenceEmotion(
      timestamp: '0:05',
      text: "I'm excited to be here today",
      emotion: 'Happy',
      emoji: '😊',
      confidence: 89,
      duration: Duration(seconds: 8),
      videoUrl: 'VIDEO_URL_HERE',
    ),
    SentenceEmotion(
      timestamp: '0:12',
      text: 'Let me show you my singing skills',
      emotion: 'Happy',
      emoji: '😊',
      confidence: 76,
      duration: Duration(seconds: 11),
      videoUrl: 'VIDEO_URL_HERE',
    ),
    SentenceEmotion(
      timestamp: '0:25',
      text: "This is something I've been practising for months",
      emotion: 'Neutral',
      emoji: '😐',
      confidence: 58,
      duration: Duration(seconds: 14),
      videoUrl: 'VIDEO_URL_HERE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final actorName = submission.actorName.trim().isEmpty
        ? 'Actor'
        : submission.actorName.trim();
    final actorAge = submission.age;
    final actorScore = submission.emotionalScore;
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: wide
                ? _WebLayout(
                    sentences: sentences,
                    actorName: actorName,
                    actorAge: actorAge,
                    actorScore: actorScore,
                  )
                : _MobileLayout(
                    sentences: sentences,
                    actorName: actorName,
                    actorAge: actorAge,
                    actorScore: actorScore,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final List<SentenceEmotion> sentences;
  final String actorName;
  final int actorAge;
  final int actorScore;
  const _MobileLayout({
    required this.sentences,
    required this.actorName,
    required this.actorAge,
    required this.actorScore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActorCard(name: actorName, age: actorAge, score: actorScore),
        const SizedBox(height: 14),
        _OverallVideoPlayer(
          // BACKEND: replace duration & videoUrl from API
          duration: const Duration(seconds: 42),
          videoUrl: 'VIDEO_URL_HERE',
        ),
        const SizedBox(height: 14),
        const _SectionHeading('Emotion Detected By Sentence'),
        const SizedBox(height: 10),
        ...sentences.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SentenceCard(sentence: s),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Web layout ────────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final List<SentenceEmotion> sentences;
  final String actorName;
  final int actorAge;
  final int actorScore;
  const _WebLayout({
    required this.sentences,
    required this.actorName,
    required this.actorAge,
    required this.actorScore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        _ActorCard(name: actorName, age: actorAge, score: actorScore),
        const SizedBox(height: 16),
        _OverallVideoPlayer(
          // BACKEND: replace duration & videoUrl from API
          duration: const Duration(seconds: 42),
          videoUrl: 'VIDEO_URL_HERE',
        ),
        const SizedBox(height: 20),
        const _SectionHeading('Emotion Detected By Sentence'),
        const SizedBox(height: 14),
        _SentenceGrid(sentences: sentences),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SentenceGrid extends StatelessWidget {
  final List<SentenceEmotion> sentences;
  const _SentenceGrid({required this.sentences});

  @override
  Widget build(BuildContext context) {
    final rows = <List<SentenceEmotion>>[];
    for (var i = 0; i < sentences.length; i += 2) {
      rows.add(sentences.sublist(i, (i + 2).clamp(0, sentences.length)));
    }
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SentenceCard(sentence: row[0])),
              if (row.length > 1) ...[
                const SizedBox(width: 20),
                Expanded(child: _SentenceCard(sentence: row[1])),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
      decoration: const BoxDecoration(gradient: ScenolyticsColors.heroBarGradient),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const Text(
            'Vocal Emotion Score',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actor card
// ─────────────────────────────────────────────────────────────────────────────

class _ActorCard extends StatelessWidget {
  final String name;
  final int age;
  final int score;
  const _ActorCard({required this.name, required this.age, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ScenolyticsColors.primary, ScenolyticsColors.accentCyan],
              ),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ScenolyticsColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Age: $age',
                    style: const TextStyle(
                        fontSize: 12, color: ScenolyticsColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: ScenolyticsColors.accentCyan, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$score',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScenolyticsColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared seekable track widget — used by both player styles
// ─────────────────────────────────────────────────────────────────────────────

class _SeekTrack extends StatelessWidget {
  final _VideoController controller;
  final Color trackColor;
  final Color fillColor;
  final double height;

  const _SeekTrack({
    required this.controller,
    required this.trackColor,
    required this.fillColor,
    this.height = 4,
  });

  void _onTapDown(TapDownDetails d, BoxConstraints box) {
    final fraction = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    controller.seekTo(
      Duration(
        milliseconds: (fraction * controller.duration.inMilliseconds).round(),
      ),
    );
  }

  void _onDrag(DragUpdateDetails d, BoxConstraints box) {
    final fraction = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    controller.seekTo(
      Duration(
        milliseconds: (fraction * controller.duration.inMilliseconds).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _onTapDown(d, box),
          onHorizontalDragUpdate: (d) => _onDrag(d, box),
          child: SizedBox(
            height: 20, // larger hit area
            child: Align(
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  return Stack(
                    children: [
                      // Track background
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                      // Fill
                      FractionallySizedBox(
                        widthFactor: controller.progress,
                        child: Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(height / 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall video player — gradient card with 16:9 preview + controls
// ─────────────────────────────────────────────────────────────────────────────

class _OverallVideoPlayer extends StatefulWidget {
  final Duration duration;
  final String videoUrl; // ← BACKEND: pass real URL

  const _OverallVideoPlayer({
    required this.duration,
    required this.videoUrl,
  });

  @override
  State<_OverallVideoPlayer> createState() => _OverallVideoPlayerState();
}

class _OverallVideoPlayerState extends State<_OverallVideoPlayer> {
  late final _VideoController _ctrl;

  @override
  void initState() {
    super.initState();
    // BACKEND: initialise your real VideoPlayerController here using widget.videoUrl
    _ctrl = _VideoController(
      totalDuration: widget.duration,
      videoUrl: widget.videoUrl,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
          // ── 16:9 video surface ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── BACKEND: replace this Container with VideoPlayer(controller) ──
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          color: Colors.white.withValues(alpha: 0.18),
                          size: 64,
                        ),
                      ),
                    ),
                    // Tap-to-toggle play/pause overlay
                    GestureDetector(
                      onTap: _ctrl.toggle,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedOpacity(
                        opacity: _ctrl.isPlaying ? 0.0 : 1.0,
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
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Controls bar below video ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
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

                // Seek track
                _SeekTrack(
                  controller: _ctrl,
                  trackColor: Colors.white.withValues(alpha: 0.25),
                  fillColor: Colors.white,
                  height: 4,
                ),
                const SizedBox(height: 6),

                // Time labels
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(_ctrl.position),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _fmt(_ctrl.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Skip back / play-pause / skip forward
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WhiteIconBtn(
                        icon: Icons.replay_10_rounded,
                        size: 26,
                        onTap: _ctrl.skipBack,
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: _ctrl.toggle,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _ctrl.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _WhiteIconBtn(
                        icon: Icons.forward_10_rounded,
                        size: 26,
                        onTap: _ctrl.skipForward,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _WhiteIconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: size),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section heading
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ScenolyticsColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sentence card
// ─────────────────────────────────────────────────────────────────────────────

class _SentenceCard extends StatelessWidget {
  final SentenceEmotion sentence;
  const _SentenceCard({required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ScenolyticsColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScenolyticsColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentence.timestamp,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ScenolyticsColors.textMuted,
                    letterSpacing: 0.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sentence.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ScenolyticsColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(sentence.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sentence.emotion,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ScenolyticsColors.accentCyan,
                    ),
                  ),
                ),
                Text(
                  '${sentence.confidence.toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ScenolyticsColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _AnimatedProgressBar(value: sentence.confidence / 100),
          ),
          Divider(
            height: 1,
            color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.6),
          ),
          _SentenceVideoPlayer(sentence: sentence),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated confidence bar
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedProgressBar extends StatefulWidget {
  final double value;
  const _AnimatedProgressBar({required this.value});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: _anim.value,
          minHeight: 6,
          backgroundColor: ScenolyticsColors.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation<Color>(
              ScenolyticsColors.accentCyanSoft),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-sentence video player — 16:9 preview + compact seek controls
// ─────────────────────────────────────────────────────────────────────────────

class _SentenceVideoPlayer extends StatefulWidget {
  final SentenceEmotion sentence;
  const _SentenceVideoPlayer({required this.sentence});

  @override
  State<_SentenceVideoPlayer> createState() => _SentenceVideoPlayerState();
}

class _SentenceVideoPlayerState extends State<_SentenceVideoPlayer> {
  late final _VideoController _ctrl;

  @override
  void initState() {
    super.initState();
    // BACKEND: initialise your real VideoPlayerController here using widget.sentence.videoUrl
    _ctrl = _VideoController(
      totalDuration: widget.sentence.duration,
      videoUrl: widget.sentence.videoUrl,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Video" label
          Row(
            children: [
              Icon(Icons.videocam_rounded,
                  size: 13, color: ScenolyticsColors.textMuted),
              const SizedBox(width: 5),
              const Text(
                'Video',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: ScenolyticsColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Video surface + controls
          Container(
            decoration: BoxDecoration(
              color: ScenolyticsColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // ── 16:9 video surface ──────────────────────────────────────
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── BACKEND: replace this Container with VideoPlayer(controller) ──
                          Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Icons.videocam_rounded,
                                color: Colors.white.withValues(alpha: 0.15),
                                size: 36,
                              ),
                            ),
                          ),
                          // Tap-to-toggle overlay
                          GestureDetector(
                            onTap: _ctrl.toggle,
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedOpacity(
                              opacity: _ctrl.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ScenolyticsColors.accentCyan,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Compact seek bar + play button ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      return Row(
                        children: [
                          // Play / pause
                          GestureDetector(
                            onTap: _ctrl.toggle,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ScenolyticsColors.accentCyan,
                              ),
                              child: Icon(
                                _ctrl.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Track + times
                          Expanded(
                            child: Column(
                              children: [
                                _SeekTrack(
                                  controller: _ctrl,
                                  trackColor: ScenolyticsColors.outlineSoft,
                                  fillColor: ScenolyticsColors.accentCyan,
                                  height: 3,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _fmt(_ctrl.position),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: ScenolyticsColors.textMuted,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _fmt(_ctrl.duration),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: ScenolyticsColors.textMuted,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
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
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}