import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../utils/lyrics_matcher.dart';

class SyncedLine {
  final int timeMs;
  final String text;

  const SyncedLine({
    required this.timeMs,
    required this.text,
  });
}

List<SyncedLine> _buildApproximateSyncedLines(
  List<String> rawLines,
  Duration duration,
) {
  final lines = rawLines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  if (duration <= const Duration(seconds: 8)) {
    return lines.map((line) => SyncedLine(timeMs: 0, text: line)).toList();
  }

  final weights = lines
      .map((line) => line.replaceAll(RegExp(r'\s+'), '').length.clamp(8, 48))
      .toList();
  final totalWeight = weights.fold<int>(0, (sum, value) => sum + value);
  final introPaddingMs =
      (duration.inMilliseconds * 0.12).round().clamp(1200, 12000);
  final outroPaddingMs =
      (duration.inMilliseconds * 0.08).round().clamp(1200, 9000);
  final usableDurationMs =
      (duration.inMilliseconds - introPaddingMs - outroPaddingMs)
          .clamp(2000, duration.inMilliseconds);
  var cursor = 0;

  return List<SyncedLine>.generate(lines.length, (index) {
    final progress = totalWeight == 0 ? 0.0 : cursor / totalWeight;
    final timeMs = (introPaddingMs + usableDurationMs * progress)
        .round()
        .clamp(0, duration.inMilliseconds);
    cursor += weights[index];
    return SyncedLine(timeMs: timeMs, text: lines[index]);
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
  final bool approximateSync;
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
    this.approximateSync = false,
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

  List<String> get _artistVariants {
    final variants = widget.artist
        .split(RegExp(r'\s*(?:,| feat\. | ft\. | & )\s*', caseSensitive: false))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (_primaryArtist.isNotEmpty && !variants.contains(_primaryArtist)) {
      variants.insert(0, _primaryArtist);
    }
    return variants;
  }

  LyricsMatchContext get _lyricsMatchContext => LyricsMatchContext(
        titleVariants: buildTitleVariants(
          _cleanTitle.isNotEmpty ? _cleanTitle : widget.title,
        ),
        artistVariants: buildArtistVariants(
          widget.artist,
          primaryArtist: _primaryArtist,
          extraArtists: _artistVariants,
        ),
        albumName: widget.album,
        durationSeconds: widget.duration.inSeconds,
      );

  // Extrapolates current position using wall-clock time since last update.
  // Capped at 1500 ms to stay responsive while avoiding running far ahead.
  int get _interpolatedPositionMs {
    if (_syncedLines.isEmpty) return _currentPositionMs;
    final elapsed =
        DateTime.now().difference(_lastPositionReceivedAt).inMilliseconds;
    return _lastReceivedPositionMs + elapsed.clamp(0, 1500);
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
      if (widget.syncedLineTimesMs.length == widget.lyricsLines.length &&
          widget.syncedLineTimesMs.any((time) => time > 0)) {
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
      final queries = <Map<String, String>>[];
      final title = _cleanTitle.isNotEmpty ? _cleanTitle : widget.title;
      for (final artist in _artistVariants) {
        queries.add({
          'title': title,
          'artist': artist,
          if (widget.album.isNotEmpty) 'album': widget.album,
        });
      }
      if (queries.isEmpty) {
        queries.add({
          'title': title,
          'artist': _primaryArtist,
          if (widget.album.isNotEmpty) 'album': widget.album,
        });
      }

      final candidates = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final query in queries.take(6)) {
        final response = await http
            .get(
              Uri.parse(
                'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(query['title'] ?? '')}'
                '&artist_name=${Uri.encodeComponent(query['artist'] ?? '')}'
                '${query['album']?.isNotEmpty == true ? '&album_name=${Uri.encodeComponent(query['album']!)}' : ''}'
                '${widget.duration.inSeconds > 0 ? '&duration=${widget.duration.inSeconds}' : ''}',
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body) as List<dynamic>;
        for (final item in data.whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          final key =
              '${map['id'] ?? ''}|${map['trackName'] ?? ''}|${map['artistName'] ?? ''}';
          if (!seen.add(key)) continue;
          candidates.add(map);
        }
      }

      if (candidates.isEmpty) {
        final response = await http
            .get(
              Uri.parse(
                'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(title)}'
                '${widget.duration.inSeconds > 0 ? '&duration=${widget.duration.inSeconds}' : ''}',
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List<dynamic>;
          for (final item in data.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            final key =
                '${map['id'] ?? ''}|${map['trackName'] ?? ''}|${map['artistName'] ?? ''}';
            if (!seen.add(key)) continue;
            candidates.add(map);
          }
        }
      }

      candidates.sort((a, b) =>
          _lyricsMatchContext.score(b).compareTo(_lyricsMatchContext.score(a)));

      for (final map in candidates) {
        if (!_lyricsMatchContext.acceptsCandidate(map)) continue;
        final syncedLyrics = map['syncedLyrics'] as String?;
        if (syncedLyrics == null || syncedLyrics.isEmpty) continue;
        final lines = _parseSyncedLyrics(syncedLyrics);
        if (lines.isEmpty) continue;
        if (!mounted) return;
        setState(() {
          _syncedLines = lines;
          _lyricsLines = lines.map((line) => line.text).toList();
          _loading = false;
        });
        _startTicker();
        return;
      }

      for (final map in candidates) {
        if (!_lyricsMatchContext.acceptsCandidate(map)) continue;
        final plainLyrics = map['plainLyrics'] as String?;
        if (plainLyrics == null || plainLyrics.isEmpty) continue;
        final lines = plainLyrics
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;
        final approx = _buildApproximateSyncedLines(lines, widget.duration);
        if (!mounted) return;
        setState(() {
          _lyricsLines = lines;
          _syncedLines = approx.any((l) => l.timeMs > 0) ? approx : [];
          _activeIndex = _syncedLines.isNotEmpty ? 0 : -1;
          _loading = false;
        });
        _startTicker();
        return;
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
        final approx = _buildApproximateSyncedLines(lines, widget.duration);
        if (!mounted) return;
        setState(() {
          _lyricsLines = lines;
          _syncedLines = approx.any((line) => line.timeMs > 0) ? approx : [];
          _activeIndex = _syncedLines.isNotEmpty ? 0 : -1;
          _loading = false;
        });
        _startTicker();
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<SyncedLine> _parseSyncedLyrics(String raw) {
    final lines = <SyncedLine>[];

    for (final entry in raw.split('\n')) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final timeMatches =
          RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]').allMatches(trimmed).toList();
      if (timeMatches.isEmpty) continue;
      final text = trimmed
          .replaceAll(RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]'), '')
          .trim();
      if (text.isEmpty) continue;
      for (final match in timeMatches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final hundredths =
            int.parse((match.group(3) ?? '0').padRight(2, '0').substring(0, 2));
        lines.add(
          SyncedLine(
            timeMs: (minutes * 60000) + (seconds * 1000) + (hundredths * 10),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
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
    int nextIndex = posMs < _syncedLines.first.timeMs ? 0 : -1;
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Нет субтитров',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (widget.approximateSync)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Approximate timing — tap to seek unavailable',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              vertical:
                                  MediaQuery.of(context).size.height * 0.34,
                            ),
                            itemCount: _lyricsLines.length,
                            itemBuilder: (context, index) {
                              final isActive = _syncedLines.isNotEmpty &&
                                  index == _activeIndex &&
                                  _activeIndex >= 0;
                              // Seek is only meaningful for exact (non-approximate) sync
                              final canSeek = _syncedLines.isNotEmpty &&
                                  widget.onSeek != null &&
                                  !widget.approximateSync;

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
                                          : Colors.white.withOpacity(0.5),
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
                      ],
                    ),
        ),
      ),
      bottomNavigationBar: null,
    );
  }
}
