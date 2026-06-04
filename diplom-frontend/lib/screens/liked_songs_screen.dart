import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'player_screen.dart';

enum _LikedSort { recent, oldest }

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen>
    with TickerProviderStateMixin {
  final _eqControllers = <AnimationController>[];
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  _LikedSort _sort = _LikedSort.recent;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _eqControllers.add(
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 320 + i * 80),
        )..repeat(reverse: true),
      );
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _eqControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await ApiService().getLikedTracks(limit: 150);
      if (!mounted) return;
      setState(() {
        _tracks = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _sortedTracks {
    final list =
        _tracks.map((track) => Map<String, dynamic>.from(track)).toList();
    list.sort((a, b) {
      final left = _likedAtMs(a);
      final right = _likedAtMs(b);
      return _sort == _LikedSort.recent
          ? right.compareTo(left)
          : left.compareTo(right);
    });
    return list;
  }

  int _likedAtMs(Map<String, dynamic> track) {
    final raw = track['liked_at'] ?? track['created_at'] ?? track['added_at'];
    if (raw is int) return raw;
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    return DateTime.tryParse(raw?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  String _trackId(Map<String, dynamic> track) {
    return (track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            '')
        .toString();
  }

  String _fmtDuration(dynamic value) {
    final raw = value is int ? value : int.tryParse('$value') ?? 0;
    if (raw <= 0) return '';
    final ms = raw < 10000 ? raw * 1000 : raw;
    final minutes = ms ~/ 60000;
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _durationFor(Map<String, dynamic> track) {
    return _fmtDuration(
      track['duration_ms'] ??
          track['track_duration_ms'] ??
          track['trackTimeMillis'] ??
          track['durationMillis'] ??
          track['duration'],
    );
  }

  void _playFrom(int index, {bool shuffle = false}) {
    var queue = _sortedTracks;
    if (shuffle || context.read<PlayerProvider>().shuffleOn) {
      queue = List<Map<String, dynamic>>.from(queue);
      final rng = Random();
      for (var i = queue.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = queue[i];
        queue[i] = queue[j];
        queue[j] = tmp;
      }
      index = 0;
    }
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    final track = Map<String, dynamic>.from(queue[index])
      ..['queue'] = queue
      ..['source'] = 'Liked Songs';
    setState(() => _currentlyPlayingId = _trackId(track));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
  }

  Future<void> _removeLike(Map<String, dynamic> track) async {
    final id = _trackId(track);
    if (id.isEmpty) return;
    try {
      await ApiService().unlikeTrack(id);
      if (!mounted) return;
      setState(() => _tracks.removeWhere((item) => _trackId(item) == id));
    } catch (_) {}
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            _sortItem(ctx, _LikedSort.recent, 'Recently added'),
            _sortItem(ctx, _LikedSort.oldest, 'Oldest first'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  ListTile _sortItem(BuildContext ctx, _LikedSort value, String label) {
    final selected = _sort == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? const Color(0xFFDB2777) : AppColors.text3,
      ),
      title: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        setState(() => _sort = value);
      },
    );
  }

  void _showTrackMenu(Map<String, dynamic> track, int index) {
    final title = (track['title'] ?? 'Track').toString();
    final artist = (track['artist'] ?? '').toString();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  _TrackCover(track: track, size: 48, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        if (artist.isNotEmpty)
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
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _menuItem(ctx, Icons.play_arrow_rounded, 'Play now',
                () => _playFrom(index)),
            _menuItem(ctx, Icons.favorite_border_rounded,
                'Remove from Liked Songs', () => _removeLike(track),
                color: const Color(0xFFF87171)),
            _menuItem(ctx, Icons.share_outlined, 'Share', () {
              Clipboard.setData(ClipboardData(text: '$title by $artist'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  ListTile _menuItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.text2),
      title: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.text,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  Widget _eqBars() {
    return SizedBox(
      width: 18,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _eqControllers[i],
            builder: (_, __) => Container(
              width: 3,
              height: 5 + _eqControllers[i].value * 10,
              decoration: BoxDecoration(
                color: const Color(0xFFDB2777),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _sortedTracks;
    final sortLabel =
        _sort == _LikedSort.recent ? 'Recently added' : 'Oldest first';

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFDB2777),
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 188,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0B0818),
              leading: _HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6F24D8),
                        Color(0xFF9F24C6),
                        Color(0xFFD73686),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -42,
                        top: -36,
                        child: Container(
                          width: 164,
                          height: 164,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -44,
                        bottom: -48,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF5415C8).withOpacity(0.20),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 39,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Liked Songs',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_tracks.length} ${_tracks.length == 1 ? 'song' : 'songs'}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_loading && tracks.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      _RoundControlButton(
                        icon: Icons.shuffle_rounded,
                        active: context.watch<PlayerProvider>().shuffleOn,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<PlayerProvider>().toggleShuffle();
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _playFrom(0),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      size: 21, color: Colors.white),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Play All',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoundControlButton(
                        icon: Icons.more_horiz_rounded,
                        onTap: _showSortSheet,
                      ),
                    ],
                  ),
                ),
              ),
            if (!_loading && tracks.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: GestureDetector(
                    onTap: _showSortSheet,
                    child: Row(
                      children: [
                        const Icon(Icons.sort_rounded,
                            size: 16, color: AppColors.text3),
                        const SizedBox(width: 6),
                        Text(
                          sortLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text2,
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: AppColors.text3),
                      ],
                    ),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFDB2777),
                  ),
                ),
              )
            else if (tracks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 58, color: Color(0xFFDB2777)),
                      const SizedBox(height: 12),
                      Text(
                        'No liked songs yet',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap the heart on any track to save it here',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.text3),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final track = tracks[i];
                    final title = (track['title'] ?? 'Unknown').toString();
                    final artist = (track['artist'] ?? '').toString();
                    final duration = _durationFor(track);
                    final isPlaying = _trackId(track) == _currentlyPlayingId;

                    return InkWell(
                      onTap: () => _playFrom(i),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 7, 14, 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: isPlaying
                                  ? _eqBars()
                                  : Text(
                                      '${i + 1}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.text3,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            _TrackCover(track: track),
                            const SizedBox(width: 12),
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
                                      fontWeight: FontWeight.w800,
                                      color: isPlaying
                                          ? const Color(0xFFDB2777)
                                          : AppColors.text,
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
                            if (duration.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 38,
                                child: Text(
                                  duration,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showTrackMenu(track, i),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.more_vert_rounded,
                                    size: 18, color: AppColors.text3),
                              ),
                            ),
                          ],
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
      ),
    );
  }
}

class _TrackCover extends StatelessWidget {
  final Map<String, dynamic> track;
  final double size;
  final double radius;

  const _TrackCover({
    required this.track,
    this.size = 48,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cover =
        (track['cover_url'] ?? track['track_cover_url'] ?? '').toString();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: cover.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: cover,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Icon(Icons.music_note_rounded,
                  size: 20, color: Colors.white38),
              errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded,
                  size: 20, color: Colors.white38),
            )
          : const Icon(Icons.music_note_rounded,
              size: 20, color: Colors.white38),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _RoundControlButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1E3A8A).withOpacity(0.45)
              : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? const Color(0xFFDB2777) : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 21,
          color: active ? const Color(0xFFDB2777) : AppColors.text2,
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
