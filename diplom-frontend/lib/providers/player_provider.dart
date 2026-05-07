import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

import '../services/api_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  yt.YoutubePlayerController? _ytController;
  StreamSubscription? _ytStateSubscription;
  StreamSubscription<Duration>? _ytPositionSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;
  Timer? _progressTimer;

  Map<String, dynamic>? _track;
  List<Map<String, dynamic>> _queue = [];
  int _queueIndex = 0;

  bool _loadingTrack = false;
  bool _ytReady = false;
  bool _audioReady = false;
  bool _ytPlaying = false;
  bool _audioPlaying = false;
  bool _shuffleOn = false;
  int _repeatMode = 0; // 0=off 1=repeat-all 2=repeat-one
  bool _trackEnded = false;
  DateTime? _lastSeekAt;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Map<String, dynamic>? get track => _track;
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  bool get isPlaying => _usingYoutube ? _ytPlaying : _audioPlaying;
  bool get hasTrack => _track != null;
  bool get shuffleOn => _shuffleOn;
  int get repeatMode => _repeatMode;
  bool get loadingTrack => _loadingTrack;
  bool get trackEnded => _trackEnded;
  bool get ytReady => _ytReady;
  bool get audioReady => _audioReady;
  Duration get position => _position;
  Duration get duration => _duration;
  yt.YoutubePlayerController? get youtubeController => _ytController;
  bool get usingYoutube => _usingYoutube;
  Stream<Duration> get positionStream => _usingYoutube && _ytController != null
      ? _ytController!.getCurrentPositionStream(
          period: const Duration(milliseconds: 200),
        )
      : _player.positionStream;
  double get progress {
    final totalMs = _seekableDuration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  String get title =>
      (_track?['title'] ?? _track?['trackName'] ?? 'Unknown').toString();
  String get artist =>
      (_track?['artist'] ?? _track?['artistName'] ?? '').toString();
  String? get coverUrl =>
      (_track?['cover_url'] ?? _track?['artworkUrl100'])?.toString();
  String get album =>
      (_track?['album'] ?? _track?['collectionName'] ?? '').toString();
  String get trackId => (_track?['spotify_id'] ??
          _track?['deezer_id'] ??
          _track?['track_id'] ??
          _track?['trackId'] ??
          '')
      .toString();

  bool get _usingYoutube => _ytReady && _ytController != null;

  String get _playbackLookupId {
    if (trackId.isNotEmpty) {
      return trackId;
    }
    final seed = '$artist $title'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return seed.isEmpty ? 'track_lookup' : 'query:$seed';
  }

  Duration get _seekableDuration {
    if (_usingYoutube) return _duration;
    if (_audioReady) {
      return _player.duration ?? _duration;
    }
    return _duration;
  }

  Future<void> openTrack(
    Map<String, dynamic> track, {
    bool refreshQueue = true,
  }) async {
    final seedTrack = Map<String, dynamic>.from(track);
    final seededQueue = _extractQueue(seedTrack);

    if (_track != null &&
        _sameTrack(_track!, seedTrack) &&
        (isPlaying || _loadingTrack)) {
      _queue = seededQueue;
      _syncQueueIndex(seedTrack);
      notifyListeners();
      return;
    }

    _queue = seededQueue;
    _syncQueueIndex(seedTrack);
    await _loadTrack(seedTrack, refreshQueue: refreshQueue);
  }

  void toggleShuffle() {
    _shuffleOn = !_shuffleOn;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = (_repeatMode + 1) % 3;
    notifyListeners();
  }

  void setRepeatMode(int mode) {
    final next = mode.clamp(0, 2);
    if (_repeatMode == next) return;
    _repeatMode = next;
    notifyListeners();
  }

  void replaceUpcomingQueue(List<Map<String, dynamic>> upcoming) {
    if (_queue.isEmpty) return;
    final head = _queue.take(_queueIndex + 1).map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
    _queue = [
      ...head,
      ...upcoming.map((item) => Map<String, dynamic>.from(item)),
    ];
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    _trackEnded = false;
    if (_usingYoutube && _ytController != null) {
      final nowPlaying = _ytPlaying;
      nowPlaying ? _ytController!.pauseVideo() : _ytController!.playVideo();
      _ytPlaying = !nowPlaying;
      notifyListeners();
      return;
    }
    if (_audioReady) {
      final nowPlaying = _audioPlaying;
      nowPlaying ? await _player.pause() : await _player.play();
      _audioPlaying = !nowPlaying;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_usingYoutube && _ytController != null) {
      _ytController!.pauseVideo();
      _ytPlaying = false;
      notifyListeners();
      return;
    }
    if (_audioReady) {
      await _player.pause();
      _audioPlaying = false;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    _trackEnded = false;
    if (_usingYoutube && _ytController != null) {
      _ytController!.playVideo();
      _ytPlaying = true;
      notifyListeners();
      return;
    }
    if (_audioReady) {
      await _player.play();
      _audioPlaying = true;
      notifyListeners();
    }
  }

  Future<void> restartCurrentTrack() async {
    _trackEnded = false;
    await seekTo(Duration.zero);
    await resume();
  }

  Future<void> seekTo(Duration position) async {
    _lastSeekAt = DateTime.now();
    final limit = _seekableDuration;
    var target = limit > Duration.zero && position > limit ? limit : position;
    if (limit > const Duration(milliseconds: 800) && target >= limit) {
      target = limit - const Duration(milliseconds: 400);
    }

    if (_ytReady && _ytController != null) {
      _ytController!.seekTo(
        seconds: target.inMilliseconds / 1000.0,
        allowSeekAhead: true,
      );
    } else if (_audioReady) {
      await _player.seek(target);
    }

    _position = target;
    notifyListeners();
  }

  Future<void> nextTrack() async {
    await _ensureQueue();
    if (_queue.isEmpty) return;

    if (_shuffleOn) {
      final indices = List.generate(_queue.length, (i) => i)
        ..remove(_queueIndex);
      if (indices.isEmpty) {
        if (_repeatMode == 1) {
          await _loadTrack(_queue[_queueIndex], refreshQueue: false);
        }
        return;
      }
      indices.shuffle();
      _queueIndex = indices.first;
      notifyListeners();
      await _loadTrack(_queue[_queueIndex], refreshQueue: false);
      return;
    }

    final next = _queueIndex + 1;
    if (next >= _queue.length) {
      if (_repeatMode == 1) {
        _queueIndex = 0;
        notifyListeners();
        await _loadTrack(_queue[0], refreshQueue: false);
        return;
      }
      if (artist.isNotEmpty) {
        try {
          final more = await ApiService().searchTracksWithFallback(
            artist,
            limit: 20,
          );
          final filtered =
              more.where((t) => !_queue.any((q) => _sameTrack(q, t))).toList();
          if (filtered.isNotEmpty) {
            _queue.addAll(filtered);
            _queueIndex += 1;
            notifyListeners();
            await _loadTrack(_queue[_queueIndex], refreshQueue: false);
          }
        } catch (_) {}
      }
      return;
    }

    _queueIndex = next;
    notifyListeners();
    await _loadTrack(_queue[next], refreshQueue: false);
  }

  Future<void> prevTrack() async {
    if (_position.inSeconds > 3) {
      if (_usingYoutube && _ytController != null) {
        _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
      } else if (_audioReady) {
        await _player.seek(Duration.zero);
      }
      _position = Duration.zero;
      notifyListeners();
      return;
    }

    await _ensureQueue();
    if (_queue.isEmpty) return;
    final prev = (_queueIndex - 1).clamp(0, _queue.length - 1);
    if (prev == _queueIndex) return;

    _queueIndex = prev;
    notifyListeners();
    await _loadTrack(_queue[prev], refreshQueue: false);
  }

  Future<void> stop() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    await _resetPlayback();

    _track = null;
    _queue = [];
    _queueIndex = 0;
    _loadingTrack = false;
    _ytReady = false;
    _audioReady = false;
    _ytPlaying = false;
    _audioPlaying = false;
    _trackEnded = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> _loadTrack(
    Map<String, dynamic> nextTrack, {
    bool refreshQueue = true,
  }) async {
    _loadingTrack = true;
    _trackEnded = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _ytReady = false;
    _audioReady = false;
    _ytPlaying = false;
    _audioPlaying = false;
    _track = Map<String, dynamic>.from(nextTrack);
    notifyListeners();

    await _resetPlayback();

    final enrichedTrack = await _enrichTrack(_track!);
    _track = Map<String, dynamic>.from(enrichedTrack);
    _syncQueueIndex(_track!);
    notifyListeners();

    _startProgressHeartbeat();
    await _initPlayer();

    _loadingTrack = false;
    notifyListeners();

    if (refreshQueue) {
      unawaited(_ensureQueue());
    }
  }

  Future<void> _initPlayer() async {
    if (title.isEmpty) return;

    try {
      final videoId = await ApiService().getYouTubeId(
        trackId: _playbackLookupId,
        title: title,
        artist: artist,
      );
      if (videoId != null && videoId.isNotEmpty) {
        final trackDurationMs = _track?['duration_ms'] as int?;
        if (trackDurationMs != null && trackDurationMs > 0) {
          _duration = Duration(milliseconds: trackDurationMs);
        }

        final controller = yt.YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const yt.YoutubePlayerParams(
            showControls: false,
            showFullscreenButton: false,
            mute: false,
          ),
        );

        _ytStateSubscription = controller.listen((value) {
          final playing = value.playerState == yt.PlayerState.playing;
          _ytPlaying = playing;
          if (value.metaData.duration > Duration.zero) {
            _duration = value.metaData.duration;
          }
          notifyListeners();
          if (value.playerState == yt.PlayerState.ended) {
            unawaited(_onTrackEnded());
          }
        });

        _ytPositionSubscription = controller
            .getCurrentPositionStream(period: const Duration(milliseconds: 200))
            .listen((position) {
          _position = position;
          notifyListeners();
        });

        _ytController = controller;
        _ytReady = true;
        notifyListeners();

        ApiService()
            .playTrack(
              _playbackLookupId,
              title: title,
              artist: artist,
              genre: _track?['genre']?.toString(),
              coverUrl: coverUrl,
            )
            .catchError((_) {});
        return;
      }
    } catch (_) {}

    await _initPreview();
  }

  Future<void> _initPreview() async {
    String? url = (_track?['preview_url'] ?? _track?['previewUrl']) as String?;

    if (url == null || url.isEmpty) {
      try {
        final resolved = await ApiService().resolveTrack(
          title: title,
          artist: artist,
          trackId: trackId.isEmpty ? null : trackId,
        );
        if (resolved != null) {
          final merged = _fillTrackData(_track!, resolved);
          url = (merged['preview_url'] ?? merged['previewUrl']) as String?;
          _track = merged;
          notifyListeners();
        }
      } catch (_) {}
    }

    if (url == null || url.isEmpty) {
      return;
    }

    try {
      await _player.setUrl(url);
      final trackDurationMs = _track?['duration_ms'] as int?;
      _duration = (trackDurationMs != null && trackDurationMs > 0)
          ? Duration(milliseconds: trackDurationMs)
          : (_player.duration ?? Duration.zero);
      _audioReady = true;

      _audioPositionSubscription = _player.positionStream.listen((position) {
        _position = position;
        notifyListeners();
      });
      _audioDurationSubscription = _player.durationStream.listen((duration) {
        if (duration == null) return;
        final metaMs = _track?['duration_ms'] as int?;
        if (metaMs == null || metaMs <= 0) {
          _duration = duration;
          notifyListeners();
        }
      });
      _audioStateSubscription = _player.playerStateStream.listen((state) {
        _audioPlaying = state.playing;
        notifyListeners();
        if (state.processingState == ProcessingState.completed) {
          unawaited(_onTrackEnded());
        }
      });

      await _player.play();
      ApiService()
          .playTrack(
            _playbackLookupId,
            title: title,
            artist: artist,
            genre: _track?['genre']?.toString(),
            coverUrl: coverUrl,
          )
          .catchError((_) {});
      notifyListeners();
    } catch (_) {
      _audioReady = false;
      notifyListeners();
    }
  }

  Future<void> _onTrackEnded() async {
    final justSeeked = _lastSeekAt != null &&
        DateTime.now().difference(_lastSeekAt!) <
            const Duration(milliseconds: 1800);
    final nearEnd = _duration > Duration.zero &&
        _position >= _duration - const Duration(milliseconds: 900);
    if (justSeeked && !nearEnd) {
      return;
    }

    _trackEnded = true;
    notifyListeners();

    if (_repeatMode == 2) {
      if (_usingYoutube && _ytController != null) {
        _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
        _ytController!.playVideo();
      } else if (_audioReady) {
        await _player.seek(Duration.zero);
        await _player.play();
      }
      return;
    }
    await nextTrack();
  }

  Future<void> _resetPlayback() async {
    await _ytStateSubscription?.cancel();
    await _ytPositionSubscription?.cancel();
    await _audioPositionSubscription?.cancel();
    await _audioDurationSubscription?.cancel();
    await _audioStateSubscription?.cancel();
    _ytStateSubscription = null;
    _ytPositionSubscription = null;
    _audioPositionSubscription = null;
    _audioDurationSubscription = null;
    _audioStateSubscription = null;
    _ytController?.close();
    _ytController = null;
    await _player.stop();
  }

  void _startProgressHeartbeat() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isPlaying && trackId.isNotEmpty) {
        final progressMs = _position.inMilliseconds;
        final completed = _duration.inMilliseconds > 0 &&
            progressMs >= _duration.inMilliseconds - 5000;
        ApiService().updateTrackProgress(trackId, progressMs, completed);
      }
    });
  }

  List<Map<String, dynamic>> _extractQueue(Map<String, dynamic> seedTrack) {
    final rawQueue = seedTrack['queue'] ?? seedTrack['tracks'];
    if (rawQueue is List) {
      final items = rawQueue
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (items.isNotEmpty) return items;
    }
    return [Map<String, dynamic>.from(seedTrack)];
  }

  void _syncQueueIndex(Map<String, dynamic> currentTrack) {
    final index = _queue.indexWhere((item) => _sameTrack(item, currentTrack));
    _queueIndex = index >= 0 ? index : 0;
  }

  Future<void> _ensureQueue() async {
    if (_queue.length > 1 || (artist.isEmpty && title.isEmpty)) return;

    try {
      final results = await ApiService()
          .searchTracksWithFallback('$artist $title', limit: 10);
      final merged = <Map<String, dynamic>>[
        if (_track != null) Map<String, dynamic>.from(_track!),
      ];
      for (final item in results) {
        final track = Map<String, dynamic>.from(item);
        if (!merged.any((existing) => _sameTrack(existing, track))) {
          merged.add(track);
        }
      }
      if (merged.length <= 1) return;
      _queue = merged;
      _syncQueueIndex(_track!);
      notifyListeners();
    } catch (_) {}
  }

  bool _sameTrack(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = (a['spotify_id'] ??
            a['deezer_id'] ??
            a['track_id'] ??
            a['trackId'] ??
            '')
        .toString();
    final bId = (b['spotify_id'] ??
            b['deezer_id'] ??
            b['track_id'] ??
            b['trackId'] ??
            '')
        .toString();
    if (aId.isNotEmpty && bId.isNotEmpty) return aId == bId;
    return (a['title'] ?? a['trackName']).toString() ==
            (b['title'] ?? b['trackName']).toString() &&
        (a['artist'] ?? a['artistName']).toString() ==
            (b['artist'] ?? b['artistName']).toString();
  }

  Map<String, dynamic> _fillTrackData(
    Map<String, dynamic> current,
    Map<String, dynamic> resolved,
  ) {
    final merged = Map<String, dynamic>.from(current);
    resolved.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      final existing = merged[key];
      final isMissing =
          existing == null || (existing is String && existing.trim().isEmpty);
      if (isMissing) {
        merged[key] = value;
      }
    });
    return merged;
  }

  Future<Map<String, dynamic>> _enrichTrack(Map<String, dynamic> track) async {
    final title = (track['title'] ?? track['trackName'] ?? '').toString();
    final artist = (track['artist'] ?? track['artistName'] ?? '').toString();
    final trackId = (track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            track['trackId'] ??
            '')
        .toString();
    final hasPreview =
        (track['preview_url'] ?? track['previewUrl'])?.toString().isNotEmpty ==
            true;
    final hasCover =
        (track['cover_url'] ?? track['artworkUrl100'])?.toString().isNotEmpty ==
            true;
    final hasArtistId = track['artist_id'] != null;

    if (title.isEmpty ||
        (trackId.isNotEmpty && hasPreview && hasCover && hasArtistId)) {
      return Map<String, dynamic>.from(track);
    }

    try {
      final resolved = await ApiService().resolveTrack(
        title: title,
        artist: artist,
        trackId: trackId.isEmpty ? null : trackId,
      );
      if (resolved == null) {
        return Map<String, dynamic>.from(track);
      }
      return _fillTrackData(track, resolved);
    } catch (_) {
      return Map<String, dynamic>.from(track);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_ytStateSubscription?.cancel());
    unawaited(_ytPositionSubscription?.cancel());
    unawaited(_audioPositionSubscription?.cancel());
    unawaited(_audioDurationSubscription?.cancel());
    unawaited(_audioStateSubscription?.cancel());
    _ytController?.close();
    unawaited(_player.stop());
    unawaited(_player.dispose());
    super.dispose();
  }
}
