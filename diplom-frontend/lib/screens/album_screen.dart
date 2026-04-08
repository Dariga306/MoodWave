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

  @override
  Widget build(BuildContext context) {
    final tracks = (_album?['tracks'] as List?) ?? [];
    final coverUrl = _album?['cover_xl']?.toString() ?? widget.initialCover;
    final title = _album?['title']?.toString() ?? widget.initialTitle ?? 'Album';
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
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.arrow_back_rounded,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [Color(0xFF1a0533), Color(0xFF7c3aed)]),
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
                                          borderRadius: BorderRadius.circular(22),
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const SizedBox(),
                                            errorWidget: (_, __, ___) => const Center(
                                              child: Text('💿',
                                                  style: TextStyle(fontSize: 58)),
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Text('💿',
                                              style: TextStyle(fontSize: 58))),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                              fontSize: 14, color: AppColors.text2),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$nbTracks songs',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12, color: AppColors.text3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (tracks.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  final first = Map<String, dynamic>.from(
                                      tracks.first as Map)
                                    ..['queue'] = tracks;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => PlayerScreen(track: first)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradPurple,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              AppColors.purpleDark.withOpacity(0.35),
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
                      final track =
                          Map<String, dynamic>.from(tracks[index] as Map)
                            ..['queue'] = tracks;
                      final trackTitle =
                          track['title']?.toString() ?? 'Unknown';
                      final duration = _fmt(track['duration_ms']);
                      final rank = (index + 1).toString();

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlayerScreen(track: track)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0x0AFFFFFF)))),
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
                                        color: Colors.white),
                                  ),
                                  Text(
                                    artist,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text3),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              duration,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3),
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
}
