import 'package:flutter/foundation.dart';

/// Holds the currently playing track and play/pause state.
/// PlayerScreen registers callbacks so the MiniPlayer can control playback.
class PlayerProvider extends ChangeNotifier {
  Map<String, dynamic>? _track;
  bool _isPlaying = false;
  bool _shuffleOn = false;
  double _progress = 0.0; // 0.0 to 1.0
  VoidCallback? _toggleCb;
  VoidCallback? _nextCb;
  VoidCallback? _prevCb;

  Map<String, dynamic>? get track => _track;
  bool get isPlaying => _isPlaying;
  bool get shuffleOn => _shuffleOn;
  bool get hasTrack => _track != null;
  double get progress => _progress;

  void toggleShuffle() {
    _shuffleOn = !_shuffleOn;
    notifyListeners();
  }

  void setTrack(Map<String, dynamic> track, {bool isPlaying = false}) {
    _track = Map<String, dynamic>.from(track);
    _isPlaying = isPlaying;
    _progress = 0.0;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    notifyListeners();
  }

  void setProgress(double p) {
    _progress = p.clamp(0.0, 1.0);
    notifyListeners();
  }

  void registerToggle(VoidCallback cb) => _toggleCb = cb;
  void unregisterToggle() => _toggleCb = null;
  void toggleFromOutside() => _toggleCb?.call();

  void registerNext(VoidCallback cb) => _nextCb = cb;
  void registerPrev(VoidCallback cb) => _prevCb = cb;
  void unregisterNextPrev() { _nextCb = null; _prevCb = null; }

  void nextTrack() => _nextCb?.call();
  void prevTrack() => _prevCb?.call();

  void clear() {
    _track = null;
    _isPlaying = false;
    _progress = 0.0;
    _toggleCb = null;
    _nextCb = null;
    _prevCb = null;
    notifyListeners();
  }
}
