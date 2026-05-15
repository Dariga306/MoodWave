import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'mood_screen.dart' show MoodData;
import 'player_screen.dart';

class MoodTracksScreen extends StatefulWidget {
  final MoodData mood;

  const MoodTracksScreen({super.key, required this.mood});

  @override
  State<MoodTracksScreen> createState() => _MoodTracksScreenState();
}

class _MoodTracksScreenState extends State<MoodTracksScreen> {
  List<dynamic> _tracks = [];
  bool _loading = true;
  bool _shuffleOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await ApiService().getMoodTracks(widget.mood.key);
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

  void _playAll({int startIndex = 0}) {
    if (_tracks.isEmpty) return;
    final list = _shuffleOn ? (List.from(_tracks)..shuffle()) : _tracks;
    final track = Map<String, dynamic>.from(list[startIndex] as Map)
      ..['queue'] = list;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlayerScreen(track: track)));
  }

  void _toggleShuffle() {
    setState(() => _shuffleOn = !_shuffleOn);
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Красивый заголовок с обложкой ──────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.bg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _MoodHeader(
                mood: mood,
                trackCount: _tracks.length,
                loading: _loading,
              ),
            ),
          ),

          // ─── Кнопки действий ────────────────────────────────────────
          if (!_loading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    // Shuffle
                    GestureDetector(
                      onTap: _toggleShuffle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _shuffleOn
                              ? mood.glowColor.withOpacity(0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                _shuffleOn ? mood.glowColor : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.shuffle_rounded,
                          color: _shuffleOn ? mood.glowColor : AppColors.text3,
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
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                mood.gradient.colors.first,
                                mood.gradient.colors.last,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: mood.glowColor.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 6),
                              Text(
                                'Play All',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 3-dots
                    GestureDetector(
                      onTap: () => _showOptions(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.more_horiz_rounded,
                            color: AppColors.text3, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Список треков ───────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.purpleLight, strokeWidth: 2),
              ),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: mood.glowColor.withOpacity(0.7),
                      size: 52,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tracks found',
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try another mood',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final track = _tracks[i] as Map<String, dynamic>? ?? {};
                    final title = track['title']?.toString() ?? '';
                    final artist = track['artist']?.toString() ?? '';
                    final cover = track['cover_url']?.toString() ?? '';
                    final duration = _fmt(track['duration_ms']);

                    return GestureDetector(
                      onTap: () => _playAll(startIndex: i),
                      child: _TrackTile(
                        index: i + 1,
                        title: title,
                        artist: artist,
                        cover: cover,
                        duration: duration,
                        accentColor: mood.glowColor,
                        onMoreTap: () => _showTrackOptions(context, track),
                      ),
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(100)),
          ),
          const SizedBox(height: 16),
          _SheetOption(
              icon: Icons.add_rounded,
              label: 'Add all to playlist',
              onTap: () => Navigator.pop(context)),
          _SheetOption(
              icon: Icons.share_rounded,
              label: 'Share mood',
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Map track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(100)),
          ),
          const SizedBox(height: 12),
          // Track preview row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track['cover_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: track['cover_url'].toString(),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover)
                    : Container(
                        width: 44, height: 44, color: AppColors.surface3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track['title']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(track['artist']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ]),
          ),
          const Divider(color: Colors.white10, height: 1),
          _SheetOption(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () => Navigator.pop(context)),
          _SheetOption(
              icon: Icons.favorite_border_rounded,
              label: 'Add to liked',
              onTap: () => Navigator.pop(context)),
          _SheetOption(
              icon: Icons.share_rounded,
              label: 'Share track',
              onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ─── Заголовок с mood-артом ──────────────────────────────────────────────────

class _MoodHeader extends StatelessWidget {
  final MoodData mood;
  final int trackCount;
  final bool loading;

  const _MoodHeader({
    required this.mood,
    required this.trackCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: mood.artUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            decoration: BoxDecoration(gradient: mood.gradient),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                mood.gradient.colors.first.withOpacity(0.24),
                mood.gradient.colors.last.withOpacity(0.52),
                AppColors.bg.withOpacity(0.94),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -42,
          left: -20,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                mood.glowColor.withOpacity(0.3),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 38, 28, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  mood.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 38,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 18,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      mood.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    if (!loading && trackCount > 0) ...[
                      Text(
                        '·',
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                      Text(
                        '$trackCount tracks',
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Строка трека ─────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final int index;
  final String title;
  final String artist;
  final String cover;
  final String duration;
  final Color accentColor;
  final VoidCallback onMoreTap;

  const _TrackTile({
    required this.index,
    required this.title,
    required this.artist,
    required this.cover,
    required this.duration,
    required this.accentColor,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Номер
          SizedBox(
            width: 34,
            child: Text(
              '$index',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.text3,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),

          // Обложка
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 50, height: 50, color: AppColors.surface3),
                    errorWidget: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: AppColors.surface3,
                      child: const Icon(Icons.music_note,
                          color: AppColors.text3, size: 22),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: AppColors.surface3,
                    child: const Icon(Icons.music_note,
                        color: AppColors.text3, size: 22),
                  ),
          ),
          const SizedBox(width: 12),

          // Название и исполнитель
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.text3,
                  ),
                ),
              ],
            ),
          ),

          // Длительность
          if (duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              duration,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
          ],

          // 3 точки
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.text3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Пункт нижней шторки ─────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
      title: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}
