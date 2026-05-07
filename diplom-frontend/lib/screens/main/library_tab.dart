import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/media_url.dart';
import '../album_screen.dart';
import '../artist_screen.dart';
import '../create_playlist_screen.dart';
import '../liked_songs_screen.dart';
import '../playlist_screen.dart';
import '../profile_tab_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _filter = 0; // 0=All, 1=Playlists, 2=Albums, 3=Artists
  int _playlistSubFilter = 0; // 0=All, 1=My, 2=Platform
  bool _isGridMode = false;
  int _sortOption = 0; // 0=Recent, 1=Date added, 2=Alphabetical, 3=By author

  final _filters = ['All', 'Playlists', 'Albums', 'Artists'];

  List<dynamic> _playlists = [];
  List<Map<String, dynamic>> _albums = [];
  List<Map<String, dynamic>> _artists = [];
  bool _loading = true;
  bool _albumsLoaded = false;
  bool _albumsLoading = false;
  bool _artistsLoaded = false;
  bool _artistsLoading = false;
  int _lastProfileRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _albumsLoaded = false;
      _artistsLoaded = false;
    });
    try {
      final data = await ApiService().getPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
    if (_filter == 0 || _filter == 2 || force) {
      await _loadAlbums(force: true);
    }
    if (_filter == 0 || _filter == 3 || force) {
      await _loadArtists(force: true);
    }
  }

  Future<void> _loadAlbums({bool force = false}) async {
    if (_albumsLoaded && !force) return;
    setState(() => _albumsLoading = true);
    try {
      final raw = await ApiService().getLikedAlbums();
      if (!mounted) return;
      final albums = raw
          .map((item) => {
                'id': item['id'],
                'title': item['album_name']?.toString() ?? 'Unknown Album',
                'artist': item['artist_name']?.toString() ?? '',
                'cover_xl': item['cover_url']?.toString(),
                'liked_count': 0,
              })
          .toList();
      setState(() {
        _albums = albums;
        _albumsLoaded = true;
        _albumsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _albumsLoaded = true;
          _albumsLoading = false;
        });
      }
    }
  }

  Future<void> _loadArtists({bool force = false}) async {
    if (_artistsLoaded && !force) return;
    setState(() => _artistsLoading = true);
    try {
      final raw = await ApiService().getFollowedArtistsDetails();
      if (!mounted) return;
      setState(() {
        _artists = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _artistsLoaded = true;
        _artistsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _artistsLoaded = true;
          _artistsLoading = false;
        });
      }
    }
  }

  Future<void> _openSavedAlbum(
    BuildContext context,
    Map<String, dynamic> album,
  ) async {
    final rawId = album['id']?.toString();
    if (rawId == null || rawId.isEmpty) return;

    if (rawId.startsWith('this_is:')) {
      final artistId = rawId.substring('this_is:'.length);
      final artistName = (album['artist'] ?? 'Artist').toString();
      final artistImageUrl = album['cover_xl']?.toString();

      try {
        final profile = await ApiService().getArtistProfile(artistId);
        if (!context.mounted) return;
        final tracks = ((profile['top_tracks'] as List?) ?? [])
            .whereType<Map>()
            .map((t) => Map<String, dynamic>.from(t))
            .toList();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThisIsScreen(
              artistName: artistName,
              artistImageUrl: artistImageUrl,
              artistId: artistId,
              tracks: tracks,
            ),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistScreen(
              artistId: artistId,
              artistName: artistName,
            ),
          ),
        );
      }
      return;
    }

    final id = int.tryParse(rawId);
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumScreen(albumId: id)),
    );
  }

  void _onFilterChanged(int i) {
    setState(() {
      _filter = i;
      _playlistSubFilter = 0;
    });
    if (i == 2) _loadAlbums(force: true);
    if (i == 3) _loadArtists(force: true);
  }

  List<dynamic> get _filteredPlaylists {
    List<dynamic> list = _playlists;
    if (_filter == 1) {
      if (_playlistSubFilter == 1) {
        list = list.where((p) {
          final vis = (p as Map)['visibility'] ?? '';
          return vis != 'saved';
        }).toList();
      } else if (_playlistSubFilter == 2) {
        list = list.where((p) {
          final vis = (p as Map)['visibility'] ?? '';
          return vis == 'saved';
        }).toList();
      }
    }
    switch (_sortOption) {
      case 2: // Alphabetical
        list = List.from(list)
          ..sort((a, b) => (a as Map)['title']
              .toString()
              .toLowerCase()
              .compareTo((b as Map)['title'].toString().toLowerCase()));
        break;
      case 3: // By author / visibility fallback
        list = List.from(list)
          ..sort((a, b) {
            final aa = ((a as Map)['description'] ??
                    a['visibility'] ??
                    a['title'] ??
                    '')
                .toString()
                .toLowerCase();
            final bb = ((b as Map)['description'] ??
                    b['visibility'] ??
                    b['title'] ??
                    '')
                .toString()
                .toLowerCase();
            return aa.compareTo(bb);
          });
        break;
      case 1: // Date added
        list = List.from(list)
          ..sort((a, b) =>
              _sortDateForMap(b as Map).compareTo(_sortDateForMap(a as Map)));
        break;
      case 0: // Recent (keep backend order)
      default:
        break;
    }
    return list;
  }

  DateTime _sortDateForMap(Map item) {
    for (final key in [
      'updated_at', 'created_at', 'liked_at', 'saved_at', 'followed_at'
    ]) {
      final raw = item[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    // Items with no date (e.g. artists) surface at the top alongside recent items
    return DateTime.now();
  }

  List<Map<String, dynamic>> get _allLibraryItems {
    final items = <Map<String, dynamic>>[];

    for (final raw in _filteredPlaylists) {
      if (raw is! Map) continue;
      final playlist = Map<String, dynamic>.from(raw);
      items.add({
        'type': 'playlist',
        'data': playlist,
        'title': (playlist['title'] ?? 'Untitled').toString(),
        'author': (playlist['description'] ?? playlist['visibility'] ?? '')
            .toString(),
        'sort_date': _sortDateForMap(playlist),
      });
    }

    for (final album in _albums) {
      items.add({
        'type': 'album',
        'data': album,
        'title': (album['title'] ?? 'Unknown Album').toString(),
        'author': (album['artist'] ?? '').toString(),
        'sort_date': _sortDateForMap(album),
      });
    }

    for (final artist in _artists) {
      items.add({
        'type': 'artist',
        'data': artist,
        'title': (artist['name'] ?? 'Unknown Artist').toString(),
        'author': (artist['artist'] ?? artist['name'] ?? '').toString(),
        'sort_date': _sortDateForMap(artist),
      });
    }

    switch (_sortOption) {
      case 2:
        items.sort((a, b) => (a['title'] as String)
            .toLowerCase()
            .compareTo((b['title'] as String).toLowerCase()));
        break;
      case 3:
        items.sort((a, b) => (a['author'] as String)
            .toLowerCase()
            .compareTo((b['author'] as String).toLowerCase()));
        break;
      // case 0 (Recent) and case 1 (Date added) both sort by date to mix types
      default:
        items.sort((a, b) =>
            (b['sort_date'] as DateTime).compareTo(a['sort_date'] as DateTime));
        break;
    }

    return items;
  }

  List<Widget> _buildAllLibrarySlivers() {
    final slivers = <Widget>[];
    final mixed = _allLibraryItems;

    if (mixed.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎵', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 14),
              Text('Your library is empty',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 6),
              Text('Create your first playlist',
                  style:
                      GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _openCreatePlaylist,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                      gradient: AppColors.primaryBtn,
                      borderRadius: BorderRadius.circular(14)),
                  child: Text('Create Playlist',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final item = mixed[i];
              final type = item['type']?.toString();
              final data = Map<String, dynamic>.from(item['data'] as Map);
              switch (type) {
                case 'album':
                  return _AlbumLibraryItem(
                    album: data,
                    onTap: () => _openSavedAlbum(context, data),
                  );
                case 'artist':
                  return _ArtistLibraryItem(artist: data);
                case 'playlist':
                default:
                  return _PlaylistItem(
                    playlist: data,
                    onRefresh: _load,
                  );
              }
            },
            childCount: mixed.length,
          ),
        ),
      );
    }

    return slivers;
  }

  void _showSortSheet() {
    const options = [
      'Recent',
      'Date added',
      'Alphabetical',
      'By author',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text('Sort',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                  options.length,
                  (i) => ListTile(
                        leading: Icon(
                          _sortOption == i
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: _sortOption == i
                              ? AppColors.purpleLight
                              : AppColors.text3,
                        ),
                        title: Text(options[i],
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: _sortOption == i
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _sortOption == i
                                    ? AppColors.purpleLight
                                    : AppColors.text)),
                        onTap: () {
                          setState(() => _sortOption = i);
                          Navigator.pop(ctx);
                        },
                      )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreatePlaylist() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePlaylistScreen()),
    );
    if (created == true) _load();
  }

  void _handleProfileRevision(int revision) {
    if (revision == _lastProfileRevision) return;
    _lastProfileRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileRevision =
        context.select<AuthProvider, int>((auth) => auth.profileRevision);
    _handleProfileRevision(profileRevision);
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final avatarUrl = buildMediaUrl(
      user?['avatar_url'] as String?,
      version: user?['updated_at'],
    );
    final avatarPreset = user?['avatar_preset'] as int? ?? 0;
    const avatarGradients = [
      [Color(0xFF7c3aed), Color(0xFFec4899)],
      [Color(0xFF06b6d4), Color(0xFF3b82f6)],
      [Color(0xFF22c55e), Color(0xFF14b8a6)],
      [Color(0xFFf97316), Color(0xFFec4899)],
      [Color(0xFF6366f1), Color(0xFFa855f7)],
      [Color(0xFFf59e0b), Color(0xFF22c55e)],
      [Color(0xFFef4444), Color(0xFFf97316)],
      [Color(0xFF0ea5e9), Color(0xFF8b5cf6)],
      [Color(0xFF84cc16), Color(0xFF06b6d4)],
      [Color(0xFFec4899), Color(0xFF8b5cf6)],
      [Color(0xFF64748b), Color(0xFF0f172a)],
      [Color(0xFFfde047), Color(0xFFf97316)],
    ];
    final avatarColors =
        avatarGradients[avatarPreset.clamp(0, avatarGradients.length - 1)];
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(children: [
                    // Header row
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileTabScreen())),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: avatarColors,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.4),
                                width: 1.5),
                          ),
                          child: avatarUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                          child: Text(initial,
                                              style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white)))))
                              : Center(
                                  child: Text(initial,
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Your Library',
                          style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.3)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openCreatePlaylist,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradPurple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded,
                              size: 20, color: Colors.white),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Filter chips
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
                                horizontal: 14, vertical: 7),
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
                    const SizedBox(height: 10),
                    // Sub-filters for Playlists
                    if (_filter == 1) ...[
                      SizedBox(
                        height: 30,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _SubFilter(
                                label: 'All',
                                active: _playlistSubFilter == 0,
                                onTap: () =>
                                    setState(() => _playlistSubFilter = 0)),
                            const SizedBox(width: 8),
                            _SubFilter(
                                label: 'My Playlists',
                                active: _playlistSubFilter == 1,
                                onTap: () =>
                                    setState(() => _playlistSubFilter = 1)),
                            const SizedBox(width: 8),
                            _SubFilter(
                                label: 'Saved',
                                active: _playlistSubFilter == 2,
                                onTap: () =>
                                    setState(() => _playlistSubFilter = 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Sort row
                    if (_filter == 0 || _filter == 1)
                      Row(children: [
                        GestureDetector(
                          onTap: _showSortSheet,
                          child: Row(children: [
                            const Icon(Icons.sort_rounded,
                                size: 16, color: AppColors.text2),
                            const SizedBox(width: 4),
                            Text(
                              const [
                                'Recent',
                                'Date added',
                                'Alphabetical',
                                'By author'
                              ][_sortOption],
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text2),
                            ),
                          ]),
                        ),
                        if (_filter == 1) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isGridMode = !_isGridMode),
                            child: Icon(
                              _isGridMode
                                  ? Icons.view_list_rounded
                                  : Icons.grid_view_rounded,
                              size: 20,
                              color: AppColors.text2,
                            ),
                          ),
                        ],
                      ]),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
            ),

            // ── Liked Songs pinned card ────────────────────────────────
            if (_filter == 0 || _filter == 1)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LikedSongsScreen())),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Liked Songs',
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              Text('Your favourite tracks',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: Colors.white70)),
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white70, size: 20),
                      ]),
                    ),
                  ),
                ),
              ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight)),
              )
            else if (_filter == 0)
              ..._buildAllLibrarySlivers()

            // ── Albums filter ─────────────────────────────────────────
            else if (_filter == 2 && _albumsLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight)),
              )
            else if (_filter == 2)
              _albums.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('💿', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No albums yet',
                              style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const SizedBox(height: 6),
                          Text('Like an album to save it here',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.text3)),
                        ]),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final album = _albums[i];
                          final name =
                              (album['title'] ?? 'Unknown Album').toString();
                          final artist = (album['artist'] ?? '').toString();
                          final cover = album['cover_xl']?.toString();
                          return GestureDetector(
                            onTap: () => _openSavedAlbum(ctx, album),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 7),
                              child: Row(children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: cover != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                              imageUrl: cover,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  const Center(
                                                      child: Text('💿',
                                                          style: TextStyle(
                                                              fontSize: 22)))))
                                      : const Center(
                                          child: Text('💿',
                                              style: TextStyle(fontSize: 22))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(name,
                                          style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.purple
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text('Album',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.purpleLight)),
                                        ),
                                        Expanded(
                                            child: Text(artist,
                                                style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: AppColors.text3),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                      ]),
                                    ])),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.text3, size: 20),
                              ]),
                            ),
                          );
                        },
                        childCount: _albums.length,
                      ),
                    )

            // ── Artists filter ─────────────────────────────────────────
            else if (_filter == 3 && _artistsLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight)),
              )
            else if (_filter == 3)
              _artists.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🎤', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No followed artists yet',
                              style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const SizedBox(height: 6),
                          Text('Follow artists to see them here',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.text3)),
                        ]),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final artist = _artists[i];
                          final name =
                              (artist['name'] ?? 'Unknown Artist').toString();
                          final pic = artist['picture_medium']?.toString() ??
                              artist['picture_xl']?.toString() ??
                              artist['picture']?.toString() ??
                              artist['image_url']?.toString();
                          final fans = artist['nb_fan'];
                          final artistId = artist['id'];
                          final fansNum = fans is int
                              ? fans
                              : int.tryParse(fans?.toString() ?? '') ?? 0;
                          final fansStr = fansNum >= 1000000
                              ? '${(fansNum / 1000000).toStringAsFixed(1)}M followers'
                              : fansNum >= 1000
                                  ? '${(fansNum / 1000).toStringAsFixed(0)}K followers'
                                  : fansNum > 0
                                      ? '$fansNum followers'
                                      : 'Artist';
                          return GestureDetector(
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 7),
                              child: Row(children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradPink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: pic != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                              imageUrl: pic,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Center(
                                                  child: Text(
                                                      name[0].toUpperCase(),
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Colors.white)))))
                                      : Center(
                                          child: Text(name[0].toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(name,
                                          style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text)),
                                      Text(fansStr,
                                          style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: AppColors.text3)),
                                    ])),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.text3, size: 20),
                              ]),
                            ),
                          );
                        },
                        childCount: _artists.length,
                      ),
                    )

            // ── Playlists (All / Playlists filter) ─────────────────────
            else if (_filteredPlaylists.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🎵', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 14),
                    Text('Your library is empty',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text('Create your first playlist',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _openCreatePlaylist,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                            gradient: AppColors.primaryBtn,
                            borderRadius: BorderRadius.circular(14)),
                        child: Text('Create Playlist',
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              )
            else if (_isGridMode)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PlaylistGridItem(
                      playlist: _filteredPlaylists[i] as Map<String, dynamic>,
                      onRefresh: _load,
                    ),
                    childCount: _filteredPlaylists.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PlaylistItem(
                    playlist: _filteredPlaylists[i] as Map<String, dynamic>,
                    onRefresh: _load,
                  ),
                  childCount: _filteredPlaylists.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// ── Sub-filter chip ─────────────────────────────────────────────────────────

class _SubFilter extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubFilter(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.purple.withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: active ? AppColors.purple : AppColors.border),
          ),
          child: Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.purpleLight : AppColors.text3)),
        ),
      );
}

class _AlbumLibraryItem extends StatelessWidget {
  final Map<String, dynamic> album;
  final VoidCallback onTap;

  const _AlbumLibraryItem({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (album['title'] ?? 'Unknown Album').toString();
    final artist = (album['artist'] ?? '').toString();
    final cover = album['cover_xl']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: cover != null && cover.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(
                        child: Text('💿', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('💿', style: TextStyle(fontSize: 22)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artist.isEmpty ? 'Album' : artist,
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.text3, size: 20),
        ]),
      ),
    );
  }
}

class _ArtistLibraryItem extends StatelessWidget {
  final Map<String, dynamic> artist;

  const _ArtistLibraryItem({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = (artist['name'] ?? 'Unknown Artist').toString();
    final pic = artist['picture_medium']?.toString() ??
        artist['picture_xl']?.toString() ??
        artist['picture']?.toString() ??
        artist['image_url']?.toString();
    final fans = artist['nb_fan'];
    final artistId = artist['id'];
    final fansNum =
        fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
    final fansStr = fansNum >= 1000000
        ? '${(fansNum / 1000000).toStringAsFixed(1)}M followers'
        : fansNum >= 1000
            ? '${(fansNum / 1000).toStringAsFixed(0)}K followers'
            : fansNum > 0
                ? '$fansNum followers'
                : 'Artist';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        if (artistId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistScreen(
              artistId: artistId.toString(),
              artistName: name,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: AppColors.gradPink,
              shape: BoxShape.circle,
            ),
            child: pic != null && pic.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: pic,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fansStr,
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.text3, size: 20),
        ]),
      ),
    );
  }
}

// ── Badge widget ────────────────────────────────────────────────────────────

class _VisibilityBadge extends StatelessWidget {
  final String visibility;
  const _VisibilityBadge(this.visibility);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    switch (visibility) {
      case 'public':
        bg = const Color(0xFF166534);
        text = const Color(0xFF4ADE80);
        label = 'Public';
        break;
      case 'link':
      case 'by_link':
      case 'friends':
        bg = const Color(0xFF1E3A5F);
        text = const Color(0xFF60A5FA);
        label = 'Friends';
        break;
      case 'saved':
        bg = const Color(0xFF500724);
        text = const Color(0xFFF472B6);
        label = 'Saved';
        break;
      default:
        bg = const Color(0xFF1F2937);
        text = const Color(0xFF9CA3AF);
        label = 'Private';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 10, fontWeight: FontWeight.w700, color: text)),
    );
  }
}

// ── Playlist list item ──────────────────────────────────────────────────────

class _PlaylistItem extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback onRefresh;
  const _PlaylistItem({required this.playlist, required this.onRefresh});

  void _showOptions(BuildContext context) {
    final id = playlist['id'] as int? ?? 0;
    final title = (playlist['title'] ?? 'Untitled').toString();

    Widget item(IconData icon, String label, VoidCallback onTap,
        {Color? color}) {
      return ListTile(
        leading: Icon(icon, size: 22, color: color ?? AppColors.text3),
        title: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 15, color: color ?? AppColors.text)),
        onTap: onTap,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Playlist',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.purpleLight)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 8),
              item(Icons.share_rounded, 'Share', () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: 'Playlist: $title'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              }),
              item(Icons.add_rounded, 'Add tracks', () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistScreen(playlistId: id, playlistTitle: title),
                    ));
              }),
              item(Icons.download_outlined, 'Download', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download coming soon')),
                );
              }),
              item(Icons.edit_rounded, 'Edit playlist', () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreatePlaylistScreen(existingPlaylist: playlist),
                    )).then((_) => onRefresh());
              }),
              item(Icons.delete_rounded, 'Delete playlist', () {
                Navigator.pop(ctx);
                _deletePlaylist(context, id);
              }, color: Colors.redAccent),
            ],
          ),
        ),
      ),
    );
  }

  void _renamePlaylist(BuildContext context, int id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Playlist',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.purple)),
            filled: true,
            fillColor: AppColors.glass,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true && ctrl.text.trim().isNotEmpty) {
        try {
          await ApiService().updatePlaylist(id, title: ctrl.text.trim());
          onRefresh();
        } catch (_) {}
      }
    });
  }

  void _deletePlaylist(BuildContext context, int id) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Playlist',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.outfit(color: AppColors.text2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true) {
        try {
          await ApiService().deletePlaylist(id);
          onRefresh();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = playlist['id'] as int? ?? 0;
    final title = playlist['title'] ?? 'Untitled';
    final trackCount = playlist['track_count'] ?? playlist['tracks_count'] ?? 0;
    final coverUrl = playlist['cover_url'] as String?;
    final visibility = (playlist['visibility'] ?? 'private').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlaylistScreen(
                    playlistId: id,
                    playlistTitle: title.toString(),
                  ))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
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
                            child: Text('🎵', style: TextStyle(fontSize: 22)))))
                : const Center(
                    child: Text('🎵', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                _VisibilityBadge(visibility),
                const SizedBox(width: 6),
                Text('$trackCount songs',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
              ]),
            ]),
          ),
          GestureDetector(
            onTap: () => _showOptions(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.text3),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Playlist grid item ──────────────────────────────────────────────────────

class _PlaylistGridItem extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback onRefresh;
  const _PlaylistGridItem({required this.playlist, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final id = playlist['id'] as int? ?? 0;
    final title = playlist['title'] ?? 'Untitled';
    final trackCount = playlist['track_count'] ?? playlist['tracks_count'] ?? 0;
    final coverUrl = playlist['cover_url'] as String?;
    final visibility = (playlist['visibility'] ?? 'private').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PlaylistScreen(
                    playlistId: id,
                    playlistTitle: title.toString(),
                  ))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                            child: Text('🎵', style: TextStyle(fontSize: 36)))))
                : const Center(
                    child: Text('🎵', style: TextStyle(fontSize: 36))),
          ),
        ),
        const SizedBox(height: 6),
        Text(title.toString(),
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(children: [
          _VisibilityBadge(visibility),
          const SizedBox(width: 6),
          Flexible(
              child: Text('$trackCount songs',
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }
}
