import 'package:flutter/foundation.dart';

/// Bridges the single full-clip media player (audio or video) with the
/// per-sentence / per-segment cards so a card can play just its slice of the
/// recording.
///
/// The player widget [attach]es its seek/play/pause hooks and feeds position
/// updates via [reportPosition]; cards call [playSegment] to jump to a window
/// and the controller auto-pauses once playback reaches the segment end.
class EvaluationPlaybackController extends ChangeNotifier {
  Future<void> Function(Duration position)? _seek;
  Future<void> Function()? _play;
  Future<void> Function()? _pause;

  bool _ready = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _segmentEnd;

  bool get isReady => _ready;
  Duration get position => _position;
  Duration get duration => _duration;
  double get positionSeconds => _position.inMilliseconds / 1000.0;

  void attach({
    required Future<void> Function(Duration position) seek,
    required Future<void> Function() play,
    required Future<void> Function() pause,
  }) {
    _seek = seek;
    _play = play;
    _pause = pause;
    _ready = true;
    notifyListeners();
  }

  void detach() {
    _seek = null;
    _play = null;
    _pause = null;
    _ready = false;
    _segmentEnd = null;
    notifyListeners();
  }

  /// Fed by the player on every position tick. Auto-pauses at the end of the
  /// segment a card requested via [playSegment].
  void reportPosition(Duration position, Duration duration) {
    _position = position;
    if (duration > Duration.zero) _duration = duration;
    final end = _segmentEnd;
    if (end != null && position >= end) {
      _segmentEnd = null;
      _pause?.call();
    }
    notifyListeners();
  }

  /// True when the playhead currently sits inside [startSeconds]–[endSeconds].
  bool isSegmentActive(double? startSeconds, double? endSeconds) {
    if (startSeconds == null) return false;
    final end = endSeconds ?? startSeconds + 2.5;
    final pos = positionSeconds;
    return pos + 0.08 >= startSeconds && pos < end;
  }

  /// Seeks to [startSeconds] and plays; pauses automatically at [endSeconds]
  /// (when provided). No-op until a player has attached.
  Future<void> playSegment(double startSeconds, double? endSeconds) async {
    if (!_ready) return;
    _segmentEnd = (endSeconds != null && endSeconds > startSeconds)
        ? Duration(milliseconds: (endSeconds * 1000).round())
        : null;
    await _seek?.call(Duration(milliseconds: (startSeconds * 1000).round()));
    await _play?.call();
    notifyListeners();
  }
}
