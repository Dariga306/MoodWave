import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import 'artist_screen.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _filter = 0;
  final _filters = ['All', 'Playlists', 'Albums', 'Artists'];
  List<Map<String, dynamic>> _playlists = [];
  // Albums: unique albums derived from liked tracks
  List<Map<String, dynamic>> _albums = [];
  // Artists: followed artists with profiles
  List<Map<String, dynamic>> _artists = [];
  bool _loading = true;
  bool _albumsLoaded = false;
  bool _artistsLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await ApiService().getPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAlbums() async {
    if (_albumsLoaded) return;
    try {
      final liked = await ApiService().getLikedTracks(limit: 300);
      if (!mounted) return;
      // Group by album name, keep first-seen cover
      final seen = <String, Map<String, dynamic>>{};
      for (final t in liked.whereType<Map>()) {
        final albumName = t['album']?.toString() ?? '';
        if (albumName.isEmpty) continue;
        if (!seen.containsKey(albumName)) {
          seen[albumName] = {
            'album': albumName,
            'artist': t['artist']?.toString() ?? '',
            'cover_url': t['cover_url']?.toString(),
            'track_count': 1,
          };
        } else {
          seen[albumName]!['track_count'] =
              (seen[albumName]!['track_count'] as int) + 1;
        }
      }
      if (mounted) {
        setState(() {
          _albums = seen.values.toList();
          _albumsLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadArtists() async {
    if (_artistsLoaded) return;
    try {
      final raw = await ApiService().getFollowedArtistsDetails();
      if (!mounted) return;
      setState(() {
        _artists = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _artistsLoaded = true;
      });
    } catch (_) {}
  }

  void _onFilterChanged(int i) {
    setState(() => _filter = i);
    if (i == 2) _loadAlbums();
    if (i == 3) _loadArtists();
  }

  String _fmtFans(int fans) {
    if (fans >= 1000000) return '${(fans / 1000000).toStringAsFixed(1)}M';
    if (fans >= 1000) return '${(fans / 1000).toStringAsFixed(0)}K';
    return '$fans';
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    String visibility = 'private';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('New Playlist',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Playlist name',
                hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                filled: true,
                fillColor: AppColors.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('Visibility: ',
                  style:
                      GoogleFonts.outfit(color: AppColors.text2, fontSize: 13)),
              GestureDetector(
                onTap: () => setS(() => visibility =
                    visibility == 'private' ? 'public' : 'private'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: visibility == 'public'
                        ? AppColors.purple.withOpacity(0.2)
                        : AppColors.glass,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: visibility == 'public'
                            ? AppColors.purple
                            : AppColors.border),
                  ),
                  child: Text(
                    visibility == 'public' ? '🌍 Public' : '🔒 Private',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: visibility == 'public'
                            ? AppColors.purpleLight
                            : AppColors.text2),
                  ),
                ),
              ),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppColors.text3)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Create',
                  style: GoogleFonts.outfit(
                      color: AppColors.purpleLight,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      await ApiService()
          .createPlaylist(ctrl.text.trim(), visibility: visibility);
      if (mounted) showSuccessSnackBar(context, 'Playlist created!');
      await _load();
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not create playlist');
    }
  }

  Future<void> _deletePlaylist(Map<String, dynamic> playlist) async {
    final id = playlist['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Playlist?',
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: Text('This will permanently delete "${playlist['title']}".',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFef4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deletePlaylist(id);
      if (mounted) {
        showSuccessSnackBar(context, 'Playlist deleted');
        _load();
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not delete playlist');
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 1:
        return _playlists
            .where((p) => !(p['is_collaborative'] as bool? ?? false))
            .toList();
      case 2:
        return _albums;
      case 3:
        return _artists;
      default:
        return _playlists;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Library',
                            style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                                letterSpacing: -0.5)),
                        Row(children: [
                          GestureDetector(
                            onTap: _load,
                            child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: AppColors.glass,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.border)),
                                child: const Icon(Icons.refresh_rounded,
                                    size: 18, color: AppColors.text2)),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _createPlaylist,
                            child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 20)),
                          ),
                        ]),
                      ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _onFilterChanged(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient:
                                _filter == i ? AppColors.gradPurple : null,
                            color: _filter == i ? null : AppColors.glass,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: _filter == i
                                    ? AppColors.purple
                                    : AppColors.border),
                          ),
                          child: Text(_filters[i],
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _filter == i
                                      ? Colors.white
                                      : AppColors.text2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purpleLight))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.purpleLight,
                      backgroundColor: AppColors.surface,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Pinned: Liked Songs
                          SliverToBoxAdapter(child: _SepLabel('Pinned')),
                          SliverToBoxAdapter(
                            child: _LibItem(
                              emoji: '❤️',
                              gradient: const LinearGradient(colors: [
                                Color(0xFF6D28D9),
                                Color(0xFFDB2777)
                              ]),
                              name: 'Liked Songs',
                              meta: 'Your favourites',
                              badge: const _Badge('Saved', AppColors.pink),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LikedSongsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Section label
                          SliverToBoxAdapter(
                              child: _SepLabel(
                            _filter == 0
                                ? (_playlists.isEmpty
                                    ? 'No playlists yet'
                                    : 'My Playlists')
                                : _filter == 1
                                    ? (_playlists.isEmpty
                                        ? 'No playlists yet'
                                        : 'My Playlists')
                                    : _filter == 2
                                        ? 'Albums from Liked Songs'
                                        : 'Followed Artists',
                          )),

                          // Empty state
                          if (_filtered.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _filter == 2
                                            ? '💿'
                                            : _filter == 3
                                                ? '🎤'
                                                : '🎵',
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                          _filter == 2
                                              ? 'No saved albums yet'
                                              : _filter == 3
                                                  ? 'No followed artists yet'
                                                  : 'No playlists yet',
                                          style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              color: AppColors.text2)),
                                      const SizedBox(height: 6),
                                      Text(
                                          _filter == 2
                                              ? 'Like tracks to see their albums here'
                                              : _filter == 3
                                                  ? 'Follow artists to see them here'
                                                  : 'Tap + to create one',
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: AppColors.text3)),
                                    ]),
                              ),
                            ),

                          // Playlist items (filter 0 or 1)
                          if (_filter == 0 || _filter == 1)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final pl = _filtered[i];
                                  final trackCount =
                                      pl['track_count'] as int? ?? 0;
                                  final isCollab =
                                      pl['is_collaborative'] as bool? ?? false;
                                  final visibility =
                                      pl['visibility'] as String? ?? 'private';
                                  final coverUrl = pl['cover_url'] as String?;

                                  return Dismissible(
                                    key: ValueKey(pl['id']),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: const Color(0xFFef4444)
                                          .withOpacity(0.8),
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white),
                                    ),
                                    confirmDismiss: (_) async {
                                      await _deletePlaylist(pl);
                                      return false;
                                    },
                                    child: _LibItem(
                                      coverUrl: coverUrl,
                                      emoji: isCollab ? '🤝' : '🎵',
                                      gradient: AppColors.gradMixed,
                                      name:
                                          pl['title'] as String? ?? 'Playlist',
                                      meta: [
                                        'Playlist',
                                        '$trackCount songs',
                                        if (isCollab) 'Collab',
                                      ].join(' · '),
                                      badge: isCollab
                                          ? const _Badge(
                                              'Collab', AppColors.blue)
                                          : visibility == 'public'
                                              ? const _Badge(
                                                  'Public', AppColors.green)
                                              : null,
                                      onTap: () {
                                        final id = pl['id'] as int?;
                                        if (id != null) {
                                          Navigator.push(
                                              ctx,
                                              MaterialPageRoute(
                                                builder: (_) => PlaylistScreen(
                                                    playlistId: id),
                                              ));
                                        }
                                      },
                                    ),
                                  );
                                },
                                childCount: _filtered.length,
                              ),
                            ),

                          // Album items (filter 2)
                          if (_filter == 2)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final album = _albums[i];
                                  final albumName = album['album'] as String? ??
                                      'Unknown Album';
                                  final artist =
                                      album['artist'] as String? ?? '';
                                  final cover = album['cover_url'] as String?;
                                  final count =
                                      album['track_count'] as int? ?? 0;
                                  return _LibItem(
                                    coverUrl: cover,
                                    emoji: '💿',
                                    gradient: AppColors.gradBlue,
                                    name: albumName,
                                    meta:
                                        'Album · $artist · $count liked ${count == 1 ? 'track' : 'tracks'}',
                                    onTap: () {
                                      Navigator.push(
                                          ctx,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LikedSongsScreen(),
                                          ));
                                    },
                                  );
                                },
                                childCount: _albums.length,
                              ),
                            ),

                          // Artist items (filter 3)
                          if (_filter == 3)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final artist = _artists[i];
                                  final name =
                                      (artist['name'] ?? 'Unknown Artist')
                                          .toString();
                                  final picture =
                                      artist['picture_medium']?.toString() ??
                                          artist['picture']?.toString();
                                  final fans = artist['nb_fan'] as int?;
                                  final artistId = artist['id'];
                                  return _LibItem(
                                    coverUrl: picture,
                                    emoji: '🎤',
                                    gradient: AppColors.gradPink,
                                    name: name,
                                    meta: fans != null
                                        ? 'Artist · ${_fmtFans(fans)} fans'
                                        : 'Artist',
                                    onTap: () {
                                      if (artistId != null) {
                                        Navigator.push(
                                            ctx,
                                            MaterialPageRoute(
                                              builder: (_) => ArtistScreen(
                                                artistId: artistId.toString(),
                                                artistName: name,
                                              ),
                                            ));
                                      }
                                    },
                                  );
                                },
                                childCount: _artists.length,
                              ),
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SepLabel extends StatelessWidget {
  final String label;
  const _SepLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(label.toUpperCase(),
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
                letterSpacing: 0.1)),
      );
}

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

class _LibItem extends StatelessWidget {
  final String? coverUrl;
  final String emoji, name, meta;
  final LinearGradient gradient;
  final _Badge? badge;
  final VoidCallback? onTap;
  const _LibItem({
    this.coverUrl,
    required this.emoji,
    required this.gradient,
    required this.name,
    required this.meta,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: coverUrl != null && coverUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 22))),
                    ),
                  )
                : Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(meta,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text2),
                    overflow: TextOverflow.ellipsis),
              ])),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badge!.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: badge!.color.withOpacity(0.25)),
              ),
              child: Text(badge!.label,
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badge!.color)),
            ),
          ],
        ]),
      ),
    );
  }
}
