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
  List<String> _trendingSearches = [];
  bool _searching = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadTrending();
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

  Future<void> _loadTrending() async {
    try {
      final resp = await ApiService().globalSearch('');
      final trending = (resp['trending'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (!mounted) return;
      setState(() => _trendingSearches = trending.take(10).toList());
    } catch (_) {}
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
          : [
              track['artist']?.toString(),
              track['title']?.toString(),
            ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
      await ApiService().saveSearchHistory(
        query: query,
        resultType: 'track',
        resultId:
            (track['spotify_id'] ?? track['track_id'] ?? track['deezer_id'])
                ?.toString(),
        resultTitle:
            (track['title'] ?? track['trackName'] ?? 'Unknown').toString(),
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
        resultCover: (artist['picture_xl'] ??
                artist['picture_medium'] ??
                artist['image_url'])
            ?.toString(),
      );
      await _loadHistory();
    } catch (_) {}
  }

  Future<void> _openTrack(Map<String, dynamic> track) async {
    await _saveTrackHistory(track);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
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
    setState(() {
      _hasQuery = true;
      _searching = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(q.trim()),
    );
  }

  Future<void> _search(String q) async {
    // Extract artist name if query has "Artist - Song" separator
    String artistQuery = q;
    if (q.contains(' - ')) {
      artistQuery = q.split(' - ').first.trim();
    } else if (q.contains(' – ')) {
      artistQuery = q.split(' – ').first.trim();
    } else if (q.contains(':')) {
      artistQuery = q.split(':').first.trim();
    } else if (q.contains(' | ')) {
      artistQuery = q.split(' | ').first.trim();
    }

    try {
      final results = await Future.wait([
        ApiService()
            .searchTracksWithFallback(q, limit: 10)
            .catchError((_) => <Map<String, dynamic>>[]),
        ApiService()
            .searchArtistsList(artistQuery, limit: 12)
            .catchError((_) => <Map<String, dynamic>>[]),
        ApiService()
            .searchAlbums(q, limit: 8)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;

      final tracks = (results[0] as List?) ?? [];

      final seenArtistIds = <String>{};
      final artists = <Map<String, dynamic>>[];
      for (final a in (results[1] as List?) ?? []) {
        final artist = Map<String, dynamic>.from(a as Map);
        final id = artist['id']?.toString() ?? '';
        if (id.isNotEmpty && seenArtistIds.add(id)) {
          artists.add(artist);
        }
      }

      final albums = ((results[2] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId: artistId,
          artistName: artistName,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.02 * 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.text3,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                onChanged: _onChanged,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  color: AppColors.text,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Artists, songs, playlists...',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 15,
                                    color: AppColors.text3,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  ),
                )
              else if (_hasQuery) ...[
                if (_artists.isNotEmpty) ...[
                  const SectionHeader(title: 'Artists'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _artists.length,
                      itemBuilder: (_, index) => _ArtistCard(
                        artist: _artists[index] as Map<String, dynamic>,
                        onTap: () => _openArtist(
                          _artists[index] as Map<String, dynamic>,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_albums.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Albums'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 175,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _albums.length,
                      itemBuilder: (_, index) {
                        final album =
                            _albums[index] as Map<String, dynamic>;
                        final albumId =
                            int.tryParse(album['id'].toString()) ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumScreen(
                                albumId: albumId,
                                initialTitle: album['title']?.toString(),
                                initialCover: album['cover_xl']?.toString(),
                              ),
                            ),
                          ),
                          child: _SearchAlbumCard(album: album),
                        );
                      },
                    ),
                  ),
                ],
                if (_tracks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Tracks'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _tracks
                          .map(
                            (track) => _TrackResult(
                              track: track as Map<String, dynamic>,
                              onTap: () => _openTrack(
                                Map<String, dynamic>.from(track as Map),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (_tracks.isEmpty && _artists.isEmpty && _albums.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No results found',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            'Try a different search',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                if (_searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recently Played',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        GestureDetector(
                          onTap: _clearAllHistory,
                          child: Text('Clear all',
                              style: GoogleFonts.outfit(
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
                        final title = item['result_title']?.toString() ??
                            item['query']?.toString() ??
                            '';
                        final subtitle =
                            item['result_type']?.toString() ?? 'track';
                        final coverUrl = item['result_cover']?.toString();
                        return GestureDetector(
                          onTap: () => _useHistoryItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    borderRadius: BorderRadius.circular(10)),
                                child: coverUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              const SizedBox(),
                                          errorWidget: (_, __, ___) =>
                                              const Center(child: Text('🎵')),
                                        ),
                                      )
                                    : const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    Text(subtitle,
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text3)),
                                  ],
                                ),
                              ),
                              if (itemId != null)
                                GestureDetector(
                                  onTap: () => _deleteHistoryItem(itemId),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.close_rounded,
                                        size: 16, color: AppColors.text3),
                                  ),
                                ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                // ── Explore ──────────────────────────────────────────────
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
                      _ExploreCard(
                          '🌍', 'Discover', AppColors.gradBlue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverScreen()))),
                      _ExploreCard(
                          '🏙', 'Charts', AppColors.gradPurple,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityChartsScreen()))),
                      _ExploreCard(
                          '📻', 'Radio', AppColors.gradMixed,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioScreen()))),
                      _ExploreCard(
                          '🎉', 'Party', AppColors.gradPink,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseRoomsScreen()))),
                      _ExploreCard(
                          '✦', 'AI Mix', AppColors.gradOrange,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPlaylistScreen()))),
                      _ExploreCard(
                          '🌨', 'Weather', AppColors.gradCyan,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))),
                    ],
                  ),
                ),
                // ── Browse Genres ─────────────────────────────────────────
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
                      _GenreCard(
                        emoji: '🎤',
                        name: 'Pop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7c3aed), Color(0xFFa855f7)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'Pop', emoji: '🎤',
                            gradient: LinearGradient(colors: [Color(0xFF7c3aed), Color(0xFFa855f7)]),
                          ),
                        )),
                      ),
                      _GenreCard(
                        emoji: '🎸',
                        name: 'Rock',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'Rock', emoji: '🎸',
                            gradient: LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]),
                          ),
                        )),
                      ),
                      _GenreCard(
                        emoji: '✨',
                        name: 'K-Pop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9d174d), Color(0xFFec4899)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'K-Pop', emoji: '✨',
                            gradient: LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                          ),
                        )),
                      ),
                      _GenreCard(
                        emoji: '🎤',
                        name: 'Hip-Hop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1c1917), Color(0xFF57534e)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'Hip-Hop', emoji: '🎤',
                            gradient: LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]),
                          ),
                        )),
                      ),
                      _GenreCard(
                        emoji: '🎹',
                        name: 'Electronic',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF164e63), Color(0xFF06b6d4)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'Electronic', emoji: '🎹',
                            gradient: LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]),
                          ),
                        )),
                      ),
                      _GenreCard(
                        emoji: '🌙',
                        name: 'Ambient',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3b0764), Color(0xFF7c3aed)],
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const GenreTracksScreen(
                            genre: 'Ambient', emoji: '🌙',
                            gradient: LinearGradient(colors: [Color(0xFF3b0764), Color(0xFF7c3aed)]),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Made for You banner removed ───────────────────────────
              if (false) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _ForYouScreen(
                          category: 'my_mix',
                          title: 'Made for You',
                          subtitle: 'Your personal music picks',
                        ),
                      ),
                    ),
                    child: Container(
                      height: 104,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFA855F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // Decorative music note circles
                          Positioned(
                            right: 70, top: -10,
                            child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10, bottom: -20,
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          // Small playlist card (right side)
                          Positioned(
                            right: 16, top: 0, bottom: 0,
                            child: Center(
                              child: Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withOpacity(0.18),
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.library_music_rounded,
                                      color: Colors.white, size: 32),
                                ),
                              ),
                            ),
                          ),
                          // Text
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 104, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Made for You',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your personal picks',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─── For You Card ─────────────────────────────────────────────────────────────

class _ForYouCard extends StatelessWidget {
  final String emoji, label, sublabel;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _ForYouCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(sublabel,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      );
}

// ─── For You Screen ───────────────────────────────────────────────────────────

class _ForYouScreen extends StatefulWidget {
  final String category, title, subtitle;
  const _ForYouScreen({
    required this.category,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<_ForYouScreen> {
  List<dynamic> _tracks = [];
  bool _loading = true;

  // gradient header colour per category
  LinearGradient get _headerGradient {
    switch (widget.category) {
      case 'on_repeat':
        return const LinearGradient(
            colors: [Color(0xFF6C3FC7), Color(0xFF9B5DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 'flashbacks':
        return const LinearGradient(
            colors: [Color(0xFF1a6b5a), Color(0xFF2ec4a6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 'my_mix':
        return const LinearGradient(
            colors: [Color(0xFF5B21B6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      default:
        return const LinearGradient(
            colors: [Color(0xFF1a3d7a), Color(0xFF3a7bd5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
    }
  }

  String get _headerEmoji {
    switch (widget.category) {
      case 'on_repeat':
        return '🔁';
      case 'flashbacks':
        return '⏳';
      case 'my_mix':
        return '🎨';
      default:
        return '🔭';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List<dynamic> data;
      switch (widget.category) {
        case 'on_repeat':
          data = await ApiService().getOnRepeat(limit: 30);
        case 'flashbacks':
          data = await ApiService().getFlashbacks(limit: 30);
        default:
          data = await ApiService().getRecommendations();
      }
      if (!mounted) return;
      setState(() {
        _tracks = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatDuration(dynamic durationMs) {
    final value =
        durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight))
          : CustomScrollView(
              slivers: [
                // ── Gradient header ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(gradient: _headerGradient),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_headerEmoji,
                                    style: const TextStyle(fontSize: 44)),
                                const SizedBox(height: 8),
                                Text(widget.title,
                                    style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(widget.subtitle,
                                    style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: Colors.white70)),
                                const SizedBox(height: 12),
                                Text(
                                  '${_tracks.length} songs',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Play all button ──────────────────────────────────
                if (_tracks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () {
                            final queue = _tracks
                                .whereType<Map>()
                                .map((t) => Map<String, dynamic>.from(t))
                                .toList();
                            final first = Map<String, dynamic>.from(queue.first)
                              ..['queue'] = queue;
                            Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => PlayerScreen(track: first)));
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: _headerGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text('Play all',
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                      ]),
                    ),
                  ),

                // ── Track list ───────────────────────────────────────
                if (_tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎵',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('Nothing here yet',
                              style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text('Keep listening to fill this up!',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.text3)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final track =
                            Map<String, dynamic>.from(_tracks[i] as Map);
                        final title =
                            track['title'] ?? track['trackName'] ?? 'Unknown';
                        final artist =
                            track['artist'] ?? track['artistName'] ?? '';
                        final cover =
                            track['cover_url'] ?? track['artworkUrl100'];
                        final dur = _formatDuration(track['duration_ms']);
                        return GestureDetector(
                          onTap: () {
                            track['queue'] = _tracks;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PlayerScreen(track: track)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 7),
                            child: Row(children: [
                              // Cover
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: cover != null
                                    ? CachedNetworkImage(
                                        imageUrl: cover.toString(),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            const SizedBox(),
                                        errorWidget: (_, __, ___) => Container(
                                            width: 50,
                                            height: 50,
                                            color: AppColors.surface,
                                            child: const Icon(Icons.music_note,
                                                color: AppColors.text3)))
                                    : Container(
                                        width: 50,
                                        height: 50,
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
                                    Text(title.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(artist.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                            color: AppColors.text3,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (dur.isNotEmpty)
                                Text(dur,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.text3)),
                            ]),
                          ),
                        );
                      },
                      childCount: _tracks.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String emoji, label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _ExploreCard(this.emoji, this.label, this.gradient, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          decoration: BoxDecoration(
              gradient: gradient, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ])));
}

class _TrackResult extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback? onTap;
  const _TrackResult({required this.track, this.onTap});

  String _formatDuration(dynamic durationMs) {
    final value =
        durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  Future<void> _openArtist(BuildContext context) async {
    final artistName = track['artist'] ?? track['artistName'] ?? '';
    final directId = track['artist_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            artistId: directId,
            artistName: artistName,
          ),
        ),
      );
      return;
    }

    try {
      final result = await ApiService().searchArtist(artistName.toString());
      final artist = result['artist'] as Map<String, dynamic>?;
      if (!context.mounted || artist == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            artistId: artist['id'].toString(),
            artistName: artist['name']?.toString() ?? artistName.toString(),
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];
    final duration = _formatDuration(
      track['duration_ms'] ?? track['trackTimeMillis'] ?? 0,
    );

    return GestureDetector(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 20)),
                    ),
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
                      color: AppColors.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openArtist(context),
                    child: Text(
                      artist,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (duration.isNotEmpty)
              Text(
                duration,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
              ),
            const SizedBox(width: 8),
            Text(
              '›',
              style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3),
            ),
          ],
        ),
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
    final imageUrl =
        artist['picture_xl'] ?? artist['picture_medium'] ?? artist['image_url'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
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
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              'Artist',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
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
    final year = (album['release_date']?.toString() ?? '').split('-').first;

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
            child: coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) =>
                          const Center(child: Text('💿')),
                    ),
                  )
                : const Center(
                    child: Text('💿', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (artist.isNotEmpty)
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3),
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

class _GenreCard extends StatelessWidget {
  final String emoji;
  final String name;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GenreCard({
    required this.emoji,
    required this.name,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
