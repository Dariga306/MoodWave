import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../album_screen.dart';
import '../artist_screen.dart';
import '../extra_screens.dart';
import '../genre_tracks_screen.dart';
import '../modals.dart';
import '../player_screen.dart';
import '../weather_screen.dart';
import '../ai_playlist_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchHistory = [];
  List<dynamic> _tracks = [];
  List<dynamic> _artists = [];
  List<dynamic> _albums = [];
  bool _searching = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final data = await ApiService().getSearchHistory(limit: 20);
    if (!mounted) return;
    setState(() => _searchHistory = data);
  }

  Future<void> _clearAllHistory() async {
    try {
      await ApiService().clearSearchHistory();
      if (!mounted) return;
      setState(() => _searchHistory = []);
    } catch (_) {}
  }

  Future<void> _deleteHistoryItem(int id) async {
    try {
      await ApiService().deleteSearchHistoryItem(id);
      await _loadHistory();
    } catch (_) {}
  }

  Future<void> _saveTrackHistory(Map<String, dynamic> track) async {
    try {
      final query = _ctrl.text.trim().isNotEmpty
          ? _ctrl.text.trim()
          : [track['artist']?.toString(), track['title']?.toString()]
              .whereType<String>().where((e) => e.isNotEmpty).join(' ');
      await ApiService().saveSearchHistory(
        query: query,
        resultType: 'track',
        resultId: (track['spotify_id'] ?? track['track_id'] ?? track['deezer_id'])?.toString(),
        resultTitle: (track['title'] ?? track['trackName'] ?? 'Unknown').toString(),
        resultCover: (track['cover_url'] ?? track['artworkUrl100'])?.toString(),
      );
      await _loadHistory();
    } catch (_) {}
  }

  Future<void> _saveArtistHistory(Map<String, dynamic> artist) async {
    try {
      final query = _ctrl.text.trim().isNotEmpty
          ? _ctrl.text.trim()
          : (artist['name']?.toString() ?? '');
      await ApiService().saveSearchHistory(
        query: query,
        resultType: 'artist',
        resultId: artist['id']?.toString(),
        resultTitle: artist['name']?.toString(),
        resultCover: (artist['picture_xl'] ?? artist['picture_medium'] ?? artist['image_url'])?.toString(),
      );
      await _loadHistory();
    } catch (_) {}
  }

  Future<void> _openTrack(Map<String, dynamic> track) async {
    await _saveTrackHistory(track);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(track: track)));
  }

  void _useHistoryItem(Map<String, dynamic> item) {
    final query = item['query']?.toString() ?? '';
    if (query.isEmpty) return;
    _ctrl.text = query;
    _onChanged(query);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _hasQuery = false;
        _tracks = [];
        _artists = [];
        _albums = [];
        _searching = false;
      });
      return;
    }
    setState(() { _hasQuery = true; _searching = true; });
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    String artistQuery = q;
    if (q.contains(' - ')) artistQuery = q.split(' - ').first.trim();
    else if (q.contains(' – ')) artistQuery = q.split(' – ').first.trim();
    else if (q.contains(':')) artistQuery = q.split(':').first.trim();
    else if (q.contains(' | ')) artistQuery = q.split(' | ').first.trim();

    try {
      final results = await Future.wait([
        ApiService().searchTracksWithFallback(q, limit: 10).catchError((_) => <Map<String, dynamic>>[]),
        ApiService().searchArtistsList(artistQuery, limit: 12).catchError((_) => <Map<String, dynamic>>[]),
        ApiService().searchAlbums(q, limit: 8).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;

      final tracks = (results[0] as List?) ?? [];
      final seenIds = <String>{};
      final artists = <Map<String, dynamic>>[];
      for (final a in (results[1] as List?) ?? []) {
        final artist = Map<String, dynamic>.from(a as Map);
        final id = artist['id']?.toString() ?? '';
        if (id.isNotEmpty && seenIds.add(id)) artists.add(artist);
      }
      final albums = ((results[2] as List?) ?? []).whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() {
        _tracks = tracks;
        _artists = artists;
        _albums = albums;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _openArtist(Map<String, dynamic> artist) async {
    final artistId = artist['id']?.toString();
    final artistName = artist['name']?.toString() ?? 'Unknown';
    if (artistId == null || artistId.isEmpty) return;
    await _saveArtistHistory(artist);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ArtistScreen(artistId: artistId, artistName: artistName),
    ));
  }

  void _showTrackMenu(Map<String, dynamic> track) {
    final title = (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
    final artist = (track['artist'] ?? track['artistName'] ?? '').toString();
    final coverUrl = (track['cover_url'] ?? track['artworkUrl100'])?.toString();
    final artistId = track['artist_id']?.toString();

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
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(10)),
                    child: coverUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Center(child: Text('🎵'))))
                        : const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                  ])),
                ]),
              ),
              const Divider(color: Color(0x1AFFFFFF)),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, size: 22, color: AppColors.text3),
                title: Text('Add to playlist', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddToPlaylist(context, track: track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, size: 22, color: AppColors.text3),
                title: Text('Add to queue', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to queue', style: GoogleFonts.outfit(fontSize: 13)),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (artistId != null && artistId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_rounded, size: 22, color: AppColors.text3),
                  title: Text('Go to artist', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ArtistScreen(artistId: artistId, artistName: artist),
                    ));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        onTap: () => _focus.unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Search', style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: AppColors.text, letterSpacing: -0.02 * 26)),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search_rounded, size: 20, color: AppColors.text3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            onChanged: _onChanged,
                            style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: 'What do you want to listen to?',
                              hintStyle: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_hasQuery)
                          GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              setState(() {
                                _hasQuery = false;
                                _tracks = [];
                                _artists = [];
                                _albums = [];
                                _searching = false;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.close_rounded, size: 18, color: AppColors.text3),
                            ),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),

              if (_searching)
                _SearchSkeleton()
              else if (_hasQuery) ...[
                // ── Artists ──────────────────────────────────────────────
                if (_artists.isNotEmpty) ...[
                  _SectionRow(
                    title: 'Artists',
                    onShowAll: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _AllArtistsScreen(artists: _artists, onOpen: _openArtist),
                    )),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _artists.length,
                      itemBuilder: (_, i) => _ArtistCard(
                        artist: _artists[i] as Map<String, dynamic>,
                        onTap: () => _openArtist(_artists[i] as Map<String, dynamic>),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Albums ────────────────────────────────────────────────
                if (_albums.isNotEmpty) ...[
                  _SectionRow(
                    title: 'Albums',
                    onShowAll: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _AllAlbumsScreen(albums: _albums.cast<Map<String, dynamic>>()),
                    )),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 175,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _albums.length,
                      itemBuilder: (_, i) {
                        final album = _albums[i] as Map<String, dynamic>;
                        final albumId = int.tryParse(album['id'].toString()) ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AlbumScreen(albumId: albumId,
                                initialTitle: album['title']?.toString(),
                                initialCover: album['cover_xl']?.toString()),
                          )),
                          child: _SearchAlbumCard(album: album),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Songs ─────────────────────────────────────────────────
                if (_tracks.isNotEmpty) ...[
                  _SectionRow(title: 'Songs'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ..._tracks.take(5).map((track) => _TrackResult(
                          track: track as Map<String, dynamic>,
                          onTap: () => _openTrack(Map<String, dynamic>.from(track as Map)),
                          onMenuTap: () => _showTrackMenu(Map<String, dynamic>.from(track as Map)),
                        )),
                        if (_tracks.length > 5) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => _AllSongsScreen(
                                query: _ctrl.text.trim(),
                                tracks: _tracks.cast<Map<String, dynamic>>(),
                                onOpenTrack: _openTrack,
                                onMenuTap: _showTrackMenu,
                              ),
                            )),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text('Show all songs',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: AppColors.purpleLight)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── No results ────────────────────────────────────────────
                if (_tracks.isEmpty && _artists.isEmpty && _albums.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                    child: Center(
                      child: Column(children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.text3),
                        const SizedBox(height: 12),
                        Text(
                          'No results found for\n"${_ctrl.text.trim()}"',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                        const SizedBox(height: 8),
                        Text('Check the spelling or try a different keyword',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                      ]),
                    ),
                  ),
              ] else ...[
                // ── Recent searches ────────────────────────────────────────
                if (_searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent searches', style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                        GestureDetector(
                          onTap: _clearAllHistory,
                          child: Text('Clear all', style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.purpleLight)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _searchHistory.map((item) {
                        final itemId = item['id'] as int?;
                        final title = item['result_title']?.toString()
                            ?? item['query']?.toString() ?? '';
                        final subtitle = item['result_type']?.toString() ?? 'track';
                        final coverUrl = item['result_cover']?.toString();
                        return GestureDetector(
                          onTap: () => _useHistoryItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    borderRadius: BorderRadius.circular(10)),
                                child: coverUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Center(child: Text('🎵'))))
                                    : const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                                Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                              ])),
                              if (itemId != null)
                                GestureDetector(
                                  onTap: () => _deleteHistoryItem(itemId),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.close_rounded, size: 16, color: AppColors.text3),
                                  ),
                                ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // ── Explore ────────────────────────────────────────────────
                const SizedBox(height: 20),
                const SectionHeader(title: 'Explore'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.4,
                    children: [
                      _ExploreCard('🌍', 'Discover', AppColors.gradBlue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverScreen()))),
                      _ExploreCard('🏙', 'Charts', AppColors.gradPurple,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityChartsScreen()))),
                      _ExploreCard('📻', 'Radio', AppColors.gradMixed,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioScreen()))),
                      _ExploreCard('🎉', 'Party', AppColors.gradPink,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseRoomsScreen()))),
                      _ExploreCard('✦', 'AI Mix', AppColors.gradOrange,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPlaylistScreen()))),
                      _ExploreCard('🌨', 'Weather', AppColors.gradCyan,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))),
                    ],
                  ),
                ),

                // ── Browse Genres ──────────────────────────────────────────
                const SizedBox(height: 24),
                const SectionHeader(title: 'Browse Genres'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _GenreCard(emoji: '🎤', name: 'Pop',
                          gradient: const LinearGradient(colors: [Color(0xFF7c3aed), Color(0xFFa855f7)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'Pop', emoji: '🎤',
                                gradient: LinearGradient(colors: [Color(0xFF7c3aed), Color(0xFFa855f7)]))))),
                      _GenreCard(emoji: '🎸', name: 'Rock',
                          gradient: const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'Rock', emoji: '🎸',
                                gradient: LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]))))),
                      _GenreCard(emoji: '✨', name: 'K-Pop',
                          gradient: const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'K-Pop', emoji: '✨',
                                gradient: LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]))))),
                      _GenreCard(emoji: '🎤', name: 'Hip-Hop',
                          gradient: const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'Hip-Hop', emoji: '🎤',
                                gradient: LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]))))),
                      _GenreCard(emoji: '🎹', name: 'Electronic',
                          gradient: const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'Electronic', emoji: '🎹',
                                gradient: LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]))))),
                      _GenreCard(emoji: '🌙', name: 'Ambient',
                          gradient: const LinearGradient(colors: [Color(0xFF3b0764), Color(0xFF7c3aed)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const GenreTracksScreen(genre: 'Ambient', emoji: '🌙',
                                gradient: LinearGradient(colors: [Color(0xFF3b0764), Color(0xFF7c3aed)]))))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton loading ────────────────────────────────────────────────────────

class _SearchSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Artists skeleton
        _skel(80, 14),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, __) => Container(
              width: 80, margin: const EdgeInsets.only(right: 14),
              child: Column(children: [
                Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                ),
                const SizedBox(height: 6),
                _skel(60, 10),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Albums skeleton
        _skel(80, 14),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, __) => Container(
              width: 120, margin: const EdgeInsets.only(right: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 6),
                _skel(100, 10),
                const SizedBox(height: 4),
                _skel(70, 8),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Songs skeleton
        _skel(60, 14),
        const SizedBox(height: 8),
        ...List.generate(5, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _skel(double.infinity, 12),
              const SizedBox(height: 4),
              _skel(100, 10),
            ])),
          ]),
        )),
      ]),
    );
  }

  static Widget _skel(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

// ── Section row with optional Show All ─────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String title;
  final VoidCallback? onShowAll;
  const _SectionRow({required this.title, this.onShowAll});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Text(title, style: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
      const Spacer(),
      if (onShowAll != null)
        GestureDetector(
          onTap: onShowAll,
          child: Text('Show all', style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
        ),
    ]),
  );
}

// ── All Songs Screen ────────────────────────────────────────────────────────

class _AllSongsScreen extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> tracks;
  final Future<void> Function(Map<String, dynamic>) onOpenTrack;
  final void Function(Map<String, dynamic>) onMenuTap;
  const _AllSongsScreen({
    required this.query,
    required this.tracks,
    required this.onOpenTrack,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Songs', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
          if (query.isNotEmpty)
            Text(query, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ]),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (_, i) => _TrackResult(
          track: tracks[i],
          onTap: () => onOpenTrack(Map<String, dynamic>.from(tracks[i])),
          onMenuTap: () => onMenuTap(Map<String, dynamic>.from(tracks[i])),
        ),
      ),
    );
  }
}

// ── All Artists Screen ──────────────────────────────────────────────────────

class _AllArtistsScreen extends StatelessWidget {
  final List<dynamic> artists;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  const _AllArtistsScreen({required this.artists, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Artists', style: GoogleFonts.outfit(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 20, crossAxisSpacing: 14, childAspectRatio: 0.75,
        ),
        itemCount: artists.length,
        itemBuilder: (_, i) => _ArtistCard(
          artist: artists[i] as Map<String, dynamic>,
          onTap: () => onOpen(artists[i] as Map<String, dynamic>),
        ),
      ),
    );
  }
}

// ── All Albums Screen ───────────────────────────────────────────────────────

class _AllAlbumsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> albums;
  const _AllAlbumsScreen({required this.albums});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Albums', style: GoogleFonts.outfit(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 20, crossAxisSpacing: 14, childAspectRatio: 0.75,
        ),
        itemCount: albums.length,
        itemBuilder: (_, i) {
          final album = albums[i];
          final id = int.tryParse(album['id'].toString()) ?? 0;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AlbumScreen(albumId: id,
                  initialTitle: album['title']?.toString(),
                  initialCover: album['cover_xl']?.toString()),
            )),
            child: _SearchAlbumCard(album: album),
          );
        },
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _ExploreCard extends StatelessWidget {
  final String emoji, label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _ExploreCard(this.emoji, this.label, this.gradient, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ),
  );
}

class _TrackResult extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;
  const _TrackResult({required this.track, this.onTap, this.onMenuTap});

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];
    final duration = _fmt(track['duration_ms'] ?? track['trackTimeMillis'] ?? 0);

    return GestureDetector(
      onTap: onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(10)),
            child: coverUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(child: Text('🎵'))))
                : const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ])),
          if (duration.isNotEmpty)
            Text(duration, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onMenuTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.text3),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;
  final VoidCallback onTap;
  const _ArtistCard({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = artist['name']?.toString() ?? 'Unknown';
    final imageUrl = artist['picture_xl'] ?? artist['picture_medium'] ?? artist['image_url'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 14),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border2),
            ),
            child: imageUrl != null
                ? ClipOval(child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)))))
                : Center(child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text('Artist', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
        ]),
      ),
    );
  }
}

class _SearchAlbumCard extends StatelessWidget {
  final Map<String, dynamic> album;
  const _SearchAlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final title = album['title']?.toString() ?? 'Unknown';
    final artist = album['artist']?.toString() ?? '';
    final coverUrl = album['cover_xl']?.toString();

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(12)),
          child: coverUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(child: Text('💿'))))
              : const Center(child: Text('💿', style: TextStyle(fontSize: 28))),
        ),
        const SizedBox(height: 6),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        if (artist.isNotEmpty)
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
      ]),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final String emoji, name;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _GenreCard({required this.emoji, required this.name, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ),
  );
}
