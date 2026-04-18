import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'artist_screen.dart';
import 'player_screen.dart';

class AlbumScreen extends StatefulWidget {
  final int albumId;
  final String? initialTitle;
  final String? initialCover;

  const AlbumScreen({
    super.key,
    required this.albumId,
    this.initialTitle,
    this.initialCover,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Map<String, dynamic>? _album;
  bool _loading = true;
  bool _isLiked = false;
  bool _downloadToggle = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getAlbumDetail(widget.albumId);
      if (!mounted) return;
      setState(() {
        _album = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic durationMs) {
    final ms = durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (ms <= 0) return '';
    return '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  String _year(String? date) =>
      (date?.isNotEmpty == true) ? date!.split('-').first : '';

  String _trackId(Map<String, dynamic> track) =>
      (track['spotify_id'] ?? track['deezer_id'] ?? track['track_id'] ?? '')
          .toString();

  void _playAll(List<dynamic> tracks) {
    final list = tracks.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
    if (list.isEmpty) return;
    final first = Map<String, dynamic>.from(list.first)..['queue'] = list;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
  }

  void _shufflePlay(List<dynamic> tracks) {
    final list = tracks.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
    if (list.isEmpty) return;
    list.shuffle(Random());
    final first = Map<String, dynamic>.from(list.first)..['queue'] = list;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
  }

  @override
  Widget build(BuildContext context) {
    final tracks = (_album?['tracks'] as List?) ?? [];
    final coverUrl = _album?['cover_xl']?.toString() ?? widget.initialCover;
    final title = _album?['title']?.toString() ?? widget.initialTitle ?? 'Album';
    final artist = _album?['artist']?.toString() ?? '';
    final artistId = _album?['artist_id'];
    final year = _year(_album?['release_date']?.toString());
    final nbTracks = tracks.isNotEmpty ? tracks.length : (_album?['nb_tracks'] ?? 0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight))
          : CustomScrollView(
              slivers: [
                // ── Spotify-style large cover header ──────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Cover + back button
                      Stack(
                        children: [
                          // Cover image
                          Container(
                            width: double.infinity,
                            height: 300,
                            color: const Color(0xFF1a0533),
                            child: coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: coverUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox(),
                                    errorWidget: (_, __, ___) => const Center(
                                        child: Text('💿', style: TextStyle(fontSize: 80))),
                                  )
                                : const Center(
                                    child: Text('💿', style: TextStyle(fontSize: 80))),
                          ),
                          // Gradient scrim
                          Container(
                            height: 300,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x55000000), Color(0xCC08080F)],
                              ),
                            ),
                          ),
                          // Back button
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ── Metadata ─────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.text,
                                    height: 1.1)),
                            const SizedBox(height: 6),
                            Row(children: [
                              if (artist.isNotEmpty)
                                GestureDetector(
                                  onTap: artistId == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ArtistScreen(
                                                artistId: artistId.toString(),
                                                artistName: artist,
                                              ),
                                            ),
                                          ),
                                  child: Text(artist,
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.purpleLight)),
                                ),
                              if (year.isNotEmpty) ...[
                                Text('  ·  ',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, color: AppColors.text3)),
                                Text(year,
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, color: AppColors.text3)),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Text('$nbTracks songs',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                            const SizedBox(height: 16),
                            // ── Action buttons row ──────────────────────────
                            Row(children: [
                              // Heart
                              GestureDetector(
                                onTap: () => setState(() => _isLiked = !_isLiked),
                                child: Icon(
                                  _isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _isLiked ? AppColors.pink : AppColors.text3,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Download toggle
                              GestureDetector(
                                onTap: () => setState(() => _downloadToggle = !_downloadToggle),
                                child: Icon(
                                  _downloadToggle
                                      ? Icons.download_done_rounded
                                      : Icons.download_outlined,
                                  color: _downloadToggle
                                      ? AppColors.purpleLight
                                      : AppColors.text3,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Three dots
                              GestureDetector(
                                onTap: () => _showAlbumMenu(tracks, artist, artistId),
                                child: const Icon(Icons.more_vert_rounded,
                                    color: AppColors.text3, size: 26),
                              ),
                              const Spacer(),
                              // Shuffle
                              if (tracks.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _shufflePlay(tracks),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(Icons.shuffle_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              // Play
                              if (tracks.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _playAll(tracks),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1DB954),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white, size: 30),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      if (tracks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 40),
                          child: Center(
                            child: Column(children: [
                              const Text('💿', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 16),
                              Text('No tracks available',
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              const SizedBox(height: 8),
                              Text('This album has no playable tracks yet.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13, color: AppColors.text3)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Track list ────────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = Map<String, dynamic>.from(tracks[index] as Map)
                        ..['queue'] = tracks;
                      final trackTitle = track['title']?.toString() ?? 'Unknown';
                      final duration = _fmt(track['duration_ms']);

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
                        ),
                        onLongPress: () => _showTrackOptions(track, artist, artistId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Color(0x0AFFFFFF))),
                          ),
                          child: Row(children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trackTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  Text(artist,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12, color: AppColors.text3)),
                                ],
                              ),
                            ),
                            Text(duration,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _showTrackOptions(track, artist, artistId),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.more_vert_rounded,
                                    size: 18, color: AppColors.text3),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }

  void _showAlbumMenu(List<dynamic> tracks, String artist, dynamic artistId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(height: 16),
            _MenuItem(
              icon: Icons.play_circle_outline_rounded,
              label: 'Play all',
              onTap: () { Navigator.pop(context); _playAll(tracks); },
            ),
            _MenuItem(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle play',
              onTap: () { Navigator.pop(context); _shufflePlay(tracks); },
            ),
            if (artist.isNotEmpty && artistId != null)
              _MenuItem(
                icon: Icons.person_rounded,
                label: 'Go to artist',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistScreen(
                        artistId: artistId.toString(),
                        artistName: artist,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(Map<String, dynamic> track, String albumArtist, dynamic artistId) {
    showTrackMenu(
      context,
      track,
      onPlayNow: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
      ),
      onGoToArtist: artistId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistScreen(
                    artistId: artistId.toString(),
                    artistName: albumArtist,
                  ),
                ),
              ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.text2, size: 22),
      title: Text(label,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.white)),
      onTap: onTap,
    );
  }
}
