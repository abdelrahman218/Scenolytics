import 'dart:async';
import 'package:flutter/material.dart';
import '../models/actor_audition_submission.dart';
import '../theme/scenolytics_colors.dart';

const double _kMobileBreak = 600;
bool _isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= _kMobileBreak;

/// Placeholder timeline-driven controller — replaced with a real audio plugin
/// (e.g. `just_audio`) once the recording asset is wired through the API.
class _AudioController extends ChangeNotifier {
  final Duration totalDuration;
  final String audioUrl;

  _AudioController({required this.totalDuration, required this.audioUrl});

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
          : (_position.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);

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

  void pause() {
    if (_disposed) return;
    _playing = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

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

class SentenceEmotion {
  final String timestamp;
  final String text;
  final String emotion;
  final String emoji;
  final double confidence;
  final Duration duration;
  final String audioUrl;

  const SentenceEmotion({
    required this.timestamp,
    required this.text,
    required this.emotion,
    required this.emoji,
    required this.confidence,
    required this.duration,
    this.audioUrl = 'AUDIO_URL_HERE',
  });
}

class VocalEmotionScorePage extends StatelessWidget {
  const VocalEmotionScorePage({
    super.key,
    required this.submission,
    this.sentences = _sentences,
    this.nested = false,
  });

  final ActorAuditionSubmission submission;
  final List<SentenceEmotion> sentences;

  /// When true, omits the page header so this can live inside a parent tab.
  final bool nested;

  static const _sentences = [
    SentenceEmotion(
      timestamp: '0:05',
      text: "I'm excited to be here today",
      emotion: 'Happy',
      emoji: '😊',
      confidence: 89,
      duration: Duration(seconds: 8),
      audioUrl: 'AUDIO_URL_HERE',
    ),
    SentenceEmotion(
      timestamp: '0:12',
      text: 'Let me show you my singing skills',
      emotion: 'Happy',
      emoji: '😊',
      confidence: 76,
      duration: Duration(seconds: 11),
      audioUrl: 'AUDIO_URL_HERE',
    ),
    SentenceEmotion(
      timestamp: '0:25',
      text: "This is something I've been practising for months",
      emotion: 'Neutral',
      emoji: '😐',
      confidence: 58,
      duration: Duration(seconds: 14),
      audioUrl: 'AUDIO_URL_HERE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final actorName = submission.actorName.trim().isEmpty ? 'Actor' : submission.actorName.trim();
    final actorAge = submission.age;
    final actorScore = submission.vocalToneScore;
    final pending = !submission.evaluationCompleted;
    final body = Column(
      children: [
        if (!nested) _AppBar(),
        Expanded(
          child: pending
              ? _PendingAnalysisView(
                  actorName: actorName,
                  actorAge: actorAge,
                  label: 'Vocal emotion analysis',
                )
              : wide
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
    );
    if (nested) {
      return ColoredBox(
        color: ScenolyticsColors.pageBackground,
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      body: body,
    );
  }
}

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
        _OverallAudioPlayer(
          duration: const Duration(seconds: 42),
          audioUrl: 'AUDIO_URL_HERE',
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
        _OverallAudioPlayer(
          duration: const Duration(seconds: 42),
          audioUrl: 'AUDIO_URL_HERE',
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

/// Reusable horizontal track that handles tap / drag seek for both players.
class _SeekTrack extends StatelessWidget {
  final _AudioController controller;
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
    final fraction =
        ((d.localPosition.dx) / box.maxWidth).clamp(0.0, 1.0);
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
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
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
                      Positioned(
                        left: (controller.progress * box.maxWidth - 6).clamp(0.0, box.maxWidth - 12),
                        top: (height / 2) - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fillColor,
                            boxShadow: [
                              BoxShadow(
                                color: fillColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
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

class _OverallAudioPlayer extends StatefulWidget {
  final Duration duration;
  final String audioUrl;

  const _OverallAudioPlayer({
    required this.duration,
    required this.audioUrl,
  });

  @override
  State<_OverallAudioPlayer> createState() => _OverallAudioPlayerState();
}

class _OverallAudioPlayerState extends State<_OverallAudioPlayer> {
  late final _AudioController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = _AudioController(
      totalDuration: widget.duration,
      audioUrl: widget.audioUrl,
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
          const SizedBox(height: 16),

          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                children: [
                  _WhiteIconBtn(
                    icon: Icons.replay_10_rounded,
                    size: 22,
                    onTap: _ctrl.skipBack,
                  ),
                  const SizedBox(width: 10),

                  GestureDetector(
                    onTap: _ctrl.toggle,
                    child: Container(
                      width: 48,
                      height: 48,
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
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  _WhiteIconBtn(
                    icon: Icons.forward_10_rounded,
                    size: 22,
                    onTap: _ctrl.skipForward,
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SeekTrack(
                          controller: _ctrl,
                          trackColor: Colors.white.withValues(alpha: 0.25),
                          fillColor: Colors.white,
                          height: 4,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedBuilder(
                              animation: _ctrl,
                              builder: (_, __) => Text(
                                _fmt(_ctrl.position),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
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
                      ],
                    ),
                  ),
                ],
              );
            },
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
          _SentenceAudioPlayer(sentence: sentence),
        ],
      ),
    );
  }
}

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

class _SentenceAudioPlayer extends StatefulWidget {
  final SentenceEmotion sentence;
  const _SentenceAudioPlayer({required this.sentence});

  @override
  State<_SentenceAudioPlayer> createState() => _SentenceAudioPlayerState();
}

class _SentenceAudioPlayerState extends State<_SentenceAudioPlayer> {
  late final _AudioController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = _AudioController(
      totalDuration: widget.sentence.duration,
      audioUrl: widget.sentence.audioUrl,
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
          Row(
            children: [
              Icon(Icons.volume_up_rounded,
                  size: 13, color: ScenolyticsColors.textMuted),
              const SizedBox(width: 5),
              const Text(
                'Audio',
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

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ScenolyticsColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  children: [
                    GestureDetector(
                      onTap: _ctrl.toggle,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ScenolyticsColors.accentCyan,
                        ),
                        child: Icon(
                          _ctrl.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fmt(_ctrl.position),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ScenolyticsColors.textMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                _fmt(_ctrl.duration),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ScenolyticsColors.textMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
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
    );
  }
}

class _PendingAnalysisView extends StatelessWidget {
  final String actorName;
  final int actorAge;
  final String label;
  const _PendingAnalysisView({
    required this.actorName,
    required this.actorAge,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ActorCardPending(name: actorName, age: actorAge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: ScenolyticsColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScenolyticsColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$label is pending',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ScenolyticsColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'The AI evaluation has not completed yet for this submission. '
                'The detailed breakdown, scores, and sentence-level results '
                'will appear here as soon as analysis finishes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ScenolyticsColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActorCardPending extends StatelessWidget {
  final String name;
  final int age;
  const _ActorCardPending({required this.name, required this.age});

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
                colors: [
                  ScenolyticsColors.primary,
                  ScenolyticsColors.accentCyan,
                ],
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ScenolyticsColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Age: $age',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScenolyticsColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ScenolyticsColors.accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ScenolyticsColors.accentCyan.withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ScenolyticsColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}