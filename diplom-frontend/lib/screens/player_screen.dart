import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../services/api_service.dart';
import '../services/spotify_player_service.dart';
import '../theme/app_colors.dart';
import 'modals.dart';
import 'queue_screen.dart';

// ─── LRC / lyrics helpers ───────────────────────────────────────────────────

class _LrcLine {
  final Duration time;
  final String text;
  const _LrcLine({required this.time, required this.text});
}

List<_LrcLine> _parseLrc(String lrc) {
  final lines = <_LrcLine>[];
  final regex = RegExp(r'\[(\d+):(\d+)[.:](\d+)\]\s*(.*)');
  for (final raw in lrc.split('\n')) {
    final m = regex.firstMatch(raw.trim());
    if (m == null) continue;
    final mins = int.parse(m.group(1)!);
    final secs = int.parse(m.group(2)!);
    final csRaw = m.group(3)!.padRight(2, '0').substring(0, 2);
    final cs = int.parse(csRaw);
    final text = m.group(4)!.trim();
    lines.add(_LrcLine(
      time: Duration(minutes: mins, seconds: secs, milliseconds: cs * 10),
      text: text,
    ));
  }
  return lines;
}

// ─── PlayerScreen ────────────────────────────────────────────────────────────

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic>? track;
  const PlayerScreen({super.key, this.track});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  // ── animation ──────────────────────────────────────────────────────────────
  late final AnimationController _floatController;

  // ── spotify ─────────────────────────────────────────────────────────────────
  String? _spotifyToken;
  bool _spotifyLoading = true;
  bool _spotifyPlaying = false;
  int _spotifyPosition = 0; // ms
  int _spotifyDuration = 0; // ms
  Timer? _pollTimer;

  // ── just_audio fallback ─────────────────────────────────────────────────────
  final _player = AudioPlayer();
  bool _previewPlaying = false;
  bool _noPreview = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;

  // ── lyrics ──────────────────────────────────────────────────────────────────
  bool _showLyrics = false;
  bool _lyricsLoading = false;
  List<_LrcLine> _lrcLines = [];
  bool _lyricsSynced = false; // true when LRC timestamps available
  int _currentLyricIdx = -1;
  final _lyricsScroll = ScrollController();
  static const double _lineHeight = 52.0;

  // ── misc ────────────────────────────────────────────────────────────────────
  bool _isLiked = false;

  // ── derived ─────────────────────────────────────────────────────────────────
  bool get _usingSpotify =>
      _spotifyToken != null && SpotifyPlayerService.isReady;

  bool get _isPlaying =>
      _usingSpotify ? _spotifyPlaying : _previewPlaying;

  Duration get _position =>
      _usingSpotify ? Duration(milliseconds: _spotifyPosition) : _previewPosition;

  Duration get _duration =>
      _usingSpotify ? Duration(milliseconds: _spotifyDuration) : _previewDuration;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _initSpotify();
    _fetchLyrics();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pollTimer?.cancel();
    _player.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  // ── Spotify ──────────────────────────────────────────────────────────────────

  Future<void> _initSpotify() async {
    if (!kIsWeb) {
      setState(() => _spotifyLoading = false);
      _initPreview();
      return;
    }

    final token = await ApiService().getSpotifyToken();
    if (token == null) {
      setState(() => _spotifyLoading = false);
      _initPreview();
      return;
    }

    setState(() => _spotifyToken = token);
    await SpotifyPlayerService.init(token);

    if (!mounted) return;
    setState(() => _spotifyLoading = false);

    if (SpotifyPlayerService.isReady) {
      _startPolling();
      _playWithSpotify();
    } else {
      _initPreview();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final s = SpotifyPlayerService.getState();
      if (s != null) {
        final newPos = s['position'] as int? ?? 0;
        setState(() {
          _spotifyPlaying = !(s['paused'] as bool? ?? true);
          _spotifyPosition = newPos;
          _spotifyDuration = s['duration'] as int? ?? 0;
        });
        _updateLyricIdx(Duration(milliseconds: newPos));
      }
    });
  }

  Future<void> _playWithSpotify() async {
    final track = widget.track;
    if (track == null) return;

    bool ok = false;

    // Prefer direct URI playback when spotify_uri is available
    final spotifyUri = track['spotify_uri'] as String?;
    if (spotifyUri != null && spotifyUri.startsWith('spotify:track:')) {
      ok = await SpotifyPlayerService.playUri(spotifyUri, _spotifyToken!);
    }

    // Fall back to search by title+artist
    if (!ok) {
      final title = track['title'] ?? track['trackName'] ?? '';
      final artist = track['artist'] ?? track['artistName'] ?? '';
      final query = '$title $artist'.trim();
      if (query.isNotEmpty) {
        ok = await SpotifyPlayerService.playByQuery(query, _spotifyToken!);
      }
    }

    if (!ok && mounted) _initPreview();

    final trackId = track['spotify_id'] ?? track['trackId']?.toString();
    if (trackId != null) ApiService().playTrack(trackId).catchError((_) {});
  }

  // ── Preview fallback ─────────────────────────────────────────────────────────

  Future<void> _initPreview() async {
    String? url = (widget.track?['preview_url'] ?? widget.track?['previewUrl']) as String?;

    if (url == null) {
      final title = (widget.track?['title'] ?? widget.track?['trackName'] ?? '') as String;
      final artist = (widget.track?['artist'] ?? widget.track?['artistName'] ?? '') as String;
      if (title.isNotEmpty) {
        try {
          final q = Uri.encodeComponent('$title $artist');
          final resp = await http.get(Uri.parse(
              'https://itunes.apple.com/search?term=$q&media=music&limit=5'));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            final results = data['results'] as List<dynamic>?;
            if (results != null) {
              for (final item in results) {
                final c = item['previewUrl'] as String?;
                if (c != null && c.isNotEmpty) { url = c; break; }
              }
            }
          }
        } catch (_) {}
      }
      if (url == null) {
        if (mounted) setState(() => _noPreview = true);
        return;
      }
    }
    try {
      await _player.setUrl(url);
      if (!mounted) return;
      setState(() {
        _previewDuration = _player.duration ?? Duration.zero;
      });
      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _previewPosition = p);
        _updateLyricIdx(p);
      });
      _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _previewDuration = d);
      });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _previewPlaying = s.playing);
      });
      await _player.play();
    } catch (_) {}
  }

  // ── Lyrics ───────────────────────────────────────────────────────────────────

  Future<void> _fetchLyrics() async {
    final title = (widget.track?['title'] ?? widget.track?['trackName'] ?? '') as String;
    final artist = (widget.track?['artist'] ?? widget.track?['artistName'] ?? '') as String;
    if (title.isEmpty) return;
    if (mounted) setState(() => _lyricsLoading = true);

    // 1. Try lrclib.net for synced LRC lyrics
    try {
      final t = Uri.encodeComponent(title);
      final a = Uri.encodeComponent(artist);
      final resp = await http
          .get(Uri.parse('https://lrclib.net/api/get?track_name=$t&artist_name=$a'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        final plain = data['plainLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          final lines = _parseLrc(synced).where((l) => l.text.isNotEmpty).toList();
          if (lines.isNotEmpty) {
            if (mounted) setState(() { _lrcLines = lines; _lyricsSynced = true; _lyricsLoading = false; });
            return;
          }
        }
        if (plain != null && plain.isNotEmpty) {
          final lines = plain.split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((l) => _LrcLine(time: Duration.zero, text: l.trim()))
              .toList();
          if (mounted) setState(() { _lrcLines = lines; _lyricsSynced = false; _lyricsLoading = false; });
          return;
        }
      }
    } catch (_) {}

    // 2. Fallback: lyrics.ovh (plain text)
    if (artist.isNotEmpty) {
      try {
        final t = Uri.encodeComponent(title);
        final a = Uri.encodeComponent(artist);
        final resp = await http
            .get(Uri.parse('https://api.lyrics.ovh/v1/$a/$t'))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final raw = data['lyrics'] as String?;
          if (raw != null && raw.isNotEmpty) {
            final lines = raw.split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((l) => _LrcLine(time: Duration.zero, text: l.trim()))
                .toList();
            if (mounted) setState(() { _lrcLines = lines; _lyricsSynced = false; _lyricsLoading = false; });
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _lyricsLoading = false);
  }

  void _updateLyricIdx(Duration pos) {
    if (_lrcLines.isEmpty || !_lyricsSynced) return;
    int idx = -1;
    for (int i = 0; i < _lrcLines.length; i++) {
      if (_lrcLines[i].time <= pos) idx = i;
      else break;
    }
    if (idx != _currentLyricIdx) {
      setState(() => _currentLyricIdx = idx);
      _scrollToLyric(idx);
    }
  }

  void _scrollToLyric(int idx) {
    if (!_lyricsScroll.hasClients || idx < 0) return;
    final offset = (idx * _lineHeight - 160).clamp(0.0, double.infinity);
    final max = _lyricsScroll.position.maxScrollExtent;
    _lyricsScroll.animateTo(
      offset.clamp(0.0, max),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // ── Controls ─────────────────────────────────────────────────────────────────

  void _togglePlayPause() {
    if (_usingSpotify) {
      _spotifyPlaying ? SpotifyPlayerService.pause() : SpotifyPlayerService.resume();
    } else {
      _previewPlaying ? _player.pause() : _player.play();
    }
  }

  void _seek(double frac) {
    final total = _duration.inMilliseconds;
    if (total == 0) return;
    final target = (total * frac).round();
    if (_usingSpotify) {
      SpotifyPlayerService.seek(target);
    } else {
      _player.seek(Duration(milliseconds: target));
    }
  }

  Future<void> _connectSpotify() async {
    final url = await ApiService().getSpotifyAuthUrl();
    if (url != null) SpotifyPlayerService.openUrl(url);
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a0240), Color(0xFF0d0d20), Color(0xFF001230)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 60, left: -40,
                child: _orb(200, AppColors.purple.withOpacity(0.3))),
            Positioned(top: 120, right: -20,
                child: _orb(180, AppColors.pink.withOpacity(0.25))),
            Positioned(bottom: 100, left: 0, right: 0,
                child: Center(child: _orb(300, AppColors.blue.withOpacity(0.15)))),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _topBar(),
                      const SizedBox(height: 28),
                      _coverOrLyrics(),
                      const SizedBox(height: 24),
                      _titleRow(),
                      const SizedBox(height: 10),
                      _statusBadge(),
                      if (!_usingSpotify && !_spotifyLoading)
                        _spotifyConnectBanner(),
                      const SizedBox(height: 6),
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

  // ── sub-widgets ───────────────────────────────────────────────────────────────

  Widget _orb(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent])),
      );

  Widget _topBar() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
            ),
          ),
          Text('Now Playing',
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.text3, letterSpacing: 0.1)),
          const SizedBox(width: 40),
        ],
      );

  // Cover art or lyrics view (toggle on tap)
  Widget _coverOrLyrics() {
    return GestureDetector(
      onTap: () {
        setState(() => _showLyrics = !_showLyrics);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showLyrics ? _lyricsBox() : _coverArtBox(),
      ),
    );
  }

  Widget _coverArtBox() {
    final coverUrl = widget.track?['cover_url'] ?? widget.track?['artworkUrl100'];
    return AnimatedBuilder(
      key: const ValueKey('cover'),
      animation: _floatController,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, -8 * _floatController.value),
        child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            gradient: AppColors.gradMixed,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 60),
              BoxShadow(color: AppColors.pink.withOpacity(0.2), blurRadius: 120),
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 60, offset: const Offset(0, 30)),
            ],
          ),
          child: coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: CachedNetworkImage(
                      imageUrl: coverUrl, fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(child: Text('🌊', style: TextStyle(fontSize: 100))),
                      errorWidget: (_, __, ___) => const Center(child: Text('🎵', style: TextStyle(fontSize: 100)))))
              : const Center(child: Text('🌊', style: TextStyle(fontSize: 100))),
        ),
      ),
    );
  }

  Widget _lyricsBox() {
    return Container(
      key: const ValueKey('lyrics'),
      width: 280, height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a0240), Color(0xFF0a0a1e)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.purpleDark.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: AppColors.purpleDark.withOpacity(0.5), blurRadius: 40),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: _lyricsLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.purpleLight, strokeWidth: 2))
          : _lrcLines.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎵', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text('No lyrics found',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 4),
                    Text('tap to go back',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                  ],
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _lyricsScroll,
                      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 12),
                      itemCount: _lrcLines.length,
                      itemBuilder: (_, i) {
                        final isCurrent = _lyricsSynced && i == _currentLyricIdx;
                        final isNear = _lyricsSynced &&
                            (i == _currentLyricIdx - 1 || i == _currentLyricIdx + 1);
                        return AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: GoogleFonts.outfit(
                            fontSize: isCurrent ? 16 : (isNear ? 13 : 12),
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                            color: isCurrent
                                ? Colors.white
                                : isNear
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.22),
                            height: 1.5,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              _lrcLines[i].text,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    // Top & bottom fade
                    Positioned(top: 0, left: 0, right: 0,
                      child: Container(height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [const Color(0xFF1a0240), const Color(0x001a0240)])))),
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [const Color(0xFF0a0a1e), const Color(0x000a0a1e)])))),
                    // Tap hint
                    Positioned(bottom: 8, right: 12,
                      child: Text('tap to close',
                          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3))),
                  ],
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
                    widget.track?['title'] ?? widget.track?['trackName'] ?? 'Unknown',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.5)),
                Text(
                    widget.track?['artist'] ?? widget.track?['artistName'] ?? '',
                    style: GoogleFonts.outfit(
                        fontSize: 15, color: const Color(0xB3C8B4FF))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isLiked = !_isLiked),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: Icon(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isLiked ? AppColors.pink : AppColors.text2,
                  size: 22),
            ),
          ),
        ],
      );

  Widget _statusBadge() {
    if (_spotifyLoading) {
      return _badge(Icons.refresh, 'Connecting…', AppColors.purple);
    }
    if (_usingSpotify) {
      return _badge(Icons.music_note_rounded, 'Spotify Premium', const Color(0xFF1DB954));
    }
    if (_noPreview) {
      return _badge(Icons.music_off_rounded, 'Preview unavailable', AppColors.text3);
    }
    return _badge(Icons.headphones_rounded, '30-second preview', AppColors.text3);
  }

  Widget _badge(IconData icon, String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: color)),
          ],
        ),
      );

  // Spotify connect banner shown below status badge
  Widget _spotifyConnectBanner() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GestureDetector(
          onTap: _connectSpotify,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1a4a2a), Color(0xFF0f2e1a)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note_rounded, color: Color(0xFF1DB954), size: 16),
                const SizedBox(width: 8),
                Text('Connect Spotify Premium for full tracks',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: const Color(0xFF1DB954))),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1DB954), size: 14),
              ],
            ),
          ),
        ),
      );

  Widget _progressBar() {
    final frac = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        LayoutBuilder(builder: (ctx, box) {
          return GestureDetector(
            onTapDown: (d) {
              if (_duration.inMilliseconds == 0) return;
              _seek((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0));
            },
            onHorizontalDragUpdate: (d) {
              if (_duration.inMilliseconds == 0) return;
              _seek((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0));
            },
            child: Stack(
              children: [
                Container(
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.purple, AppColors.pink]),
                          borderRadius: BorderRadius.circular(100))),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_position),
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            Text(_fmt(_duration),
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
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
              onPressed: () {},
              icon: const Icon(Icons.shuffle_rounded,
                  size: 22, color: AppColors.purpleLight)),
          IconButton(
              onPressed: _usingSpotify ? SpotifyPlayerService.previousTrack : null,
              icon: Icon(Icons.skip_previous_rounded,
                  size: 32, color: _usingSpotify ? AppColors.text2 : AppColors.text3)),
          GestureDetector(
            onTap: _spotifyLoading ? null : _togglePlayPause,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  gradient: AppColors.primaryBtn,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.purpleDark.withOpacity(0.5), blurRadius: 30),
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                  ]),
              child: _spotifyLoading
                  ? const Center(
                      child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 34),
            ),
          ),
          IconButton(
              onPressed: _usingSpotify ? SpotifyPlayerService.nextTrack : null,
              icon: Icon(Icons.skip_next_rounded,
                  size: 32, color: _usingSpotify ? AppColors.text2 : AppColors.text3)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.repeat_rounded, size: 22, color: AppColors.text3)),
        ],
      );

  Widget _extraActions() => Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _showLyrics = !_showLyrics);
                if (_showLyrics && _lrcLines.isNotEmpty && _lyricsSynced) {
                  Future.delayed(const Duration(milliseconds: 350),
                      () => _scrollToLyric(_currentLyricIdx));
                }
              },
              child: _ExtraBtn(
                  icon: Icons.lyrics_outlined,
                  label: 'Lyrics',
                  active: _showLyrics || _lrcLines.isNotEmpty),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QueueScreen())),
              child: const _ExtraBtn(icon: Icons.queue_music_rounded, label: 'Queue'),
            ),
            GestureDetector(
              onTap: () => showShareTrack(context),
              child: const _ExtraBtn(icon: Icons.share_outlined, label: 'Share'),
            ),
            GestureDetector(
              onTap: () => showAddToPlaylist(context),
              child: const _ExtraBtn(icon: Icons.playlist_play_rounded, label: 'Playlist'),
            ),
          ],
        ),
      );
}

// ─── _ExtraBtn ────────────────────────────────────────────────────────────────

class _ExtraBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _ExtraBtn({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: active ? AppColors.purpleLight : AppColors.text3),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.purpleLight : AppColors.text3)),
      ],
    );
  }
}
