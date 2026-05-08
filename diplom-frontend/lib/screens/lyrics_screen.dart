import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class SyncedLine {
  final int timeMs;
  final String text;

  const SyncedLine({
    required this.timeMs,
    required this.text,
  });
}

class LyricsScreen extends StatefulWidget {
  final String artist;
  final String title;
  final String album;
  final Duration duration;
  final List<String> lyricsLines;
  final Duration currentPosition;
  final List<int> syncedLineTimesMs;
  final void Function(Duration)? onSeek;
  final Stream<Duration>? positionStream;

  const LyricsScreen({
    super.key,
    required this.artist,
    required this.title,
    this.album = '',
    this.duration = Duration.zero,
    required this.lyricsLines,
    required this.currentPosition,
    this.syncedLineTimesMs = const [],
    this.onSeek,
    this.positionStream,
  });

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  final _activeKey = GlobalKey();

  Timer? _timer;
  StreamSubscription<Duration>? _positionSub;
  List<String> _lyricsLines = [];
  List<SyncedLine> _syncedLines = [];
  bool _loading = true;
  int _activeIndex = -1;
  int _currentPositionMs = 0;

  // For smooth interpolation between position updates
  int _lastReceivedPositionMs = 0;
  DateTime _lastPositionReceivedAt = DateTime.now();
  // Ignore stale stream events right after a seek
  DateTime? _seekedAt;

  String get _cleanTitle => widget.title
      .replaceAll(RegExp(r'\((feat|ft|with).*?\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\[(feat|ft|with).*?\]', caseSensitive: false), ' ')
      .replaceAll(
          RegExp(r'\((live|remaster(ed)?|version).*?\)', caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String get _primaryArtist => widget.artist
      .split(RegExp(r'\s*(?:,| feat\. | ft\. | & )\s*', caseSensitive: false))
      .map((item) => item.trim())
      .firstWhere((item) => item.isNotEmpty, orElse: () => widget.artist);

  // Extrapolates current position using wall-clock time since last update.
  // Capped at 500 ms so a paused player doesn't drift.
  int get _interpolatedPositionMs {
    if (_syncedLines.isEmpty) return _currentPositionMs;
    final elapsed =
        DateTime.now().difference(_lastPositionReceivedAt).inMilliseconds;
    return _lastReceivedPositionMs + elapsed.clamp(0, 500);
  }

  @override
  void initState() {
    super.initState();
    _currentPositionMs = widget.currentPosition.inMilliseconds;
    _lastReceivedPositionMs = _currentPositionMs;
    _lastPositionReceivedAt = DateTime.now();
    _seedInitialLyrics();
    if (widget.positionStream != null) {
      _positionSub = widget.positionStream!.listen((pos) {
        _lastReceivedPositionMs = pos.inMilliseconds;
        _lastPositionReceivedAt = DateTime.now();
        // Discard stale pre-seek positions for 1 second after a seek
        final msSinceSeek = _seekedAt == null
            ? 9999
            : DateTime.now().difference(_seekedAt!).inMilliseconds;
        if (msSinceSeek > 1000) {
          _currentPositionMs = pos.inMilliseconds;
          _updateActiveIndex();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant LyricsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      _currentPositionMs = widget.currentPosition.inMilliseconds;
      _updateActiveIndex();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _seedInitialLyrics() {
    if (widget.lyricsLines.isNotEmpty) {
      _lyricsLines = List<String>.from(widget.lyricsLines);
      if (widget.syncedLineTimesMs.length == widget.lyricsLines.length) {
        _syncedLines = List.generate(
          widget.lyricsLines.length,
          (index) => SyncedLine(
            timeMs: widget.syncedLineTimesMs[index],
            text: widget.lyricsLines[index],
          ),
        );
      }
      _loading = false;
      _startTicker();
      return;
    }
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    setState(() => _loading = true);

    try {
      final title = Uri.encodeComponent(
          _cleanTitle.isNotEmpty ? _cleanTitle : widget.title);
      final artist = Uri.encodeComponent(_primaryArtist);
      final album = widget.album.isNotEmpty
          ? '&album_name=${Uri.encodeComponent(widget.album)}'
          : '';
      final duration = widget.duration.inSeconds > 0
          ? '&duration=${widget.duration.inSeconds}'
          : '';
      final response = await http
          .get(
            Uri.parse(
              'https://lrclib.net/api/search?track_name=$title&artist_name=$artist$album$duration',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final candidates = data.whereType<Map>().cast<Map>().toList()
          ..sort((a, b) => _lyricsScore(b).compareTo(_lyricsScore(a)));
        for (final item in candidates) {
          final map = Map<String, dynamic>.from(item);
          if (!_looksLikeRequestedSong(map)) continue;
          final syncedLyrics = map['syncedLyrics'] as String?;
          if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
            final lines = _parseSyncedLyrics(syncedLyrics);
            if (lines.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _syncedLines = lines;
                _lyricsLines = lines.map((line) => line.text).toList();
                _loading = false;
              });
              _startTicker();
              return;
            }
          }
        }
      }
    } catch (_) {}

    try {
      final title = Uri.encodeComponent(
          _cleanTitle.isNotEmpty ? _cleanTitle : widget.title);
      final artist = Uri.encodeComponent(_primaryArtist);
      final response = await http
          .get(Uri.parse('https://api.lyrics.ovh/v1/$artist/$title'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['lyrics'] as String? ?? '';
        final lines = raw
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _lyricsLines = lines;
          _syncedLines = [];
          _activeIndex = -1;
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  int _lyricsScore(Map item) {
    final itemTitle = (item['trackName'] ?? item['name'] ?? '').toString();
    final itemArtist = (item['artistName'] ?? item['artist'] ?? '').toString();
    final itemAlbum = (item['albumName'] ?? '').toString();
    final titleTokens =
        _tokens(_cleanTitle.isNotEmpty ? _cleanTitle : widget.title);
    final artistTokens = _tokens(_primaryArtist);
    final itemTitleTokens = _tokens(itemTitle);
    final itemArtistTokens = _tokens(itemArtist);
    final synced =
        (item['syncedLyrics'] as String?)?.isNotEmpty == true ? 1000 : 0;
    final plain =
        (item['plainLyrics'] as String?)?.isNotEmpty == true ? 100 : 0;
    final titleMatches = titleTokens.intersection(itemTitleTokens).length;
    final artistMatches = artistTokens.intersection(itemArtistTokens).length;
    final durationSeconds = widget.duration.inSeconds;
    final itemDuration = (item['duration'] as num?)?.toInt() ?? durationSeconds;
    final durationPenalty =
        durationSeconds > 0 ? (durationSeconds - itemDuration).abs() * 3 : 0;
    final albumBonus = widget.album.isNotEmpty &&
            _normalize(itemAlbum) == _normalize(widget.album)
        ? 80
        : 0;
    return synced +
        plain +
        titleMatches * 120 +
        artistMatches * 140 +
        albumBonus -
        durationPenalty;
  }

  bool _looksLikeRequestedSong(Map item) {
    final itemTitle = (item['trackName'] ?? item['name'] ?? '').toString();
    final itemArtist = (item['artistName'] ?? item['artist'] ?? '').toString();
    final titleTokens =
        _tokens(_cleanTitle.isNotEmpty ? _cleanTitle : widget.title);
    final artistTokens = _tokens(_primaryArtist);
    if (titleTokens.isNotEmpty &&
        titleTokens.intersection(_tokens(itemTitle)).isEmpty) {
      return false;
    }
    if (artistTokens.isNotEmpty &&
        itemArtist.isNotEmpty &&
        artistTokens.intersection(_tokens(itemArtist)).isEmpty) {
      return false;
    }
    final durationSeconds = widget.duration.inSeconds;
    final itemDuration = (item['duration'] as num?)?.toInt() ?? 0;
    if (durationSeconds > 0 &&
        itemDuration > 0 &&
        (durationSeconds - itemDuration).abs() > 8) {
      return false;
    }
    return true;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'\((official|audio|lyrics?|video|live).*?\)'), ' ')
        .replaceAll(RegExp(r'\[(official|audio|lyrics?|video|live).*?\]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _tokens(String value) =>
      _normalize(value).split(' ').where((token) => token.isNotEmpty).toSet();

  List<SyncedLine> _parseSyncedLyrics(String raw) {
    final regex = RegExp(r'^\[(\d+):(\d+)[.:](\d+)\]\s*(.*)$');
    final lines = <SyncedLine>[];

    for (final entry in raw.split('\n')) {
      final match = regex.firstMatch(entry.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final hundredths = int.parse(match.group(3)!);
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      lines.add(
        SyncedLine(
          timeMs: (minutes * 60000) + (seconds * 1000) + (hundredths * 10),
          text: text,
        ),
      );
    }

    return lines;
  }

  void _startTicker() {
    _timer?.cancel();
    if (_syncedLines.isEmpty) return;

    _updateActiveIndex();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateActiveIndex();
    });
  }

  void _updateActiveIndex() {
    if (_syncedLines.isEmpty) return;

    final posMs = _interpolatedPositionMs;
    int nextIndex = -1;
    for (int i = 0; i < _syncedLines.length; i++) {
      if (_syncedLines[i].timeMs <= posMs) {
        nextIndex = i;
      } else {
        break;
      }
    }

    if (nextIndex != _activeIndex && mounted) {
      setState(() => _activeIndex = nextIndex);
      if (nextIndex >= 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToActiveLine());
      }
    }
  }

  void _scrollToActiveLine() {
    final ctx = _activeKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _seekToLine(int index) {
    if (index < 0 || index >= _syncedLines.length) return;
    final timeMs = _syncedLines[index].timeMs;
    // Record seek so we ignore stale stream events for 1 second
    _seekedAt = DateTime.now();
    _lastReceivedPositionMs = timeMs;
    _lastPositionReceivedAt = DateTime.now();
    widget.onSeek?.call(Duration(milliseconds: timeMs));
    setState(() {
      _currentPositionMs = timeMs;
      _activeIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveLine());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D20), Color(0xFF1A0240)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : _lyricsLines.isEmpty
                  ? Center(
                      child: Text(
                        'Lyrics not found',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white60,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.42,
                      ),
                      itemCount: _lyricsLines.length,
                      itemBuilder: (context, index) {
                        final isActive = _syncedLines.isNotEmpty &&
                            index == _activeIndex &&
                            _activeIndex >= 0;
                        final canSeek =
                            _syncedLines.isNotEmpty && widget.onSeek != null;

                        return GestureDetector(
                          key: isActive ? _activeKey : null,
                          onTap: canSeek ? () => _seekToLine(index) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 5,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.28),
                                height: 1.7,
                              ),
                              child: Text(
                                _lyricsLines[index],
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
