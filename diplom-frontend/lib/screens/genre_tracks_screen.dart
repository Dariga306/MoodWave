import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class GenreTracksScreen extends StatefulWidget {
  final String genre;
  final String emoji;
  final LinearGradient gradient;

  const GenreTracksScreen({
    super.key,
    required this.genre,
    required this.emoji,
    required this.gradient,
  });

  @override
  State<GenreTracksScreen> createState() => _GenreTracksScreenState();
}

class _GenreTracksScreenState extends State<GenreTracksScreen> {
  List<dynamic> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await ApiService().getCharts(genre: widget.genre, limit: 30);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic ms) {
    final value = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: widget.gradient),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20, left: -20,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.emoji,
                                style: const TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(widget.genre,
                                style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                            if (!_loading)
                              Text('${_tracks.length} tracks',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
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
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.purpleLight)),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎵', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text('No tracks found',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text('Try another genre',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text3)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final track = _tracks[i] as Map<String, dynamic>? ?? {};
                  final trackMap = Map<String, dynamic>.from(track as Map)
                    ..['queue'] = _tracks;
                  final title = trackMap['title']?.toString() ?? '';
                  final artist = trackMap['artist']?.toString() ?? '';
                  final cover = trackMap['cover_url']?.toString() ?? '';
                  final duration = _fmt(trackMap['duration_ms']);
                  final spotifyId = trackMap['spotify_id']?.toString() ??
                      trackMap['deezer_id']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(track: trackMap),
                      ),
                    ),
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cover.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cover,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surface3),
                                  errorWidget: (_, __, ___) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surface3,
                                      child: const Icon(Icons.music_note,
                                          color: AppColors.text3, size: 24)),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: AppColors.surface3,
                                  child: const Icon(Icons.music_note,
                                      color: AppColors.text3, size: 24)),
                        ),
                        const SizedBox(width: 14),
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
                                      fontSize: 12, color: AppColors.text3)),
                            ],
                          ),
                        ),
                        if (duration.isNotEmpty)
                          Text(duration,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3)),
                      ]),
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),
        ],
      ),
    );
  }
}
