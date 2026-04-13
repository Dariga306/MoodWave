import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
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

  /// Track IDs the user has chosen to hide/ignore for this album session.
  final Set<String> _ignoredTrackIds = {};

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

  void _toggleIgnore(Map<String, dynamic> track) {
    final id = _trackId(track);
    if (id.isEmpty) return;
    setState(() {
      if (_ignoredTrackIds.contains(id)) {
        _ignoredTrackIds.remove(id);
      } else {
        _ignoredTrackIds.add(id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _ignoredTrackIds.contains(id)
              ? 'Track hidden — will be skipped'
              : 'Track restored',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1a1a2e),
      ),
    );
  }

  void _playAll(List<dynamic> tracks) {
    final active = tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .where((t) => !_ignoredTrackIds.contains(_trackId(t)))
        .toList();
    if (active.isEmpty) return;
    final first = Map<String, dynamic>.from(active.first)..['queue'] = active;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = (_album?['tracks'] as List?) ?? [];
    final coverUrl = _album?['cover_xl']?.toString() ?? widget.initialCover;
    final title =
        _album?['title']?.toString() ?? widget.initialTitle ?? 'Album';
    final artist = _album?['artist']?.toString() ?? '';
    final year = _year(_album?['release_date']?.toString());
    final nbTracks = _album?['nb_tracks'] ?? tracks.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.purpleLight,
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1e0846).withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.glass,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(Icons.arrow_back_rounded,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                                // Like album button
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _isLiked = !_isLiked);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _isLiked
                                              ? 'Album saved to your library'
                                              : 'Removed from library',
                                          style:
                                              GoogleFonts.outfit(fontSize: 13),
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor:
                                            const Color(0xFF1a1a2e),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.glass,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Icon(
                                      _isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 20,
                                      color: _isLiked
                                          ? AppColors.pink
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFF1a0533),
                                      Color(0xFF7c3aed)
                                    ]),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20)),
                                    ],
                                  ),
                                  child: coverUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const SizedBox(),
                                            errorWidget: (_, __, ___) =>
                                                const Center(
                                              child: Text('💿',
                                                  style: TextStyle(
                                                      fontSize: 58)),
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Text('💿',
                                              style:
                                                  TextStyle(fontSize: 58))),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Album${year.isNotEmpty ? ' · $year' : ''}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.purpleLight,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.text,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (artist.isNotEmpty)
                                        Text(
                                          artist,
                                          style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              color: AppColors.text2),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$nbTracks songs',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (tracks.isNotEmpty)
                              GestureDetector(
                                onTap: () => _playAll(tracks),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradPurple,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.purpleDark
                                              .withOpacity(0.35),
                                          blurRadius: 20)
                                    ],
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Play all',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        )),
                                    const Spacer(),
                                    if (_ignoredTrackIds.isNotEmpty)
                                      Text(
                                        '(${_ignoredTrackIds.length} hidden)',
                                        style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.white60),
                                      ),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = Map<String, dynamic>.from(
                          tracks[index] as Map)
                        ..['queue'] = tracks;
                      final id = _trackId(track);
                      final ignored = _ignoredTrackIds.contains(id);
                      final trackTitle =
                          track['title']?.toString() ?? 'Unknown';
                      final duration = _fmt(track['duration_ms']);
                      final rank = (index + 1).toString();

                      return Opacity(
                        opacity: ignored ? 0.35 : 1.0,
                        child: InkWell(
                          onTap: ignored
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PlayerScreen(track: track)),
                                  ),
                          onLongPress: () => _showTrackOptions(track, ignored),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                                color: ignored
                                    ? Colors.white.withOpacity(0.02)
                                    : Colors.transparent,
                                border: const Border(
                                    bottom: BorderSide(
                                        color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  rank,
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
                                    Text(
                                      trackTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: ignored
                                              ? Colors.white38
                                              : Colors.white,
                                          decoration: ignored
                                              ? TextDecoration.lineThrough
                                              : null),
                                    ),
                                    Text(
                                      artist,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.text3),
                                    ),
                                  ],
                                ),
                              ),
                              if (ignored)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.visibility_off_outlined,
                                      size: 14, color: AppColors.text3),
                                ),
                              Text(
                                duration,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    _showTrackOptions(track, ignored),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.more_vert_rounded,
                                      size: 18, color: AppColors.text3),
                                ),
                              ),
                            ]),
                          ),
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

  void _showTrackOptions(Map<String, dynamic> track, bool isIgnored) {
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                track['title']?.toString() ?? 'Track',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isIgnored
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_outlined,
                color: isIgnored ? AppColors.purpleLight : AppColors.text2,
                size: 22,
              ),
              title: Text(
                isIgnored ? 'Unhide track' : 'Hide track (skip in album)',
                style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleIgnore(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.text2, size: 22),
              title: Text('Play now',
                  style: GoogleFonts.outfit(fontSize: 15, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: track)),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
