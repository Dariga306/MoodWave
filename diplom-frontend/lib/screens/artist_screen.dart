import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'album_screen.dart';
import 'player_screen.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;
  final String artistName;

  const ArtistScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _followLoading = false;
  bool _isFollowing = false;
  String? _resolvedId; // numeric Deezer ID resolved from slug/name

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // If artistId is not a numeric Deezer ID, resolve it via name search first
      String resolvedId = widget.artistId;
      if (int.tryParse(resolvedId) == null) {
        final searchResult =
            await ApiService().searchArtist(widget.artistName);
        final found = searchResult['artist'] as Map<String, dynamic>?;
        if (found != null) {
          resolvedId = found['id'].toString();
        }
      }

      final results = await Future.wait([
        ApiService().getArtistProfile(resolvedId),
        ApiService().getFollowedArtists(),
      ]);
      if (!mounted) return;

      final followedIds =
          (results[1] as List).map((item) => item.toString()).toSet();

      setState(() {
        _resolvedId = resolvedId;
        _profile = Map<String, dynamic>.from(results[0] as Map);
        _isFollowing = followedIds.contains(resolvedId);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      final id = _resolvedId ?? widget.artistId;
      if (_isFollowing) {
        await ApiService().unfollowArtist(id);
      } else {
        await ApiService().followArtist(id);
      }
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update follow status')),
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  String _formatFans(dynamic fans) {
    final raw = fans is int ? fans : int.tryParse('$fans') ?? 0;
    final value = raw < 5000 ? raw + 50000 : raw;
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m >= 10 ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M fans';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '${k >= 100 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K fans';
    }
    return '$value fans';
  }

  String _formatDuration(dynamic durationMs) {
    final value =
        durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  String _albumYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return '';
    return releaseDate.split('-').first;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final headerHeight = media.height * 0.4;

    final artist = _profile?['artist'] as Map<String, dynamic>? ??
        {
          'name': widget.artistName,
          'nb_fan': 0,
        };
    final tracks = (_profile?['top_tracks'] as List?) ?? [];
    final albums = (_profile?['albums'] as List?) ?? [];
    final relatedArtists = (_profile?['related_artists'] as List?) ?? [];
    final imageUrl = artist['picture_xl']?.toString();

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
                  child: SizedBox(
                    height: headerHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF140B2A),
                              child: const Center(
                                child:
                                    Text('🎤', style: TextStyle(fontSize: 120)),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFF140B2A),
                            child: const Center(
                              child:
                                  Text('🎤', style: TextStyle(fontSize: 120)),
                            ),
                          ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x33000000),
                                Color(0x55000000),
                                Color(0xFF08080F),
                              ],
                              stops: [0, 0.45, 1],
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const BackButton(color: Colors.white),
                                    OutlinedButton(
                                      onPressed:
                                          _followLoading ? null : _toggleFollow,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? AppColors.purple
                                            : Colors.transparent,
                                        side: const BorderSide(
                                            color: Colors.white),
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text(
                                        _isFollowing ? 'Following' : 'Follow',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  artist['name']?.toString() ??
                                      widget.artistName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatFans(artist['nb_fan']),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white60,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Popular'),
                        const SizedBox(height: 8),
                        if (tracks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text(
                              'No tracks available right now.',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.text3,
                              ),
                            ),
                          )
                        else
                          ...tracks.asMap().entries.map((entry) {
                            final item = Map<String, dynamic>.from(
                                entry.value as Map)
                              ..['queue'] = tracks;
                            return _PopularTrackRow(
                              track: item,
                              duration: _formatDuration(item['duration_ms']),
                            );
                          }),
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Discography'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 188,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: albums.length,
                            itemBuilder: (_, index) {
                              final album = Map<String, dynamic>.from(
                                  albums[index] as Map);
                              final albumId = album['id'];
                              final parsedAlbumId = albumId != null
                                  ? int.tryParse(albumId.toString())
                                  : null;
                              return GestureDetector(
                                onTap: parsedAlbumId == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AlbumScreen(
                                              albumId: parsedAlbumId,
                                              initialTitle:
                                                  album['title']?.toString(),
                                              initialCover:
                                                  album['cover_xl']?.toString(),
                                            ),
                                          ),
                                        ),
                                child: _AlbumCard(
                                  title:
                                      album['title']?.toString() ?? 'Unknown',
                                  imageUrl: album['cover_xl']?.toString(),
                                  year: _albumYear(
                                      album['release_date']?.toString()),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Fans also like'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 136,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: relatedArtists.length,
                            itemBuilder: (_, index) {
                              final related = Map<String, dynamic>.from(
                                relatedArtists[index] as Map,
                              );
                              return _RelatedArtistCard(
                                artist: related,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArtistScreen(
                                        artistId: related['id'].toString(),
                                        artistName:
                                            related['name']?.toString() ??
                                                'Artist',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PopularTrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  final String duration;

  const _PopularTrackRow({
    required this.track,
    required this.duration,
  });

  void _showTrackMenu(BuildContext context, Map<String, dynamic> track) {
    final title = track['title']?.toString() ?? 'Unknown';
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            _menuItem(Icons.play_circle_outline_rounded, 'Play now', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(track: track)));
            }),
            _menuItem(Icons.playlist_add_rounded, 'Add to playlist', () {
              Navigator.pop(context);
            }),
            _menuItem(Icons.share_outlined, 'Share', () {
              Navigator.pop(context);
            }),
            _menuItem(Icons.album_rounded, 'View album', () {
              Navigator.pop(context);
              final albumId = track['album_id'];
              final parsed = albumId != null
                  ? int.tryParse(albumId.toString())
                  : null;
              if (parsed != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumScreen(
                      albumId: parsed,
                      initialTitle: track['album']?.toString(),
                    ),
                  ),
                );
              }
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(label,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.white)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rank = track['rank']?.toString() ?? '';
    final title = track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final coverUrl = track['cover_url']?.toString();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                rank,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                          child: Text('🎵'),
                        ),
                      ),
                    )
                  : const Center(child: Text('🎵')),
            ),
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
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
            Text(
              duration,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showTrackMenu(context, track),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded,
                    color: AppColors.text3, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String year;

  const _AlbumCard({
    required this.title,
    required this.imageUrl,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const Center(
                        child: Text('💿'),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('💿', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (year.isNotEmpty)
            Text(
              year,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
        ],
      ),
    );
  }
}

class _RelatedArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;
  final VoidCallback onTap;

  const _RelatedArtistCard({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = artist['picture_medium']?.toString() ??
        artist['picture_xl']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border2),
              ),
              child: imageUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                          child: Text('🎤'),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('🎤', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 10),
            Text(
              artist['name']?.toString() ?? 'Artist',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
