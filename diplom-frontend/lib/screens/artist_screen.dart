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

      final profileResult = await ApiService().getArtistProfile(resolvedId);
      List followedList = [];
      try {
        followedList = await ApiService().getFollowedArtists();
      } catch (_) {}
      if (!mounted) return;

      final followedIds = followedList.map((item) => item.toString()).toSet();

      setState(() {
        _resolvedId = resolvedId;
        _profile = Map<String, dynamic>.from(profileResult);
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
    final value = fans is int ? fans : int.tryParse('$fans') ?? 0;
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
                          ...tracks.take(10).toList().asMap().entries.map((entry) {
                            final item = Map<String, dynamic>.from(
                                entry.value as Map)
                              ..['queue'] = tracks;
                            return _PopularTrackRow(
                              track: item,
                              duration: _formatDuration(item['duration_ms']),
                            );
                          }),
                        const SizedBox(height: 20),
                        // ─── Discography header with See All ──────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Discography',
                                  style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              if (albums.isNotEmpty)
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _DiscographyAllScreen(
                                        artistId: _resolvedId ?? widget.artistId,
                                        artistName: artist['name']?.toString() ?? widget.artistName,
                                      ),
                                    ),
                                  ),
                                  child: Text('See all',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppColors.purpleLight,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 195,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: albums.take(10).length,
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
                                  recordType: album['record_type']?.toString() ?? 'album',
                                ),
                              );
                            },
                          ),
                        ),
                        // ─── "This Is [Artist]" Spotify-style card ───────
                        if (tracks.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ThisIsScreen(
                                      artistName: artist['name']?.toString() ?? widget.artistName,
                                      artistImageUrl: imageUrl,
                                      artistId: _resolvedId ?? widget.artistId,
                                      tracks: tracks
                                          .whereType<Map>()
                                          .map((t) => Map<String, dynamic>.from(t))
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  height: 160,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // White base
                                      Container(color: Colors.white),
                                      // Artist photo on right
                                      if (imageUrl != null && imageUrl.isNotEmpty)
                                        Positioned(
                                          right: 0, top: 0, bottom: 0,
                                          width: 150,
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const SizedBox(),
                                            errorWidget: (_, __, ___) => const SizedBox(),
                                          ),
                                        ),
                                      // Gradient fade from left
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.white,
                                              Colors.white.withOpacity(0.85),
                                              Colors.white.withOpacity(0.0),
                                            ],
                                            stops: const [0.0, 0.45, 0.65, 1.0],
                                          ),
                                        ),
                                      ),
                                      // Text overlay
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'THIS IS',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black54,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  artist['name']?.toString() ??
                                                      widget.artistName,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF1DB954),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${tracks.length} songs',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ]),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    final artistId = track['artist_id']?.toString();
    final artistName = track['artist']?.toString() ?? '';
    final rawAlbumId = track['album_id'];
    final albumId = rawAlbumId != null ? int.tryParse(rawAlbumId.toString()) : null;

    showTrackMenu(
      context,
      track,
      onPlayNow: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      onGoToArtist: artistId != null && artistName.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistScreen(
                    artistId: artistId,
                    artistName: artistName,
                  ),
                ),
              )
          : null,
      onViewAlbum: albumId != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumScreen(
                    albumId: albumId,
                    initialTitle: track['album']?.toString(),
                    initialCover: track['cover_url']?.toString(),
                  ),
                ),
              )
          : null,
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
  final String recordType;

  const _AlbumCard({
    required this.title,
    required this.imageUrl,
    required this.year,
    this.recordType = 'album',
  });

  String get _typeLabel {
    switch (recordType) {
      case 'single': return 'Single';
      case 'ep': return 'EP';
      case 'live': return 'Live';
      case 'compilation': return 'Compilation';
      default: return 'Album';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
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
              if (recordType != 'album')
                Positioned(
                  bottom: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_typeLabel,
                        style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full Discography Screen
// ─────────────────────────────────────────────────────────────────────────────

class _DiscographyAllScreen extends StatefulWidget {
  final String artistId;
  final String artistName;

  const _DiscographyAllScreen({
    required this.artistId,
    required this.artistName,
  });

  @override
  State<_DiscographyAllScreen> createState() => _DiscographyAllScreenState();
}

class _DiscographyAllScreenState extends State<_DiscographyAllScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getArtistDiscography(widget.artistId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _albumYear(String? date) =>
      (date?.isNotEmpty == true) ? date!.split('-').first : '';

  Widget _buildGrid(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Nothing here yet',
              style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3)),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final album = Map<String, dynamic>.from(items[i] as Map);
        final albumId = album['id'];
        final parsedId = albumId != null ? int.tryParse(albumId.toString()) : null;
        final cover = album['cover_xl']?.toString();
        final title = album['title']?.toString() ?? 'Unknown';
        final year = _albumYear(album['release_date']?.toString());
        return GestureDetector(
          onTap: parsedId == null
              ? null
              : () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => AlbumScreen(
                        albumId: parsedId,
                        initialTitle: title,
                        initialCover: cover,
                      ),
                    ),
                  ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) =>
                              const Center(child: Text('💿')),
                        ),
                      )
                    : const Center(child: Text('💿', style: TextStyle(fontSize: 24))),
              ),
            ),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            if (year.isNotEmpty)
              Text(year,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.text3)),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final albums = (_data?['albums'] as List?) ?? [];
    final singles = (_data?['singles'] as List?) ?? [];
    final eps = (_data?['eps'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(widget.artistName,
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.purpleLight,
          unselectedLabelColor: AppColors.text3,
          indicatorColor: AppColors.purpleLight,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Albums (${albums.length})'),
            Tab(text: 'Singles (${singles.length})'),
            Tab(text: 'EPs (${eps.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.purpleLight))
          : TabBarView(
              controller: _tab,
              children: [
                _buildGrid(albums),
                _buildGrid(singles),
                _buildGrid(eps),
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

// ─── "This Is" full playlist screen ──────────────────────────────────────────

class _ThisIsScreen extends StatefulWidget {
  final String artistName;
  final String? artistImageUrl;
  final String? artistId;
  final List<Map<String, dynamic>> tracks;

  const _ThisIsScreen({
    required this.artistName,
    required this.artistImageUrl,
    this.artistId,
    required this.tracks,
  });

  @override
  State<_ThisIsScreen> createState() => _ThisIsScreenState();
}

class _ThisIsScreenState extends State<_ThisIsScreen> {
  bool _saved = false;
  bool _saving = false;

  String _formatDuration(dynamic durationMs) {
    int ms;
    if (durationMs is int) {
      ms = durationMs;
    } else if (durationMs is double) {
      ms = durationMs.round();
    } else {
      ms = int.tryParse('$durationMs') ?? 0;
    }
    if (ms <= 0) return '';
    if (ms <= 9999) ms *= 1000;
    return '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  Future<void> _saveToLibrary() async {
    if (_saving) return;
    final id = widget.artistId;
    if (id == null || id.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService().followArtist(id);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist saved to Library'), duration: Duration(seconds: 2)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save artist'), duration: Duration(seconds: 2)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.tracks;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Background: artist photo
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: widget.artistImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.artistImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFF140B2A)),
                          errorWidget: (_, __, ___) =>
                              Container(color: const Color(0xFF140B2A)),
                        )
                      : Container(color: const Color(0xFF140B2A)),
                ),
                // Dark overlay
                Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x44000000), Color(0xFF08080F)],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
                // Back button + text
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BackButton(color: Colors.white),
                        const SizedBox(height: 80),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'THIS IS',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white54,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.artistName,
                                style: GoogleFonts.outfit(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.tracks.length} songs',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Play All / Shuffle buttons ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (queue.isEmpty) return;
                      final first = Map<String, dynamic>.from(queue.first)
                        ..['queue'] = queue;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlayerScreen(track: first)),
                      );
                    },
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
                  const SizedBox(width: 10),
                  Text(
                    'Play all',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (queue.isEmpty) return;
                      final shuffled =
                          List<Map<String, dynamic>>.from(queue)..shuffle();
                      final first = Map<String, dynamic>.from(shuffled.first)
                        ..['queue'] = shuffled;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlayerScreen(track: first)),
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.shuffle_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Shuffle',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saveToLibrary,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purpleLight,
                            ),
                          )
                        : Icon(
                            _saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _saved
                                ? AppColors.pink
                                : AppColors.text2,
                            size: 28,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ── Track list ───────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final track = Map<String, dynamic>.from(queue[i])
                  ..['queue'] = queue;
                final title =
                    track['title'] ?? track['trackName'] ?? 'Unknown';
                final cover = track['cover_url'] ?? track['artworkUrl100'];
                final dur = _formatDuration(track['duration_ms']);
                final rawAlbumId = track['album_id'];
                final albumId = rawAlbumId != null
                    ? int.tryParse(rawAlbumId.toString())
                    : null;

                return InkWell(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => PlayerScreen(track: track)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(children: [
                      // Rank
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: cover != null
                            ? CachedNetworkImage(
                                imageUrl: cover.toString(),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const SizedBox(width: 44, height: 44),
                                errorWidget: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: AppColors.surface,
                                    child: const Icon(Icons.music_note,
                                        color: AppColors.text3)),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: AppColors.surface,
                                child: const Icon(Icons.music_note,
                                    color: AppColors.text3)),
                      ),
                      const SizedBox(width: 12),
                      // Title + artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                      // Duration
                      if (dur.isNotEmpty)
                        Text(dur,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.text3)),
                      // 3-dot menu
                      GestureDetector(
                        onTap: () => showTrackMenu(
                          ctx,
                          track,
                          onPlayNow: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(track: track)),
                          ),
                          onViewAlbum: albumId != null
                              ? () => Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => AlbumScreen(
                                        albumId: albumId,
                                        initialTitle:
                                            track['album']?.toString(),
                                        initialCover:
                                            track['cover_url']?.toString(),
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.more_vert_rounded,
                              color: AppColors.text3, size: 18),
                        ),
                      ),
                    ]),
                  ),
                );
              },
              childCount: queue.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
