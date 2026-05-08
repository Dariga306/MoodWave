import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'artist_screen.dart';
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

String _normalizeLookupText(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'\((official|audio|lyrics?|video|live).*?\)'), ' ')
      .replaceAll(RegExp(r'\[(official|audio|lyrics?|video|live).*?\]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> _lookupTokens(String value) {
  return _normalizeLookupText(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();
}

String _stripTrackVersion(String value) {
  return value
      .replaceAll(RegExp(r'\((feat|ft|with).*?\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\[(feat|ft|with).*?\]', caseSensitive: false), ' ')
      .replaceAll(
          RegExp(r'\((live|remaster(ed)?|sped up|slowed|version).*?\)',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(r'\[(live|remaster(ed)?|sped up|slowed|version).*?\]',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(r'\s+-\s+(live|remaster(ed)?|sped up|slowed).*$',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
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
  late final PlayerProvider _playback;
  late Map<String, dynamic> _track;

  bool _loadingTrack = true;
  bool _trackEnded = false;
  bool _isLiked = false;
  bool _shuffle = false;
  int _repeatMode = 0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isScrubbing = false;
  double? _scrubValue;

  bool _lyricsLoading = false;
  bool _lyricsSynced = false;
  List<_LrcLine> _lrcLines = [];
  int _currentLyricIdx = -1;
  String _lyricsTrackKey = '';

  Timer? _sleepTimer;
  int? _sleepMinutesLeft;

  String get _title =>
      (_track['title'] ?? _track['trackName'] ?? 'Unknown').toString();
  String get _artist =>
      (_track['artist'] ?? _track['artistName'] ?? '').toString();
  String? get _coverUrl =>
      (_track['cover_url'] ?? _track['artworkUrl100'])?.toString();
  String get _trackId => (_track['spotify_id'] ??
          _track['deezer_id'] ??
          _track['track_id'] ??
          _track['trackId'] ??
          '')
      .toString();
  bool get _isPlaying => _playback.isPlaying;
  String get _playbackLookupId {
    if (_trackId.isNotEmpty) {
      return _trackId;
    }
    final seed = '$_artist $_title'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return seed.isEmpty ? 'track_lookup' : 'query:$seed';
  }

  List<String> get _lyricsLines => _lrcLines.map((line) => line.text).toList();
  List<int> get _lyricsTimesMs =>
      _lrcLines.map((line) => line.time.inMilliseconds).toList();
  String get _album =>
      (_track['album'] ?? _track['collectionName'] ?? '').toString();
  Duration get _seekableDuration =>
      _playback.duration > Duration.zero ? _playback.duration : _duration;

  List<Map<String, dynamic>> get _artistEntries {
    final rawArtists = _track['artists'];
    if (rawArtists is List) {
      final artists = rawArtists
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
              (item) => (item['name']?.toString().trim().isNotEmpty ?? false))
          .toList();
      if (artists.isNotEmpty) {
        return artists;
      }
    }

    final names = _artist
        .split(RegExp(r'\s*(?:,| feat\. | ft\. | & )\s*', caseSensitive: false))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return names
        .map((name) => <String, dynamic>{'id': null, 'name': name})
        .toList();
  }

  String get _primaryArtist => _artistEntries.isNotEmpty
      ? (_artistEntries.first['name'] ?? '').toString()
      : _artist;

  List<String> get _titleVariants {
    final variants = <String>{};
    final raw = _title.trim();
    if (raw.isNotEmpty) {
      variants.add(raw);
      final stripped = _stripTrackVersion(raw);
      if (stripped.isNotEmpty) {
        variants.add(stripped);
      }
    }
    return variants.where((value) => value.isNotEmpty).toList();
  }

  List<String> get _artistVariants {
    final variants = <String>{};
    final full = _artist.trim();
    if (full.isNotEmpty) {
      variants.add(full);
    }
    final primary = _primaryArtist.trim();
    if (primary.isNotEmpty) {
      variants.add(primary);
    }
    for (final artist in _artistEntries) {
      final name = (artist['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        variants.add(name);
      }
    }
    return variants.toList();
  }

  String? get _currentLyricLine {
    if (!_lyricsSynced || _lrcLines.isEmpty) return null;
    final idx = _currentLyricIdx >= 0 ? _currentLyricIdx : 0;
    if (idx < _lrcLines.length) return _lrcLines[idx].text;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlayerProvider>();
    _track = Map<String, dynamic>.from(
      _playback.track ?? widget.track ?? const {},
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _playback.addListener(_handlePlaybackChanged);
    _handlePlaybackChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requestedTrack = widget.track;
      if (requestedTrack != null) {
        final currentTrack = _playback.track;
        if (currentTrack == null || !_sameTrack(currentTrack, requestedTrack)) {
          final prepared = _prepareRequestedTrack(requestedTrack);
          final preserveQueue = _trackExistsInQueue(
            requestedTrack,
            _playback.queue,
          );
          unawaited(
            _playback.openTrack(
              prepared,
              refreshQueue: !preserveQueue,
            ),
          );
          return;
        }
      }
      _maybeRefreshLyrics(force: true);
    });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _floatController.dispose();
    _playback.removeListener(_handlePlaybackChanged);
    super.dispose();
  }

  Map<String, dynamic> _prepareRequestedTrack(Map<String, dynamic> track) {
    final prepared = Map<String, dynamic>.from(track);
    final existingQueue = _playback.queue;
    final hasOwnQueue = prepared['queue'] is List || prepared['tracks'] is List;
    if (!hasOwnQueue && _trackExistsInQueue(prepared, existingQueue)) {
      prepared['queue'] =
          existingQueue.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return prepared;
  }

  bool _trackExistsInQueue(
    Map<String, dynamic> track,
    List<Map<String, dynamic>> queue,
  ) {
    return queue.any((item) => _sameTrack(item, track));
  }

  String _trackStateKey(Map<String, dynamic>? track) {
    if (track == null) return '';
    final id = (track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            track['trackId'] ??
            '')
        .toString();
    if (id.isNotEmpty) return id;
    return '${(track['artist'] ?? track['artistName'] ?? '')}::'
        '${(track['title'] ?? track['trackName'] ?? '')}';
  }

  void _handlePlaybackChanged() {
    if (!mounted) return;

    final providerTrack = _playback.track;
    if (providerTrack == null) {
      setState(() {
        _loadingTrack = false;
        _trackEnded = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      return;
    }

    final nextTrack = Map<String, dynamic>.from(providerTrack);
    final nextKey = _trackStateKey(nextTrack);
    final oldKey = _trackStateKey(_track);

    setState(() {
      _track = nextTrack;
      _loadingTrack = _playback.loadingTrack;
      _trackEnded = _playback.trackEnded;
      _position = _playback.position;
      _duration = _playback.duration;
      _shuffle = _playback.shuffleOn;
      _repeatMode = _playback.repeatMode;
      _updateLyricIdx(_position);
    });

    if (nextKey != oldKey) {
      _maybeRefreshLyrics(force: true);
    }
  }

  void _maybeRefreshLyrics({bool force = false}) {
    final key = _trackStateKey(_track);
    if (!force && key == _lyricsTrackKey) return;
    _lyricsTrackKey = key;
    setState(() {
      _lrcLines = [];
      _lyricsSynced = false;
      _currentLyricIdx = -1;
    });
    unawaited(_fetchLyrics());
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

  Future<void> _fetchLyrics() async {
    if (_title.isEmpty) return;
    if (mounted) {
      setState(() => _lyricsLoading = true);
    }
    final durationSeconds = _duration.inSeconds > 0
        ? _duration.inSeconds
        : (((_track['duration_ms'] as int?) ?? 0) ~/ 1000);
    final albumName = _album.trim();
    final queries = <Map<String, String>>[];
    for (final title in _titleVariants) {
      for (final artist in _artistVariants) {
        queries.add({
          'title': title,
          'artist': artist,
          if (albumName.isNotEmpty) 'album': albumName,
        });
      }
    }
    if (queries.isEmpty) {
      queries.add({
        'title': _title,
        'artist': _primaryArtist,
        if (albumName.isNotEmpty) 'album': albumName,
      });
    }

    try {
      final seenKeys = <String>{};
      final candidates = <Map<String, dynamic>>[];
      for (final query in queries.take(8)) {
        final encodedTitle = Uri.encodeComponent(query['title'] ?? '');
        final encodedArtist = Uri.encodeComponent(query['artist'] ?? '');
        final encodedAlbum = (query['album']?.isNotEmpty ?? false)
            ? Uri.encodeComponent(query['album']!)
            : null;
        final response = await http
            .get(
              Uri.parse(
                'https://lrclib.net/api/search?track_name=$encodedTitle&artist_name=$encodedArtist'
                '${encodedAlbum != null ? '&album_name=$encodedAlbum' : ''}'
                '${durationSeconds > 0 ? '&duration=$durationSeconds' : ''}',
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final raw = jsonDecode(response.body);
        if (raw is! List) continue;
        for (final candidate in raw.whereType<Map>()) {
          final lyricsMap = Map<String, dynamic>.from(candidate);
          final key = '${lyricsMap['id'] ?? ''}'
              '${lyricsMap['trackName'] ?? lyricsMap['name'] ?? ''}'
              '${lyricsMap['artistName'] ?? lyricsMap['artist'] ?? ''}';
          if (!seenKeys.add(key)) continue;
          candidates.add(lyricsMap);
        }
      }
      if (candidates.isNotEmpty) {
        int score(Map<String, dynamic> item) {
          final itemTitle =
              (item['trackName'] ?? item['name'] ?? item['track_name'] ?? '')
                  .toString();
          final itemArtist = (item['artistName'] ??
                  item['artist'] ??
                  item['artist_name'] ??
                  '')
              .toString();
          final synced =
              (item['syncedLyrics'] as String?)?.isNotEmpty == true ? 1000 : 0;
          final plain =
              (item['plainLyrics'] as String?)?.isNotEmpty == true ? 250 : 0;
          final itemTitleTokens = _lookupTokens(itemTitle);
          final itemArtistTokens = _lookupTokens(itemArtist);
          final titleScores = _titleVariants.map((title) {
            final titleTokens = _lookupTokens(title);
            final matches = titleTokens.intersection(itemTitleTokens).length;
            return titleTokens.isNotEmpty
                ? matches * 110 + (matches == titleTokens.length ? 260 : 0)
                : 0;
          });
          final artistScores = _artistVariants.map((artist) {
            final artistTokens = _lookupTokens(artist);
            final matches = artistTokens.intersection(itemArtistTokens).length;
            return artistTokens.isNotEmpty
                ? matches * 130 + (matches == artistTokens.length ? 320 : 0)
                : 0;
          });
          final titleBonus = titleScores.isEmpty
              ? 0
              : titleScores.reduce((a, b) => a > b ? a : b);
          final artistBonus = artistScores.isEmpty
              ? 0
              : artistScores.reduce((a, b) => a > b ? a : b);
          final itemDuration =
              (item['duration'] as num?)?.toInt() ?? durationSeconds;
          final durationPenalty = durationSeconds > 0
              ? (durationSeconds - itemDuration).abs() * 2
              : 0;
          final albumBonus = albumName.isNotEmpty &&
                  (item['albumName']?.toString().toLowerCase() ==
                      albumName.toLowerCase())
              ? 80
              : 0;
          return synced +
              plain +
              titleBonus +
              artistBonus +
              albumBonus -
              durationPenalty;
        }

        candidates.sort((a, b) => score(b).compareTo(score(a)));

        for (final lyricsMap in candidates) {
          final candidateTitle = (lyricsMap['trackName'] ??
                  lyricsMap['name'] ??
                  lyricsMap['track_name'] ??
                  '')
              .toString();
          final candidateArtist = (lyricsMap['artistName'] ??
                  lyricsMap['artist'] ??
                  lyricsMap['artist_name'] ??
                  '')
              .toString();
          final candidateDuration =
              (lyricsMap['duration'] as num?)?.toInt() ?? 0;
          final titleMatch = _titleVariants.any((title) => _lookupTokens(title)
              .intersection(_lookupTokens(candidateTitle))
              .isNotEmpty);
          final artistMatch = _artistVariants.any((artist) =>
              _lookupTokens(artist)
                  .intersection(_lookupTokens(candidateArtist))
                  .isNotEmpty);
          if (!titleMatch || !artistMatch) {
            continue;
          }
          if (durationSeconds > 0 &&
              candidateDuration > 0 &&
              (durationSeconds - candidateDuration).abs() > 10) {
            continue;
          }
          if (await _applyLyricsPayload(lyricsMap)) {
            return;
          }
        }
      }
    } catch (_) {}

    if (_artistVariants.isNotEmpty) {
      try {
        for (final query in queries.take(4)) {
          final response = await http
              .get(
                Uri.parse(
                  'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(query['title'] ?? '')}'
                  '&artist_name=${Uri.encodeComponent(query['artist'] ?? '')}',
                ),
              )
              .timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            if (await _applyLyricsPayload(data)) {
              return;
            }
          }
        }
      } catch (_) {}

      try {
        for (final query in queries.take(3)) {
          final encodedArtist = Uri.encodeComponent(query['artist'] ?? '');
          final encodedTitle = Uri.encodeComponent(query['title'] ?? '');
          final response = await http
              .get(Uri.parse(
                  'https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle'))
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
            if (lines.isEmpty) {
              continue;
            }
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
    }

    if (mounted) {
      setState(() => _lyricsLoading = false);
    }
  }

  Future<bool> _applyLyricsPayload(Map<String, dynamic> data) async {
    final synced = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;

    if (synced != null && synced.isNotEmpty) {
      final lines = _parseLrc(synced);
      if (lines.isNotEmpty) {
        if (!mounted) return true;
        setState(() {
          _lrcLines = lines;
          _lyricsSynced = true;
          _lyricsLoading = false;
        });
        _updateLyricIdx(_position);
        return true;
      }
    }

    if (plain != null && plain.isNotEmpty) {
      final lines = plain
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => _LrcLine(time: Duration.zero, text: line))
          .toList();
      if (!mounted) return true;
      setState(() {
        _lrcLines = lines;
        _lyricsSynced = false;
        _lyricsLoading = false;
      });
      return true;
    }

    return false;
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

    _currentLyricIdx = nextIndex;
  }

  Future<void> _togglePlayPause() async {
    if (_trackEnded) {
      await _playback.restartCurrentTrack();
      return;
    }
    await _playback.togglePlayPause();
  }

  Future<void> _seekTo(Duration position) async {
    await _playback.seekTo(position);
    if (!mounted) return;
    final synced = _playback.position;
    setState(() {
      _position = synced;
      _updateLyricIdx(synced);
    });
  }

  Future<void> _toggleLike() async {
    if (_title.isEmpty) return;
    try {
      await ApiService().likeTrack(
        _playbackLookupId,
        title: _title,
        artist: _artist,
        genre: _track['genre']?.toString(),
      );
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

  Future<void> _skipNext() async {
    await _playback.nextTrack();
  }

  Future<void> _skipPrevious() async {
    await _playback.prevTrack();
  }

  Future<void> _openArtistProfile(Map<String, dynamic> artist) async {
    final name = (artist['name'] ?? '').toString().trim();
    if (name.isEmpty) return;
    final id = artist['id']?.toString() ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId:
              id.isNotEmpty ? id : name.toLowerCase().replaceAll(' ', '_'),
          artistName: name,
        ),
      ),
    );
  }

  void _openLyricsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsScreen(
          artist: _artist,
          title: _title,
          album: _album,
          duration: _seekableDuration,
          lyricsLines: _lyricsLines,
          currentPosition: _position,
          syncedLineTimesMs: _lyricsTimesMs,
          positionStream: _playback.positionStream,
          onSeek: (Duration pos) {
            unawaited(_seekTo(pos));
          },
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
                          onLongPress: _lyricsSynced && _currentLyricIdx >= 0
                              ? () => _seekTo(_lrcLines[_currentLyricIdx].time)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Text(
                              _currentLyricLine!,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.75),
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _titleRow(),
                      const SizedBox(height: 12),
                      _progressBar(),
                      const SizedBox(height: 28),
                      _controls(),
                      const SizedBox(height: 28),
                      _extraActions(),
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
            onTap: () => Navigator.of(context).maybePop(),
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
                Wrap(
                  spacing: 0,
                  children: () {
                    final artists = _artistEntries;
                    return artists.asMap().entries.map((entry) {
                      final artist = entry.value;
                      final name = (artist['name'] ?? '').toString();
                      final isLast = entry.key == artists.length - 1;
                      return GestureDetector(
                        onTap: () => _openArtistProfile(artist),
                        child: Text(
                          isLast ? name : '$name, ',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: const Color(0xB3C8B4FF),
                          ),
                        ),
                      );
                    }).toList();
                  }(),
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
    final effectiveDuration =
        _seekableDuration > Duration.zero ? _seekableDuration : _duration;
    final sliderValue = _isScrubbing
        ? (_scrubValue ?? 0.0)
        : (effectiveDuration.inMilliseconds > 0
            ? (_position.inMilliseconds / effectiveDuration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0);
    final displayPosition = _isScrubbing && effectiveDuration.inMilliseconds > 0
        ? Duration(
            milliseconds:
                (sliderValue * effectiveDuration.inMilliseconds).round(),
          )
        : _position;

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
            value: sliderValue,
            onChangeStart: effectiveDuration.inMilliseconds > 0
                ? (value) {
                    setState(() {
                      _isScrubbing = true;
                      _scrubValue = value;
                    });
                  }
                : null,
            onChanged: effectiveDuration.inMilliseconds > 0
                ? (value) => setState(() => _scrubValue = value)
                : null,
            onChangeEnd: effectiveDuration.inMilliseconds > 0
                ? (value) async {
                    final ms =
                        (value * effectiveDuration.inMilliseconds).round();
                    setState(() {
                      _isScrubbing = false;
                      _scrubValue = null;
                    });
                    await _seekTo(Duration(milliseconds: ms));
                  }
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(displayPosition),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
            Text(
              _fmt(effectiveDuration),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _playPauseGlyph() {
    if (_trackEnded) {
      return const Icon(
        Icons.replay_rounded,
        color: Colors.white,
        size: 34,
      );
    }
    if (!_isPlaying) {
      return const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 34,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (_) => Container(
          width: 6,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _controls() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _playback.toggleShuffle,
            icon: Icon(
              Icons.shuffle_rounded,
              size: 22,
              color: _shuffle ? AppColors.purpleLight : Colors.white54,
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
                  : _playPauseGlyph(),
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
            onPressed: () => _playback.cycleRepeatMode(),
            icon: Icon(
              _repeatMode == 2
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 22,
              color: _repeatMode > 0 ? AppColors.purpleLight : Colors.white54,
            ),
          ),
        ],
      );

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sleep Timer',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (_sleepMinutesLeft != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Off in ${_sleepMinutesLeft}m',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.purpleLight,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            for (final min in [5, 10, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                title: Text(
                  '$min minutes',
                  style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setSleepTimer(min);
                },
              ),
            if (_sleepTimer != null)
              ListTile(
                leading: const Icon(
                  Icons.timer_off_outlined,
                  color: AppColors.pink,
                  size: 20,
                ),
                title: Text(
                  'Cancel timer',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.pink,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _cancelSleepTimer();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutesLeft = minutes);
    var remaining = minutes;
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      remaining--;
      if (mounted) {
        setState(() => _sleepMinutesLeft = remaining);
      }
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_playback.pause());
        if (mounted) {
          setState(() => _sleepMinutesLeft = null);
        }
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (mounted) {
      setState(() => _sleepMinutesLeft = null);
    }
  }

  Widget _extraActions() => Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _title.isEmpty ? null : _openLyricsScreen,
              child: _ExtraBtn(
                icon: Icons.lyrics_outlined,
                label: 'Lyrics',
                active: _lyricsLines.isNotEmpty || _lyricsLoading,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QueueScreen(
                    currentTitle: _title,
                    currentArtist: _artist,
                    currentCover: _coverUrl,
                    queue: _playback.queue,
                    currentIndex: _playback.queueIndex,
                    shuffle: _shuffle,
                    repeatMode: _repeatMode,
                    onToggleShuffle: _playback.toggleShuffle,
                    onChangeRepeat: _playback.setRepeatMode,
                    onQueueReordered: _playback.replaceUpcomingQueue,
                  ),
                ),
              ),
              child: const _ExtraBtn(
                icon: Icons.queue_music_rounded,
                label: 'Queue',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showShareTrack(context, track: _track),
              child: const _ExtraBtn(
                icon: Icons.share_outlined,
                label: 'Share',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showAddToPlaylist(context, track: _track),
              child: const _ExtraBtn(
                icon: Icons.playlist_play_rounded,
                label: 'Playlist',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showSleepTimerDialog,
              child: _ExtraBtn(
                icon: Icons.bedtime_outlined,
                label: _sleepMinutesLeft != null
                    ? '${_sleepMinutesLeft}m'
                    : 'Sleep',
                active: _sleepTimer != null,
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
    return SizedBox(
      width: 58,
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? AppColors.purpleLight : AppColors.text3,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.purpleLight : AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
