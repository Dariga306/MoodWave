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
  final List<String> lyricsLines;
  final Duration currentPosition;
  final List<int> syncedLineTimesMs;
  final void Function(Duration)? onSeek;
  final Stream<Duration>? positionStream;

  const LyricsScreen({
    super.key,
    required this.artist,
    required this.title,
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

  Timer? _timer;
  StreamSubscription<Duration>? _positionSub;
  List<String> _lyricsLines = [];
  List<SyncedLine> _syncedLines = [];
  bool _loading = true;
  int _activeIndex = -1;
  int _basePositionMs = 0;
  DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _basePositionMs = widget.currentPosition.inMilliseconds;
    _openedAt = DateTime.now();
    _seedInitialLyrics();
    // Keep lyrics in sync with actual playback position
    if (widget.positionStream != null) {
      _positionSub = widget.positionStream!.listen((pos) {
        _basePositionMs = pos.inMilliseconds;
        _openedAt = DateTime.now();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LyricsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      _basePositionMs = widget.currentPosition.inMilliseconds;
      _openedAt = DateTime.now();
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
      final title = Uri.encodeComponent(widget.title);
      final artist = Uri.encodeComponent(widget.artist);
      final response = await http
          .get(
            Uri.parse(
              'https://lrclib.net/api/search?track_name=$title&artist_name=$artist',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        for (final item in data) {
          final map = item as Map<String, dynamic>;
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
      final title = Uri.encodeComponent(widget.title);
      final artist = Uri.encodeComponent(widget.artist);
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

  List<SyncedLine> _parseSyncedLyrics(String raw) {
    final regex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2})\]\s*(.*)$');
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
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _updateActiveIndex();
    });
  }

  void _updateActiveIndex() {
    if (_syncedLines.isEmpty) return;

    final elapsed = DateTime.now().difference(_openedAt).inMilliseconds;
    final positionMs = _basePositionMs + elapsed;

    // Start at -1: nothing active until the first lyric time is reached
    int nextIndex = -1;
    for (int i = 0; i < _syncedLines.length; i++) {
      if (_syncedLines[i].timeMs <= positionMs) {
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
    if (!_scrollController.hasClients || _activeIndex < 0) return;
    final pos = _scrollController.position;
    final screenHeight = MediaQuery.of(context).size.height;
    // Top padding is 42% of full screen height (must match ListView padding)
    final topPadding = screenHeight * 0.42;
    // Each item: vertical padding 5+5=10px + font 17 * height 1.7 ≈ 29px text = ~39px
    // But actual render with Padding widget adds widget overhead, so use 58px measured
    const itemHeight = 58.0;
    // Use the actual viewport height (scroll area) for centering
    final viewH = pos.viewportDimension > 0 ? pos.viewportDimension : screenHeight;
    // Center the active line vertically in the viewport
    final targetOffset =
        topPadding + (_activeIndex * itemHeight) - (viewH / 2) + (itemHeight / 2);
    pos.animateTo(
      targetOffset.clamp(0.0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _seekToLine(int index) {
    if (index < 0 || index >= _syncedLines.length) return;
    final timeMs = _syncedLines[index].timeMs;
    widget.onSeek?.call(Duration(milliseconds: timeMs));
    setState(() {
      _basePositionMs = timeMs;
      _openedAt = DateTime.now();
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
