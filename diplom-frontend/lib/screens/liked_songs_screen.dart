import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});
  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _currentlyPlayingId;

  late final List<AnimationController> _eqControllers;

  @override
  void initState() {
    super.initState();
    _eqControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + i * 80),
      )..repeat(reverse: true),
    );
    _load();
  }

  @override
  void dispose() {
    for (final c in _eqControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await ApiService().getLikedTracks();
      if (!mounted) return;
      setState(() {
        _tracks = raw.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  void _playFrom(int index) {
    var queue = _tracks
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    if (context.read<PlayerProvider>().shuffleOn) {
      final rng = Random();
      for (int i = queue.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = queue[i];
        queue[i] = queue[j];
        queue[j] = tmp;
      }
      index = 0;
    }
    final track = Map<String, dynamic>.from(queue[index])..['queue'] = queue;
    final trackId = (track['spotify_id'] ?? track['deezer_id'] ?? '').toString();
    setState(() => _currentlyPlayingId = trackId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
  }

  Future<void> _unlikeTrack(String trackId) async {
    try {
      await ApiService().unlikeTrack(trackId);
      if (!mounted) return;
      setState(() {
        _tracks.removeWhere(
          (t) => (t['spotify_id'] ?? t['deezer_id'] ?? '').toString() == trackId,
        );
      });
    } catch (_) {}
  }

  void _showTrackMenu(BuildContext context, Map<String, dynamic> track, int index) {
    final title = track['title']?.toString() ?? 'Track';
    final artist = track['artist']?.toString() ?? '';
    final trackId = (track['spotify_id'] ?? track['deezer_id'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (artist.isNotEmpty)
                  Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            _menuItem(ctx, Icons.play_arrow_rounded, 'Play now', () {
              _playFrom(index);
            }),
            _menuItem(ctx, Icons.queue_music_rounded, 'Add to queue', () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Added to queue', style: GoogleFonts.outfit(color: Colors.white)),
                backgroundColor: AppColors.purpleDark,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            }),
            _menuItem(ctx, Icons.playlist_add_rounded, 'Add to playlist', () {
              showTrackMenu(context, track, onPlayNow: () => _playFrom(index));
            }),
            _menuItem(ctx, Icons.person_rounded, 'Go to artist', () {
              Navigator.pop(ctx);
            }),
            _menuItem(ctx, Icons.album_rounded, 'Go to album', () {
              Navigator.pop(ctx);
            }),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded,
                  color: Color(0xFFDB2777), size: 22),
              title: Text('Remove from Liked Songs',
                  style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFFDB2777))),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Remove from Liked Songs?',
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                    content: Text('Remove "$title" from your liked songs?',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Remove', style: GoogleFonts.outfit(
                            color: const Color(0xFFef4444), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ).then((ok) {
                  if (ok == true && trackId.isNotEmpty) _unlikeTrack(trackId);
                });
              },
            ),
            _menuItem(ctx, Icons.share_outlined, 'Share', () {
              Clipboard.setData(ClipboardData(text: '$title by $artist — MoodWave'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 2),
              ));
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  ListTile _menuItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70, size: 22),
      title: Text(label,
          style: GoogleFonts.outfit(fontSize: 15, color: color ?? Colors.white)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  Widget _eqBars() {
    return SizedBox(
      width: 20, height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) => AnimatedBuilder(
          animation: _eqControllers[i],
          builder: (_, __) => Container(
            width: 3,
            height: 6 + _eqControllers[i].value * 10,
            decoration: BoxDecoration(
              color: AppColors.purpleLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            // ── Spotify-style SliverAppBar ──────────────────────────
            SliverAppBar(
              expandedHeight: 240,
              backgroundColor: const Color(0xFF1a0533),
              pinned: true,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6D28D9), Color(0xFFDB2777)],
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(top: -50, right: -50,
                      child: Container(width: 220, height: 220,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06)))),
                    Positioned(bottom: -30, left: -30,
                      child: Container(width: 150, height: 150,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04)))),
                    SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  size: 44, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text('Liked Songs',
                                style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(
                              '${_tracks.length} ${_tracks.length == 1 ? 'song' : 'songs'}',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.65)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // ── Controls row ─────────────────────────────────────────
            if (!_loading && _tracks.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    // Shuffle toggle — uses PlayerProvider state
                    Consumer<PlayerProvider>(
                      builder: (_, provider, __) => GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          provider.toggleShuffle();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: provider.shuffleOn
                                ? AppColors.purpleLight.withOpacity(0.2)
                                : AppColors.glass,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: provider.shuffleOn
                                  ? AppColors.purpleLight
                                  : AppColors.border,
                              width: provider.shuffleOn ? 1.5 : 1,
                            ),
                          ),
                          child: Icon(Icons.shuffle_rounded,
                              size: 22,
                              color: provider.shuffleOn
                                  ? AppColors.purpleLight
                                  : AppColors.text3),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Play button
                    GestureDetector(
                      onTap: () => _playFrom(0),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF6D28D9), Color(0xFFDB2777)]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF6D28D9).withOpacity(0.4),
                                blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ]),
                ),
              ),

            // ── Track list ───────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.purpleLight)),
              )
            else if (_tracks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_rounded,
                        size: 64, color: Color(0xFFDB2777)),
                    const SizedBox(height: 12),
                    Text('No liked songs yet',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text('Tap the heart on any track to save it here',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.text3)),
                  ]),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final t = _tracks[i];
                    final cover = t['cover_url']?.toString();
                    final title = t['title']?.toString() ?? 'Unknown';
                    final artist = t['artist']?.toString() ?? '';
                    final dur = _fmt(t['duration_ms']);
                    final trackId =
                        (t['spotify_id'] ?? t['deezer_id'] ?? '').toString();
                    final isPlaying = trackId == _currentlyPlayingId;

                    return GestureDetector(
                      onTap: () => _playFrom(i),
                      child: Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Color(0x0AFFFFFF), width: 0.5)),
                        ),
                        child: Row(children: [
                          // Track number or equalizer bars
                          SizedBox(
                            width: 24,
                            child: isPlaying
                                ? _eqBars()
                                : Text('${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text3)),
                          ),
                          const SizedBox(width: 12),
                          // Album art
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: cover != null && cover.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: cover,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                          child: Icon(Icons.music_note_rounded,
                                              size: 20, color: Colors.white54)),
                                      errorWidget: (_, __, ___) => const Center(
                                          child: Icon(Icons.music_note_rounded,
                                              size: 20, color: Colors.white54)),
                                    ))
                                : const Center(
                                    child: Icon(Icons.music_note_rounded,
                                        size: 20, color: Colors.white54)),
                          ),
                          const SizedBox(width: 12),
                          // Title + artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isPlaying
                                            ? AppColors.purpleLight
                                            : AppColors.text)),
                                Text(artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text2)),
                              ],
                            ),
                          ),
                          // Duration
                          Text(dur,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3)),
                          const SizedBox(width: 4),
                          // Heart button
                          GestureDetector(
                            onTap: () => _unlikeTrack(trackId),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Icon(Icons.favorite_rounded,
                                  size: 18, color: Color(0xFFDB2777)),
                            ),
                          ),
                          // Three dots
                          GestureDetector(
                            onTap: () => _showTrackMenu(context, t, i),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.text3),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}
