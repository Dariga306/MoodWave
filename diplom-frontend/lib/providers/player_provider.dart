import 'package:flutter/foundation.dart';

/// Holds the currently playing track and play/pause state.
/// PlayerScreen registers a toggle callback so the MiniPlayer can
/// control playback even when it's not the active route.
class PlayerProvider extends ChangeNotifier {
  Map<String, dynamic>? _track;
  bool _isPlaying = false;
  VoidCallback? _toggleCb;

  Map<String, dynamic>? get track => _track;
  bool get isPlaying => _isPlaying;
  bool get hasTrack => _track != null;

  void setTrack(Map<String, dynamic> track, {bool isPlaying = false}) {
    _track = Map<String, dynamic>.from(track);
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    notifyListeners();
  }

  /// Called by PlayerScreen in initState / after each track load.
  void registerToggle(VoidCallback cb) => _toggleCb = cb;

  /// Called by PlayerScreen in dispose.
  void unregisterToggle() => _toggleCb = null;

  /// Called from MiniPlayer play/pause button.
  void toggleFromOutside() => _toggleCb?.call();

  void clear() {
    _track = null;
    _isPlaying = false;
    _toggleCb = null;
    notifyListeners();
  }
}
