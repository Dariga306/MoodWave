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
import '../playlist_screen.dart';
import '../user_profile_screen.dart';
import '../weather_screen.dart';
import '../ai_playlist_screen.dart';
import 'explore_section.dart';
import 'genre_section.dart';

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
  List<dynamic> _playlists = [];
  List<dynamic> _users = [];
  int _categoryIndex =
      0; // 0=All 1=Tracks 2=Artists 3=Albums 4=Playlists 5=Profiles
  List<String> _trendingSearches = [];
  List<String> _suggestions = [];
  Timer? _suggestionDebounce;
  bool _searching = false;
  bool _hasQuery = false;
  bool _showAllHistory = false;

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .trim();
  }

  int _scoreSearchMatch(
    String query,
    String primary, {
    String secondary = '',
  }) {
    final q = _normalizeSearchText(query);
    final first = _normalizeSearchText(primary);
    final second = _normalizeSearchText(secondary);
    if (q.isEmpty) return 0;

    var score = 0;
    if (first == q) score += 120;
    if (first.startsWith(q)) score += 70;
    if (first.contains(q)) score += 40;
    if (second == q) score += 30;
    if (second.startsWith(q)) score += 20;
    if (second.contains(q)) score += 10;
    return score;
  }

  List<Map<String, dynamic>> _sortAlbums(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aScore = _scoreSearchMatch(
        query,
        a['title']?.toString() ?? '',
        secondary: a['artist']?.toString() ?? '',
      );
      final bScore = _scoreSearchMatch(
        query,
        b['title']?.toString() ?? '',
        secondary: b['artist']?.toString() ?? '',
      );
      if (aScore != bScore) return bScore.compareTo(aScore);
      final aTracks = int.tryParse('${a['nb_tracks'] ?? 0}') ?? 0;
      final bTracks = int.tryParse('${b['nb_tracks'] ?? 0}') ?? 0;
      if (aTracks != bTracks) return bTracks.compareTo(aTracks);
      return (a['title']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['title']?.toString() ?? '').toLowerCase());
    });
    return sorted;
  }

  List<Map<String, dynamic>> _sortTracks(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aScore = _scoreSearchMatch(
        query,
        a['title']?.toString() ?? a['trackName']?.toString() ?? '',
        secondary: a['artist']?.toString() ?? a['artistName']?.toString() ?? '',
      );
      final bScore = _scoreSearchMatch(
        query,
        b['title']?.toString() ?? b['trackName']?.toString() ?? '',
        secondary: b['artist']?.toString() ?? b['artistName']?.toString() ?? '',
      );
      if (aScore != bScore) return bScore.compareTo(aScore);
      return (a['title']?.toString() ?? a['trackName']?.toString() ?? '')
          .toLowerCase()
          .compareTo(
            (b['title']?.toString() ?? b['trackName']?.toString() ?? '')
                .toLowerCase(),
          );
    });
    return sorted;
  }

  List<Map<String, dynamic>> _sortArtists(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aScore = _scoreSearchMatch(query, a['name']?.toString() ?? '');
      final bScore = _scoreSearchMatch(query, b['name']?.toString() ?? '');
      if (aScore != bScore) return bScore.compareTo(aScore);
      final aFans = int.tryParse('${a['nb_fan'] ?? 0}') ?? 0;
      final bFans = int.tryParse('${b['nb_fan'] ?? 0}') ?? 0;
      if (aFans != bFans) return bFans.compareTo(aFans);
      return (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase());
    });
    return sorted;
  }

  List<Map<String, dynamic>> _sortPlaylists(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aScore = _scoreSearchMatch(
        query,
        a['title']?.toString() ?? '',
        secondary: a['description']?.toString() ?? '',
      );
      final bScore = _scoreSearchMatch(
        query,
        b['title']?.toString() ?? '',
        secondary: b['description']?.toString() ?? '',
      );
      if (aScore != bScore) return bScore.compareTo(aScore);
      final aTracks = int.tryParse('${a['track_count'] ?? 0}') ?? 0;
      final bTracks = int.tryParse('${b['track_count'] ?? 0}') ?? 0;
      return bTracks.compareTo(aTracks);
    });
    return sorted;
  }

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
    _suggestionDebounce?.cancel();
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
      final trending =
          (resp['trending'] as List?)?.map((e) => e.toString()).toList() ?? [];
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

  Future<void> _saveUserHistory(Map<String, dynamic> user) async {
    try {
      final query = _ctrl.text.trim().isNotEmpty
          ? _ctrl.text.trim()
          : ((user['display_name'] ?? user['username'] ?? 'User').toString());
      await ApiService().saveSearchHistory(
        query: query,
        resultType: 'profile',
        resultId: user['id']?.toString(),
        resultTitle:
            (user['display_name'] ?? user['username'] ?? 'User').toString(),
        resultCover: (user['avatar_url'] ?? '').toString(),
      );
      await _loadHistory();
    } catch (_) {}
  }

  Future<void> _savePlaylistHistory(Map<String, dynamic> playlist) async {
    try {
      final query = _ctrl.text.trim().isNotEmpty
          ? _ctrl.text.trim()
          : (playlist['title']?.toString() ?? 'Playlist');
      await ApiService().saveSearchHistory(
        query: query,
        resultType: 'playlist',
        resultId: playlist['id']?.toString(),
        resultTitle: playlist['title']?.toString(),
        resultCover: playlist['cover_url']?.toString(),
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

  void _openAlbum(Map<String, dynamic> album) {
    final albumId = int.tryParse(album['id'].toString()) ?? 0;
    if (albumId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumScreen(
          albumId: albumId,
          initialTitle: album['title']?.toString(),
          initialCover: album['cover_xl']?.toString(),
        ),
      ),
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
    _suggestionDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _hasQuery = false;
        _tracks = [];
        _artists = [];
        _albums = [];
        _playlists = [];
        _users = [];
        _categoryIndex = 0;
        _searching = false;
        _suggestions = [];
      });
      return;
    }
    setState(() {
      _hasQuery = true;
      _searching = true;
    });
    _suggestionDebounce = Timer(const Duration(milliseconds: 90), () async {
      final sug = await ApiService().getSearchSuggestions(q.trim());
      if (!mounted) return;
      setState(() => _suggestions = sug);
    });
    _debounce = Timer(
      const Duration(milliseconds: 220),
      () => _search(q.trim()),
    );
  }

  Future<void> _search(String q) async {
    // Один запрос к /search?type=all — бэкенд возвращает tracks+artists+albums+playlists+users
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
      final result = await ApiService()
          .globalSearch(q, type: 'all')
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return;

      List<Map<String, dynamic>> _parseList(dynamic raw) =>
          ((raw as List?) ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      final tracks = _sortTracks(_parseList(result['tracks']), q);

      final seenArtistIds = <String>{};
      final rawArtists = _parseList(result['artists']);
      final artists = <Map<String, dynamic>>[];
      for (final a in rawArtists) {
        final id = a['id']?.toString() ?? '';
        if (id.isNotEmpty && seenArtistIds.add(id)) artists.add(a);
      }

      final albums = _sortAlbums(_parseList(result['albums']), q);
      final users = _parseList(result['users']);
      final playlists =
          _sortPlaylists(_parseList(result['playlists']), q);

      setState(() {
        _tracks = tracks;
        _artists = _sortArtists(artists, artistQuery);
        _albums = albums;
        _playlists = playlists;
        _users = users;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  List<Widget> _buildSuggestions() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return [];
    final items = _suggestions.isNotEmpty ? _suggestions : [q];
    return items
        .map((s) => _SuggestionRow(
              text: s,
              onTap: () {
                _ctrl.text = s;
                _debounce?.cancel();
                _suggestionDebounce?.cancel();
                setState(() {
                  _hasQuery = true;
                  _searching = true;
                  _suggestions = [];
                });
                _search(s);
              },
            ))
        .toList();
  }

  List<Widget> _buildUnifiedResults() {
    final trackList = _tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final artistList = _artists
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final albumList = _albums
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final playlistList = _playlists
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final userList = _users
        .whereType<Map>()
        .map((u) => Map<String, dynamic>.from(u))
        .toList();

    final widgets = <Widget>[];

    if (_categoryIndex == 1) {
      for (final t in trackList) {
        widgets.add(_FlatTrackRow(track: t, onTap: () => _openTrack(t)));
      }
    } else if (_categoryIndex == 2) {
      for (final a in artistList) {
        widgets.add(_FlatArtistRow(artist: a, onTap: () => _openArtist(a)));
      }
    } else if (_categoryIndex == 3) {
      for (final a in albumList) {
        widgets.add(_FlatAlbumRow(album: a, onTap: () => _openAlbum(a)));
      }
    } else if (_categoryIndex == 4) {
      for (final p in playlistList) {
        widgets
            .add(_FlatPlaylistRow(playlist: p, onTap: () => _openPlaylist(p)));
      }
    } else if (_categoryIndex == 5) {
      for (final u in userList) {
        widgets.add(_FlatUserRow(user: u, onTap: () => _openUser(u)));
      }
    } else {
      for (var i = 0; i < artistList.length && i < 3; i++) {
        final a = artistList[i];
        widgets.add(_FlatArtistRow(artist: a, onTap: () => _openArtist(a)));
      }
      for (var i = 0; i < userList.length && i < 2; i++) {
        final u = userList[i];
        widgets.add(_FlatUserRow(user: u, onTap: () => _openUser(u)));
      }
      for (var i = 0; i < trackList.length && i < 4; i++) {
        final t = trackList[i];
        widgets.add(_FlatTrackRow(track: t, onTap: () => _openTrack(t)));
      }
      for (var i = 0; i < playlistList.length && i < 3; i++) {
        final p = playlistList[i];
        widgets
            .add(_FlatPlaylistRow(playlist: p, onTap: () => _openPlaylist(p)));
      }
      for (final album in albumList) {
        widgets
            .add(_FlatAlbumRow(album: album, onTap: () => _openAlbum(album)));
      }
      for (var i = 4; i < trackList.length; i++) {
        final t = trackList[i];
        widgets.add(_FlatTrackRow(track: t, onTap: () => _openTrack(t)));
      }
    }

    if (widgets.isNotEmpty) {
      widgets.add(
          _ShowAllResultsRow(query: _ctrl.text.trim(), onTap: _openAllResults));
    }

    return widgets;
  }

  void _openAllResults() {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SearchResultsScreen(
          query: query,
          initialTracks: _tracks
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          initialArtists: _artists
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          initialAlbums: _albums
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          initialPlaylists: _playlists
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          initialUsers: _users
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      ),
    );
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

  void _openUser(Map<String, dynamic> user) {
    final rawId = user['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (userId == null) return;
    _saveUserHistory(user);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId, initialUser: user),
      ),
    );
  }

  Future<void> _openPlaylist(Map<String, dynamic> playlist) async {
    final playlistId = (playlist['id'] as num?)?.toInt() ??
        int.tryParse(playlist['id']?.toString() ?? '');
    if (playlistId == null || playlistId <= 0) return;
    await _savePlaylistHistory(playlist);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistId: playlistId,
          playlistTitle: playlist['title']?.toString(),
        ),
      ),
    );
  }

  Future<void> _openHistoryItem(Map<String, dynamic> item) async {
    final type = (item['result_type'] ?? '').toString().toLowerCase();
    final resultId = item['result_id']?.toString() ?? '';
    if (type == 'playlist') {
      final playlistId = int.tryParse(resultId);
      if (playlistId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistScreen(
              playlistId: playlistId,
              playlistTitle: item['result_title']?.toString(),
            ),
          ),
        );
        return;
      }
    } else if (type == 'profile' || type == 'user') {
      final userId = int.tryParse(resultId);
      if (userId != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        );
        return;
      }
    } else if (type == 'artist') {
      if (resultId.isNotEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistScreen(
              artistId: resultId,
              artistName: item['result_title']?.toString() ?? 'Artist',
            ),
          ),
        );
        return;
      }
    }
    _useHistoryItem(item);
  }

  List<Widget> _buildCategoryChips() {
    const labels = [
      'All',
      'Tracks',
      'Artists',
      'Albums',
      'Playlists',
      'Profiles'
    ];
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = _categoryIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _categoryIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.primaryBtn : null,
                  color: selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: selected ? Colors.transparent : AppColors.border),
                ),
                child: Text(
                  labels[i],
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.text2,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 8),
    ];
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
                                    _playlists = [];
                                    _users = [];
                                    _categoryIndex = 0;
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
              if (_hasQuery) ...[
                const SizedBox(height: 4),
                ..._buildCategoryChips(),
              ],
              if (_searching) ...[
                ..._buildSuggestions(),
                if (_suggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: AppColors.purpleLight,
                      minHeight: 2,
                    ),
                  ),
              ] else if (_hasQuery) ...[
                if (_tracks.isEmpty &&
                    _artists.isEmpty &&
                    _albums.isEmpty &&
                    _playlists.isEmpty &&
                    _users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: AppColors.text3),
                          const SizedBox(height: 12),
                          Text('No results found',
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                          Text('Try a different search',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.text3)),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: _buildUnifiedResults()),
                  ),
              ] else ...[
                if (_searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recently searched',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        Row(
                          children: [
                            if (_searchHistory.length > 4)
                              GestureDetector(
                                onTap: () => setState(
                                  () => _showAllHistory = !_showAllHistory,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: Text(
                                    _showAllHistory ? 'See less' : 'See all',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.purpleLight),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: _clearAllHistory,
                              child: Text('Clear all',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.purpleLight)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: (_showAllHistory
                              ? _searchHistory
                              : _searchHistory.take(4).toList())
                          .map((item) {
                        final itemId = item['id'] as int?;
                        final title = item['result_title']?.toString() ??
                            item['query']?.toString() ??
                            '';
                        final subtitle = () {
                          switch ((item['result_type'] ?? '').toString()) {
                            case 'playlist':
                              return 'playlist';
                            case 'profile':
                            case 'user':
                              return 'profile';
                            case 'artist':
                              return 'artist';
                            default:
                              return 'track';
                          }
                        }();
                        final coverUrl = item['result_cover']?.toString();
                        return GestureDetector(
                          onTap: () => _openHistoryItem(item),
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
                // ── Explore ──────────────────────────────────────────────
                const SizedBox(height: 20),
                const SectionHeader(title: 'Explore'),
                const SizedBox(height: 12),
                const ExploreSection(),
                // ── Browse Genres ─────────────────────────────────────────
                // ── Browse Genres ─────────────────────────────────────────
                const SizedBox(height: 24),
                const SectionHeader(title: 'Browse Genres'),
                const SizedBox(height: 12),
                const GenreSection(),
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
                          colors: [
                            Color(0xFF5B21B6),
                            Color(0xFF7C3AED),
                            Color(0xFFA855F7)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // Decorative music note circles
                          Positioned(
                            right: 70,
                            top: -10,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: -20,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          // Small playlist card (right side)
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withOpacity(0.18),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
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

              const SizedBox(height: 80),
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
                                        fontSize: 14, color: Colors.white70)),
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
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerScreen(track: first)));
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
                          const Text('🎵', style: TextStyle(fontSize: 48)),
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
                                        fontSize: 12, color: AppColors.text3)),
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

// ─── Spotify-style flat result rows ──────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionRow({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.text3),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style:
                      GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                ),
              ),
              const Icon(Icons.north_west_rounded,
                  size: 15, color: AppColors.text3),
            ],
          ),
        ),
      );
}

class _ShowAllResultsRow extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _ShowAllResultsRow({
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.04)),
            ),
          ),
          child: Text(
            'Show all results for "$query"',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsScreen extends StatefulWidget {
  final String query;
  final List<Map<String, dynamic>> initialTracks;
  final List<Map<String, dynamic>> initialArtists;
  final List<Map<String, dynamic>> initialAlbums;
  final List<Map<String, dynamic>> initialPlaylists;
  final List<Map<String, dynamic>> initialUsers;

  const _SearchResultsScreen({
    required this.query,
    required this.initialTracks,
    required this.initialArtists,
    required this.initialAlbums,
    this.initialPlaylists = const [],
    this.initialUsers = const [],
  });

  @override
  State<_SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<_SearchResultsScreen> {
  late List<Map<String, dynamic>> _tracks;
  late List<Map<String, dynamic>> _artists;
  late List<Map<String, dynamic>> _albums;
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tracks = widget.initialTracks;
    _artists = widget.initialArtists;
    _albums = widget.initialAlbums;
    _playlists = widget.initialPlaylists;
    _users = widget.initialUsers;
    _load();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .trim();
  }

  int _score(String query, String primary, {String secondary = ''}) {
    final q = _normalize(query);
    final p = _normalize(primary);
    final s = _normalize(secondary);
    if (q.isEmpty) return 0;
    var score = 0;
    if (p == q) score += 120;
    if (p.startsWith(q)) score += 70;
    if (p.contains(q)) score += 40;
    if (s == q) score += 30;
    if (s.startsWith(q)) score += 20;
    if (s.contains(q)) score += 10;
    return score;
  }

  Future<void> _load() async {
    try {
      final artistQuery = widget.query;
      final results = await Future.wait([
        ApiService().searchTracksWithFallback(widget.query, limit: 30),
        ApiService().searchArtistsList(artistQuery, limit: 20),
        ApiService().searchAlbums(widget.query, limit: 24),
        ApiService()
            .globalSearch(widget.query)
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;

      final tracks = (results[0] as List<Map<String, dynamic>>).toList()
        ..sort((a, b) => _score(
              widget.query,
              b['title']?.toString() ?? '',
              secondary: b['artist']?.toString() ?? '',
            ).compareTo(
              _score(
                widget.query,
                a['title']?.toString() ?? '',
                secondary: a['artist']?.toString() ?? '',
              ),
            ));
      final artists = (results[1] as List<Map<String, dynamic>>).toList()
        ..sort((a, b) =>
            _score(widget.query, b['name']?.toString() ?? '').compareTo(
              _score(widget.query, a['name']?.toString() ?? ''),
            ));
      final albums = (results[2] as List<Map<String, dynamic>>).toList()
        ..sort((a, b) => _score(
              widget.query,
              b['title']?.toString() ?? '',
              secondary: b['artist']?.toString() ?? '',
            ).compareTo(
              _score(
                widget.query,
                a['title']?.toString() ?? '',
                secondary: a['artist']?.toString() ?? '',
              ),
            ));
      final globalResult = results[3] as Map<String, dynamic>;
      final users = ((globalResult['users'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final playlists = ((globalResult['playlists'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => _score(
              widget.query,
              b['title']?.toString() ?? '',
              secondary: b['description']?.toString() ?? '',
            ).compareTo(
              _score(
                widget.query,
                a['title']?.toString() ?? '',
                secondary: a['description']?.toString() ?? '',
              ),
            ));

      setState(() {
        _tracks = tracks;
        _artists = artists;
        _albums = albums;
        _playlists = playlists;
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openTrack(Map<String, dynamic> track) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
  }

  void _openArtist(Map<String, dynamic> artist) {
    final artistId = artist['id']?.toString();
    if (artistId == null || artistId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId: artistId,
          artistName: artist['name']?.toString() ?? 'Unknown',
        ),
      ),
    );
  }

  void _openAlbum(Map<String, dynamic> album) {
    final albumId = int.tryParse(album['id'].toString()) ?? 0;
    if (albumId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumScreen(
          albumId: albumId,
          initialTitle: album['title']?.toString(),
          initialCover: album['cover_xl']?.toString(),
        ),
      ),
    );
  }

  void _openUser(Map<String, dynamic> user) {
    final rawId = user['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId, initialUser: user),
      ),
    );
  }

  void _openPlaylist(Map<String, dynamic> playlist) {
    final playlistId = (playlist['id'] as num?)?.toInt() ??
        int.tryParse(playlist['id']?.toString() ?? '');
    if (playlistId == null || playlistId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistId: playlistId,
          playlistTitle: playlist['title']?.toString(),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Results',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '"${widget.query}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: LinearProgressIndicator(
                          color: AppColors.purpleLight,
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      ),
                    if (_users.isNotEmpty) ...[
                      _sectionTitle('People'),
                      ..._users
                          .map((user) => _FlatUserRow(
                                user: user,
                                onTap: () => _openUser(user),
                              ))
                          .toList(),
                    ],
                    if (_artists.isNotEmpty) ...[
                      _sectionTitle('Artists'),
                      ..._artists
                          .map((artist) => _FlatArtistRow(
                                artist: artist,
                                onTap: () => _openArtist(artist),
                              ))
                          .toList(),
                    ],
                    if (_albums.isNotEmpty) ...[
                      _sectionTitle('Albums'),
                      ..._albums
                          .map((album) => _FlatAlbumRow(
                                album: album,
                                onTap: () => _openAlbum(album),
                              ))
                          .toList(),
                    ],
                    if (_playlists.isNotEmpty) ...[
                      _sectionTitle('Playlists'),
                      ..._playlists
                          .map((playlist) => _FlatPlaylistRow(
                                playlist: playlist,
                                onTap: () => _openPlaylist(playlist),
                              ))
                          .toList(),
                    ],
                    if (_tracks.isNotEmpty) ...[
                      _sectionTitle('Tracks'),
                      ..._tracks
                          .map((track) => _FlatTrackRow(
                                track: track,
                                onTap: () => _openTrack(track),
                              ))
                          .toList(),
                    ],
                    if (!_loading &&
                        _users.isEmpty &&
                        _artists.isEmpty &&
                        _albums.isEmpty &&
                        _playlists.isEmpty &&
                        _tracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No results found for "${widget.query}"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text2,
                            ),
                          ),
                        ),
                      ),
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

class _FlatArtistRow extends StatelessWidget {
  final Map<String, dynamic> artist;
  final VoidCallback onTap;
  const _FlatArtistRow({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = artist['name']?.toString() ?? '';
    final imageUrl =
        artist['picture_xl'] ?? artist['picture_medium'] ?? artist['image_url'];
    final fans = artist['nb_fan'];
    final fansNum =
        fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
    final sub = fansNum >= 1000000
        ? '${(fansNum / 1000000).toStringAsFixed(1)}M listeners'
        : fansNum >= 1000
            ? '${(fansNum / 1000).toStringAsFixed(0)}K listeners'
            : 'Artist';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppColors.gradPurple),
              child: imageUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white70)))
                  : const Icon(Icons.person_rounded, color: Colors.white70),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  Text(sub,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FlatAlbumRow extends StatelessWidget {
  final Map<String, dynamic> album;
  final VoidCallback onTap;
  const _FlatAlbumRow({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = album['title']?.toString() ?? 'Unknown';
    final artist = album['artist']?.toString() ?? '';
    final coverUrl = album['cover_xl']?.toString();
    final year = (album['release_date']?.toString() ?? '').split('-').first;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          width: 52, height: 52, color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: AppColors.surface,
                          child: const Icon(Icons.album_rounded,
                              color: AppColors.text3)))
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppColors.surface,
                      child: const Icon(Icons.album_rounded,
                          color: AppColors.text3)),
            ),
            const SizedBox(width: 14),
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
                  Text(
                      [if (artist.isNotEmpty) artist, if (year.isNotEmpty) year]
                          .join(' · '),
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            Text('Album',
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }
}

class _FlatPlaylistRow extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback onTap;
  const _FlatPlaylistRow({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = playlist['title']?.toString() ?? 'Playlist';
    final subtitle =
        (playlist['description']?.toString().trim().isNotEmpty == true)
            ? playlist['description'].toString()
            : '${playlist['track_count'] ?? 0} songs';
    final coverUrl = playlist['cover_url']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.surface,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.surface,
                        child: const Icon(Icons.queue_music_rounded,
                            color: AppColors.text3),
                      ),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppColors.surface,
                      child: const Icon(Icons.queue_music_rounded,
                          color: AppColors.text3),
                    ),
            ),
            const SizedBox(width: 14),
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
                  Text(
                    subtitle,
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
              'Playlist',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatTrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback onTap;
  const _FlatTrackRow({required this.track, required this.onTap});

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
    final dur = _fmt(track['duration_ms'] ?? track['trackTimeMillis'] ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl.toString(),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          width: 52, height: 52, color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: AppColors.surface,
                          child: const Icon(Icons.music_note_rounded,
                              color: AppColors.text3)))
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppColors.surface,
                      child: const Icon(Icons.music_note_rounded,
                          color: AppColors.text3)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  Text(
                      [
                        artist.toString(),
                        if (dur.isNotEmpty) dur,
                      ].join(' · '),
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showTrackMenu(
                context,
                track,
                onPlayNow: onTap,
                onGoToArtist: () async {
                  final artistName =
                      (track['artist'] ?? track['artistName'] ?? '').toString();
                  final directId = track['artist_id']?.toString();
                  if (directId != null &&
                      directId.isNotEmpty &&
                      context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArtistScreen(
                          artistId: directId, artistName: artistName),
                    ));
                    return;
                  }
                  if (artistName.isEmpty) return;
                  final candidates = await ApiService()
                      .searchArtistsList(artistName, limit: 6);
                  if (!context.mounted || candidates.isEmpty) return;
                  final artistId = candidates.first['id']?.toString();
                  if (artistId == null || artistId.isEmpty || !context.mounted)
                    return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArtistScreen(
                      artistId: artistId,
                      artistName:
                          candidates.first['name']?.toString() ?? artistName,
                    ),
                  ));
                },
              ),
              child: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatUserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _FlatUserRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (user['display_name'] ??
            user['first_name'] ??
            user['username'] ??
            'User')
        .toString();
    final username = (user['username'] ?? '').toString();
    final avatarUrl = (user['avatar_url'] ?? '').toString();
    final city = (user['city'] ?? '').toString();
    final sub = city.isNotEmpty
        ? city
        : (username.isNotEmpty ? '@$username' : 'Profile');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradMixed,
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
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
                          fontSize: 18,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.text3,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}