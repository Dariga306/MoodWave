import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'lyrics_screen.dart';
import 'modals.dart';
import 'queue_screen.dart';

class _LrcLine {
  final Duration time;
  final String text;

  const _LrcLine({
    required this.time,
    required this.text,
  });
}

List<_LrcLine> _parseLrc(String lrc) {
  final lines = <_LrcLine>[];
  final regex = RegExp(r'\[(\d+):(\d+)[.:](\d+)\]\s*(.*)');
  for (final raw in lrc.split('\n')) {
    final match = regex.firstMatch(raw.trim());
    if (match == null) continue;

    final mins = int.parse(match.group(1)!);
    final secs = int.parse(match.group(2)!);
    final csRaw = match.group(3)!.padRight(2, '0').substring(0, 2);
    final centiseconds = int.parse(csRaw);
    final text = match.group(4)!.trim();
    if (text.isEmpty) continue;

    lines.add(
      _LrcLine(
        time: Duration(
          minutes: mins,
          seconds: secs,
          milliseconds: centiseconds * 10,
        ),
        text: text,
      ),
    );
  }
  return lines;
}

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic>? track;

  const PlayerScreen({super.key, this.track});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late Map<String, dynamic> _track;

  final _player = AudioPlayer();

  yt.YoutubePlayerController? _ytController;
  StreamSubscription? _ytStateSubscription;
  StreamSubscription<Duration>? _ytPositionSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;

  List<Map<String, dynamic>> _queue = [];
  int _queueIndex = 0;

  bool _loadingTrack = true;
  bool _ytReady = false;
  bool _audioReady = false;
  bool _ytPlaying = false;
  bool _audioPlaying = false;
  bool _noPreview = false;
  bool _isLiked = false;
  bool _shuffle = false;
  int _repeatMode = 0; // 0=off 1=repeat-all 2=repeat-one

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _lyricsLoading = false;
  bool _lyricsSynced = false;
  List<_LrcLine> _lrcLines = [];
  int _currentLyricIdx = -1;

  String get _title =>
      (_track['title'] ?? _track['trackName'] ?? 'Unknown').toString();
  String get _artist =>
      (_track['artist'] ?? _track['artistName'] ?? '').toString();
  String? get _coverUrl =>
      (_track['cover_url'] ?? _track['artworkUrl100'])?.toString();
  String get _trackId =>
      (_track['spotify_id'] ?? _track['deezer_id'] ?? _track['trackId'] ?? '')
          .toString();
  bool get _usingYoutube => _ytReady && _ytController != null;
  bool get _isPlaying => _usingYoutube ? _ytPlaying : _audioPlaying;

  List<String> get _lyricsLines => _lrcLines.map((line) => line.text).toList();
  List<int> get _lyricsTimesMs =>
      _lrcLines.map((line) => line.time.inMilliseconds).toList();

  String? get _currentLyricLine {
    if (_lrcLines.isEmpty) return null;
    if (_lyricsSynced &&
        _currentLyricIdx >= 0 &&
        _currentLyricIdx < _lrcLines.length) {
      return _lrcLines[_currentLyricIdx].text;
    }
    return _lrcLines.first.text;
  }

  @override
  void initState() {
    super.initState();
    _track = Map<String, dynamic>.from(widget.track ?? const {});
    _queue = _extractQueue(_track);
    _syncQueueIndex();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _loadTrack(_track, refreshQueue: false);
    unawaited(_ensureQueue());
  }

  @override
  void dispose() {
    _floatController.dispose();
    _ytStateSubscription?.cancel();
    _ytPositionSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _ytController?.close();
    _player.dispose();
    super.dispose();
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

  bool _sameTrack(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId =
        (a['spotify_id'] ?? a['deezer_id'] ?? a['trackId'] ?? '').toString();
    final bId =
        (b['spotify_id'] ?? b['deezer_id'] ?? b['trackId'] ?? '').toString();
    if (aId.isNotEmpty && bId.isNotEmpty) return aId == bId;
    return (a['title'] ?? a['trackName']).toString() ==
            (b['title'] ?? b['trackName']).toString() &&
        (a['artist'] ?? a['artistName']).toString() ==
            (b['artist'] ?? b['artistName']).toString();
  }

  void _syncQueueIndex() {
    final index = _queue.indexWhere((item) => _sameTrack(item, _track));
    _queueIndex = index >= 0 ? index : 0;
  }

  Future<void> _ensureQueue() async {
    if (_queue.length > 1 || _artist.isEmpty && _title.isEmpty) return;

    try {
      final results =
          await ApiService().searchTracks('$_artist $_title', limit: 10);
      final merged = <Map<String, dynamic>>[Map<String, dynamic>.from(_track)];
      for (final item in results.whereType<Map>()) {
        final track = Map<String, dynamic>.from(item);
        if (!merged.any((existing) => _sameTrack(existing, track))) {
          merged.add(track);
        }
      }
      if (!mounted || merged.length <= 1) return;
      setState(() {
        _queue = merged;
        _syncQueueIndex();
      });
    } catch (_) {}
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

  Future<void> _loadTrack(
    Map<String, dynamic> nextTrack, {
    bool refreshQueue = true,
  }) async {
    await _resetPlayback();
    if (!mounted) return;

    setState(() {
      _track = Map<String, dynamic>.from(nextTrack);
      _ytReady = false;
      _audioReady = false;
      _ytPlaying = false;
      _audioPlaying = false;
      _noPreview = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lyricsLoading = false;
      _lyricsSynced = false;
      _lrcLines = [];
      _currentLyricIdx = -1;
      _loadingTrack = true;
    });

    _syncQueueIndex();
    await Future.wait([
      _initPlayer(),
      _fetchLyrics(),
    ]);

    if (mounted) {
      setState(() => _loadingTrack = false);
    }

    if (refreshQueue) {
      unawaited(_ensureQueue());
    }
  }

  Future<void> _initPlayer() async {
    if (_title.isEmpty) return;

    try {
      final videoId = await ApiService().getYouTubeId(
        trackId: _trackId,
        title: _title,
        artist: _artist,
      );
      if (videoId != null && videoId.isNotEmpty) {
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
          if (!mounted) return;
          setState(() {
            _ytPlaying = value.playerState == yt.PlayerState.playing;
            if (value.metaData.duration > Duration.zero) {
              _duration = value.metaData.duration;
            }
          });
          if (value.playerState == yt.PlayerState.ended) {
            _onTrackEnded();
          }
        });

        _ytPositionSubscription = controller
            .getCurrentPositionStream(
          period: const Duration(milliseconds: 500),
        )
            .listen((position) {
          if (!mounted) return;
          setState(() => _position = position);
          _updateLyricIdx(position);
        });

        if (mounted) {
          setState(() {
            _ytController = controller;
            _ytReady = true;
          });
        }

        if (_trackId.isNotEmpty) {
          ApiService().playTrack(_trackId).catchError((_) {});
        }
        return;
      }
    } catch (_) {}

    await _initPreview();
  }

  Future<void> _initPreview() async {
    String? url = (_track['preview_url'] ?? _track['previewUrl']) as String?;

    if (url == null || url.isEmpty) {
      try {
        final query = Uri.encodeComponent('$_title $_artist');
        final response = await http.get(
          Uri.parse(
            'https://itunes.apple.com/search?term=$query&media=music&limit=5',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>? ?? [];
          for (final item in results) {
            final candidate =
                (item as Map<String, dynamic>)['previewUrl'] as String?;
            if (candidate != null && candidate.isNotEmpty) {
              url = candidate;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _noPreview = true);
      return;
    }

    try {
      await _player.setUrl(url);
      _duration = _player.duration ?? Duration.zero;
      _audioReady = true;

      _audioPositionSubscription = _player.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
        _updateLyricIdx(position);
      });
      _audioDurationSubscription = _player.durationStream.listen((duration) {
        if (!mounted || duration == null) return;
        setState(() => _duration = duration);
      });
      _audioStateSubscription = _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _audioPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _onTrackEnded();
        }
      });

      await _player.play();
      if (_trackId.isNotEmpty) {
        ApiService().playTrack(_trackId).catchError((_) {});
      }
      if (mounted) {
        setState(() => _audioReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioReady = false;
          _noPreview = true;
        });
      }
    }
  }

  Future<void> _fetchLyrics() async {
    if (_title.isEmpty) return;
    if (mounted) setState(() => _lyricsLoading = true);

    try {
      final title = Uri.encodeComponent(_title);
      final artist = Uri.encodeComponent(_artist);
      final response = await http
          .get(
            Uri.parse(
              'https://lrclib.net/api/get?track_name=$title&artist_name=$artist',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        final plain = data['plainLyrics'] as String?;

        if (synced != null && synced.isNotEmpty) {
          final lines = _parseLrc(synced);
          if (lines.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _lrcLines = lines;
              _lyricsSynced = true;
              _lyricsLoading = false;
            });
            _updateLyricIdx(_position);
            return;
          }
        }

        if (plain != null && plain.isNotEmpty) {
          final lines = plain
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .map((line) => _LrcLine(time: Duration.zero, text: line))
              .toList();
          if (!mounted) return;
          setState(() {
            _lrcLines = lines;
            _lyricsSynced = false;
            _lyricsLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (_artist.isNotEmpty) {
      try {
        final title = Uri.encodeComponent(_title);
        final artist = Uri.encodeComponent(_artist);
        final response = await http
            .get(Uri.parse('https://api.lyrics.ovh/v1/$artist/$title'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final raw = data['lyrics'] as String? ?? '';
          final lines = raw
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .map((line) => _LrcLine(time: Duration.zero, text: line))
              .toList();
          if (!mounted) return;
          setState(() {
            _lrcLines = lines;
            _lyricsSynced = false;
            _lyricsLoading = false;
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _lyricsLoading = false);
  }

  void _updateLyricIdx(Duration position) {
    if (!_lyricsSynced || _lrcLines.isEmpty) return;

    int nextIndex = -1;
    for (int i = 0; i < _lrcLines.length; i++) {
      if (_lrcLines[i].time <= position) {
        nextIndex = i;
      } else {
        break;
      }
    }

    if (nextIndex != _currentLyricIdx && mounted) {
      setState(() => _currentLyricIdx = nextIndex);
    }
  }

  void _togglePlayPause() {
    if (_usingYoutube && _ytController != null) {
      _ytPlaying ? _ytController!.pauseVideo() : _ytController!.playVideo();
      return;
    }
    if (_audioReady) {
      _audioPlaying ? _player.pause() : _player.play();
    }
  }

  Future<void> _toggleLike() async {
    if (_trackId.isEmpty) return;
    try {
      await ApiService().likeTrack(_trackId);
      if (!mounted) return;
      setState(() => _isLiked = !_isLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to Liked Songs'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not like this track')),
      );
    }
  }

  Future<void> _loadRelativeTrack(int delta) async {
    await _ensureQueue();
    if (_queue.isEmpty) return;

    final nextIndex = (_queueIndex + delta).clamp(0, _queue.length - 1);
    if (nextIndex == _queueIndex) return;

    setState(() => _queueIndex = nextIndex);
    await _loadTrack(_queue[nextIndex], refreshQueue: false);
  }

  void _onTrackEnded() {
    if (_repeatMode == 2) {
      // repeat one — restart
      if (_usingYoutube && _ytController != null) {
        _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
        _ytController!.playVideo();
      } else if (_audioReady) {
        _player.seek(Duration.zero);
        _player.play();
      }
      return;
    }
    _skipNext();
  }

  Future<void> _skipNext() async {
    await _ensureQueue();
    if (_queue.isEmpty) return;

    if (_shuffle) {
      final indices = List.generate(_queue.length, (i) => i)
        ..remove(_queueIndex);
      if (indices.isEmpty) {
        if (_repeatMode == 1) {
          await _loadTrack(_queue[_queueIndex], refreshQueue: false);
        }
        return;
      }
      indices.shuffle();
      final next = indices.first;
      setState(() => _queueIndex = next);
      await _loadTrack(_queue[next], refreshQueue: false);
      return;
    }

    final next = _queueIndex + 1;
    if (next >= _queue.length) {
      if (_repeatMode == 1) {
        setState(() => _queueIndex = 0);
        await _loadTrack(_queue[0], refreshQueue: false);
      }
      return;
    }
    setState(() => _queueIndex = next);
    await _loadTrack(_queue[next], refreshQueue: false);
  }

  Future<void> _skipPrevious() async {
    if (_position.inSeconds > 3) {
      // restart current track if >3s played
      if (_usingYoutube && _ytController != null) {
        _ytController!.seekTo(seconds: 0, allowSeekAhead: true);
      } else if (_audioReady) {
        _player.seek(Duration.zero);
      }
      setState(() => _position = Duration.zero);
      return;
    }
    await _loadRelativeTrack(-1);
  }

  void _openLyricsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsScreen(
          artist: _artist,
          title: _title,
          lyricsLines: _lyricsLines,
          currentPosition: _position,
          syncedLineTimesMs: _lyricsTimesMs,
        ),
      ),
    );
  }

  String _fmt(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0240), Color(0xFF0D0D20), Color(0xFF001230)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 60,
              left: -40,
              child: _orb(200, AppColors.purple.withOpacity(0.3)),
            ),
            Positioned(
              top: 120,
              right: -20,
              child: _orb(180, AppColors.pink.withOpacity(0.25)),
            ),
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: _orb(300, AppColors.blue.withOpacity(0.15)),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _topBar(),
                      const SizedBox(height: 28),
                      _coverArtBox(),
                      if (_currentLyricLine != null &&
                          _currentLyricLine!.isNotEmpty)
                        GestureDetector(
                          onTap: _openLyricsScreen,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _currentLyricLine!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap for full lyrics',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _titleRow(),
                      if (_ytController != null)
                        SizedBox(
                          height: 1,
                          width: 1,
                          child: yt.YoutubePlayer(controller: _ytController!),
                        ),
                      const SizedBox(height: 12),
                      _progressBar(),
                      const SizedBox(height: 28),
                      _controls(),
                      const SizedBox(height: 28),
                      _extraActions(),
                      if (_noPreview)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'Playback source unavailable for this track.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.text3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );

  Widget _topBar() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            'Now Playing',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text3,
            ),
          ),
          const SizedBox(width: 40),
        ],
      );

  Widget _coverArtBox() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, -8 * _floatController.value),
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            gradient: AppColors.gradMixed,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleDark.withOpacity(0.4),
                blurRadius: 60,
              ),
              BoxShadow(
                color: AppColors.pink.withOpacity(0.2),
                blurRadius: 120,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 60,
                offset: const Offset(0, 30),
              ),
            ],
          ),
          child: _coverUrl != null && _coverUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: CachedNetworkImage(
                    imageUrl: _coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: Text('🌊', style: TextStyle(fontSize: 100)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 100)),
                    ),
                  ),
                )
              : const Center(
                  child: Text('🌊', style: TextStyle(fontSize: 100)),
                ),
        ),
      ),
    );
  }

  Widget _titleRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _artist,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: const Color(0xB3C8B4FF),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleLike,
            icon: Icon(
              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isLiked ? AppColors.pink : AppColors.text2,
              size: 24,
            ),
          ),
        ],
      );

  Widget _progressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.purple,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: AppColors.purple.withOpacity(0.2),
          ),
          child: Slider(
            value: _duration.inMilliseconds > 0
                ? (_position.inMilliseconds / _duration.inMilliseconds)
                    .clamp(0.0, 1.0)
                : 0.0,
            onChanged: (value) {
              final ms = (value * _duration.inMilliseconds).round();
              if (_ytReady && _ytController != null) {
                _ytController!.seekTo(
                  seconds: ms / 1000,
                  allowSeekAhead: true,
                );
              } else if (_audioReady) {
                _player.seek(Duration(milliseconds: ms));
              }
              setState(() => _position = Duration(milliseconds: ms));
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(_position),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
            Text(
              _fmt(_duration),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _controls() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => setState(() => _shuffle = !_shuffle),
            icon: Icon(
              Icons.shuffle_rounded,
              size: 22,
              color: _shuffle ? AppColors.purpleLight : AppColors.text3,
            ),
          ),
          IconButton(
            onPressed: _skipPrevious,
            icon: const Icon(
              Icons.skip_previous_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: _loadingTrack ? null : _togglePlayPause,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtn,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purpleDark.withOpacity(0.5),
                    blurRadius: 30,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _loadingTrack
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
            ),
          ),
          IconButton(
            onPressed: _skipNext,
            icon: const Icon(
              Icons.skip_next_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _repeatMode = (_repeatMode + 1) % 3),
            icon: Icon(
              _repeatMode == 2
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 22,
              color: _repeatMode > 0 ? AppColors.purpleLight : AppColors.text3,
            ),
          ),
        ],
      );

  Widget _extraActions() => Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: _lyricsLines.isEmpty ? null : _openLyricsScreen,
              child: _ExtraBtn(
                icon: Icons.lyrics_outlined,
                label: 'Lyrics',
                active: _lyricsLines.isNotEmpty || _lyricsLoading,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QueueScreen()),
              ),
              child: const _ExtraBtn(
                icon: Icons.queue_music_rounded,
                label: 'Queue',
              ),
            ),
            GestureDetector(
              onTap: () => showShareTrack(context),
              child: const _ExtraBtn(
                icon: Icons.share_outlined,
                label: 'Share',
              ),
            ),
            GestureDetector(
              onTap: () => showAddToPlaylist(context),
              child: const _ExtraBtn(
                icon: Icons.playlist_play_rounded,
                label: 'Playlist',
              ),
            ),
          ],
        ),
      );
}

class _ExtraBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ExtraBtn({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: active ? AppColors.purpleLight : AppColors.text3,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.purpleLight : AppColors.text3,
          ),
        ),
      ],
    );
  }
}
