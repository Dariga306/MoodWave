import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final int? playlistId;
  final String? playlistTitle;

  const PlaylistScreen({super.key, this.playlistId, this.playlistTitle});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Map<String, dynamic>? _playlist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.playlistId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await ApiService().getPlaylist(widget.playlistId!);
      if (!mounted) return;
      setState(() {
        _playlist = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  String _totalDuration(List tracks) {
    int total = 0;
    for (final t in tracks) {
      final ms = (t as Map)['duration_ms'];
      total += ms is int ? ms : int.tryParse('$ms') ?? 0;
    }
    if (total == 0) return '';
    final h = total ~/ 3600000;
    final m = (total % 3600000) ~/ 60000;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _playAll(List tracks) {
    if (tracks.isEmpty) return;
    final queue = tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = (_playlist?['tracks'] as List?) ?? [];
    final title = _playlist?['title']?.toString() ?? widget.playlistTitle ?? 'Playlist';
    final coverUrl = _playlist?['cover_url']?.toString();
    final isCollab = _playlist?['is_collaborative'] == true;
    final trackCount = _playlist?['track_count'] ?? tracks.length;
    final totalDur = _totalDuration(tracks);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC280A50), Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top nav
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.glass,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(Icons.arrow_back_rounded,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                                Text(title,
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text)),
                                Container(
                                  width: 40, height: 40,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(3, (_) => Container(
                                      width: 4, height: 4,
                                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                                      decoration: const BoxDecoration(
                                          color: AppColors.text2, shape: BoxShape.circle),
                                    )),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Cover + meta
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 130, height: 130,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20)),
                                    ],
                                  ),
                                  child: coverUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const SizedBox(),
                                            errorWidget: (_, __, ___) =>
                                                const Center(child: Text('🎵', style: TextStyle(fontSize: 52))),
                                          ))
                                      : const Center(child: Text('🎵', style: TextStyle(fontSize: 52))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('Playlist',
                                            style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.purpleLight,
                                                letterSpacing: 0.1)),
                                        if (isCollab) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.purple.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(100),
                                              border: Border.all(
                                                  color: AppColors.purple.withOpacity(0.25)),
                                            ),
                                            child: Row(children: [
                                              const Icon(Icons.people_alt_rounded,
                                                  size: 10, color: AppColors.purpleLight),
                                              const SizedBox(width: 4),
                                              Text('Collab',
                                                  style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.purpleLight)),
                                            ]),
                                          ),
                                        ],
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(title,
                                          style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.text,
                                              height: 1.2)),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          '$trackCount songs',
                                          if (totalDur.isNotEmpty) totalDur,
                                        ].join(' · '),
                                        style: GoogleFonts.outfit(
                                            fontSize: 13, color: AppColors.text2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Controls
                            Row(children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.shuffle_rounded,
                                    size: 22, color: AppColors.purpleLight),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: tracks.isEmpty ? null : () => _playAll(tracks),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: tracks.isEmpty ? null : AppColors.gradPurple,
                                      color: tracks.isEmpty ? AppColors.glass : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: tracks.isEmpty
                                          ? []
                                          : [
                                              BoxShadow(
                                                  color: AppColors.purpleDark.withOpacity(0.35),
                                                  blurRadius: 20)
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow_rounded,
                                            color: tracks.isEmpty
                                                ? AppColors.text3
                                                : Colors.white,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text('Play All',
                                            style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: tracks.isEmpty
                                                    ? AppColors.text3
                                                    : Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.more_horiz_rounded,
                                    size: 22, color: AppColors.text2),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🎵', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No tracks yet',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text)),
                        const SizedBox(height: 6),
                        Text('Add songs from search or player',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                      ]),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final track = Map<String, dynamic>.from(tracks[i] as Map)
                          ..['queue'] = tracks;
                        final trackTitle =
                            track['title']?.toString() ?? 'Unknown';
                        final artist = track['artist']?.toString() ?? '';
                        final coverUrl = track['cover_url']?.toString();
                        final duration = _fmt(track['duration_ms']);

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(track: track)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0x0AFFFFFF))),
                            ),
                            child: Row(children: [
                              SizedBox(
                                width: 20,
                                child: Text('${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text3)),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradMixed,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: coverUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const SizedBox(),
                                          errorWidget: (_, __, ___) => const Center(
                                              child: Text('🎵',
                                                  style: TextStyle(fontSize: 20))),
                                        ))
                                    : const Center(
                                        child:
                                            Text('🎵', style: TextStyle(fontSize: 20))),
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    if (artist.isNotEmpty)
                                      Text(artist,
                                          style: GoogleFonts.outfit(
                                              fontSize: 12, color: AppColors.text2)),
                                  ],
                                ),
                              ),
                              if (duration.isNotEmpty)
                                Text(duration,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text3)),
                              const SizedBox(width: 8),
                              const Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.text3),
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
