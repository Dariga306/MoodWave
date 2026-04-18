import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});
  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
    final track = Map<String, dynamic>.from(_tracks[index])
      ..['queue'] = _tracks;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            backgroundColor: AppColors.bg,
            pinned: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 18, color: Colors.white),
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
                child: Stack(
                  children: [
                    // decorative circles
                    Positioned(
                      top: -40, right: -40,
                      child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20, left: -20,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('❤️',
                                style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text('Liked Songs',
                                style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                            Text(
                                '${_tracks.length} ${_tracks.length == 1 ? 'song' : 'songs'}',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Play All button ──────────────────────────────────────
          if (!_loading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _playFrom(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFFDB2777)]),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF6D28D9).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text('Play All',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.text2),
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
                  const Text('❤️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No liked songs yet',
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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

                  return GestureDetector(
                    onTap: () => _playFrom(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(children: [
                        // Cover
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: cover != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: cover,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 20))),
                                  ))
                              : const Center(
                                  child: Text('🎵',
                                      style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        // Title + artist
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text)),
                                Text(artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text2)),
                              ]),
                        ),
                        // Duration
                        if (dur.isNotEmpty)
                          Text(dur,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3)),
                        const SizedBox(width: 4),
                        const Icon(Icons.favorite_rounded,
                            size: 16, color: Color(0xFFDB2777)),
                      ]),
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
