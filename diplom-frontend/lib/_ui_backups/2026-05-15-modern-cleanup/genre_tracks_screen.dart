import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

const Map<String, String> _genreArtUrls = {
  'pop':
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1400&q=80',
  'rock':
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1400&q=80',
  'hip-hop':
      'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1400&q=80',
  'electronic':
      'https://images.unsplash.com/photo-1571330735066-03aaa9429d89?auto=format&fit=crop&w=1400&q=80',
  'jazz':
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?auto=format&fit=crop&w=1400&q=80',
  'k-pop':
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1400&q=80',
  'classical':
      'https://images.unsplash.com/photo-1507838153414-b4b713384a76?auto=format&fit=crop&w=1400&q=80',
  'r&b':
      'https://images.unsplash.com/photo-1501612780327-45045538702b?auto=format&fit=crop&w=1400&q=80',
  'latin':
      'https://images.unsplash.com/photo-1504609813442-a8924e83f76e?auto=format&fit=crop&w=1400&q=80',
  'country':
      'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1400&q=80',
  'folk':
      'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=1400&q=80',
  'funk':
      'https://images.unsplash.com/photo-1499364615650-ec38552f4f34?auto=format&fit=crop&w=1400&q=80',
  'soul':
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1400&q=80',
  'indie':
      'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?auto=format&fit=crop&w=1400&q=80',
  'punk':
      'https://images.unsplash.com/photo-1503095396549-807759245b35?auto=format&fit=crop&w=1400&q=80',
  'reggae':
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
};

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
  bool _shuffleMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ApiService();
      var tracks = await api.getCharts(
        genre: widget.genre.trim().toLowerCase(),
        limit: 100,
      );
      if (tracks.isEmpty) {
        tracks = await api.searchTracksWithFallback(
          '${widget.genre} music',
          limit: 30,
        );
      }

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

  void _playAll() {
    if (_tracks.isEmpty) return;

    final first = Map<String, dynamic>.from(_tracks[0] as Map)
      ..['queue'] = _tracks;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(track: first),
      ),
    );
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleMode = !_shuffleMode;
      if (_shuffleMode) {
        _tracks.shuffle();
      }
    });
  }

  void _showTrackOptions(BuildContext context, Map track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.favorite_border, color: Colors.white70),
            title: Text('Add to favorites',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.playlist_add_rounded, color: Colors.white70),
            title: Text('Add to playlist',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: Colors.white70),
            title:
                Text('Share', style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  String _fmt(dynamic ms) {
    final value = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final heroArt = _genreArtUrls[widget.genre.trim().toLowerCase()] ??
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1400&q=80';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 218,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: heroArt,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(gradient: widget.gradient),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.gradient.colors.first.withOpacity(0.24),
                          widget.gradient.colors.last.withOpacity(0.58),
                          AppColors.bg.withOpacity(0.94),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.genre,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          if (!_loading) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_tracks.length} tracks',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.72),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ACTION BAR
          if (!_loading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    // Shuffle
                    GestureDetector(
                      onTap: _toggleShuffle,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _shuffleMode
                              ? AppColors.purple.withOpacity(0.3)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _shuffleMode
                                ? AppColors.purpleLight
                                : AppColors.border,
                          ),
                        ),
                        child: Icon(
                          Icons.shuffle_rounded,
                          color: _shuffleMode
                              ? AppColors.purpleLight
                              : AppColors.text3,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Play All
                    Expanded(
                      child: GestureDetector(
                        onTap: _playAll,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryBtn,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 6),
                              Text('Play All',
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 3 dots
                    GestureDetector(
                      onTap: () => _showTrackOptions(context, {}),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.more_horiz_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // TRACK LIST
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final track = _tracks[i] as Map<String, dynamic>? ?? {};
                final trackMap = Map<String, dynamic>.from(track)
                  ..['queue'] = _tracks;

                final title = trackMap['title']?.toString() ?? '';
                final artist = trackMap['artist']?.toString() ?? '';
                final cover = trackMap['cover_url']?.toString() ?? '';
                final duration = _fmt(trackMap['duration_ms']);

                return GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: trackMap),
                    ),
                  ),
                  child: Container(
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
                              )
                            : Container(
                                width: 52,
                                height: 52,
                                color: AppColors.surface3,
                                child: const Icon(Icons.music_note,
                                    color: AppColors.text3, size: 24),
                              ),
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
                                  color: AppColors.text,
                                )),
                            Text(artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.text3,
                                )),
                          ],
                        ),
                      ),
                      if (duration.isNotEmpty)
                        Text(duration,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.text3)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showTrackOptions(context, trackMap),
                        child: const Icon(Icons.more_vert_rounded,
                            color: Colors.white38, size: 18),
                      ),
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
