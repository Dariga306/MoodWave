import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/media_url.dart';
import '../../widgets/common_widgets.dart';
import 'package:moodwave/widgets/mini_player.dart';
import '../album_screen.dart';
import '../artist_screen.dart';
import '../city_charts_screen.dart';
import '../discover_screen.dart';
import '../extra_screens.dart' hide DiscoverScreen, CityChartsScreen;
import '../mood_screen.dart';
import '../mood_tracks_screen.dart';
import '../notifications_screen.dart';
import '../player_screen.dart';
import '../playlist_screen.dart';
import '../profile_tab_screen.dart';
import '../social_activity_screen.dart';
import '../user_profile_screen.dart';
import '../weather_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _weather;
  Map<String, dynamic> _friendsActivity = {};
  List<dynamic> _charts = [];
  List<dynamic> _recentlyPlayed = [];
  List<dynamic> _freshWave = [];
  List<dynamic> _followedArtists = [];
  List<dynamic> _liveRooms = [];
  List<dynamic> _becauseYouListened = [];
  List<dynamic> _discoverGlobal = [];
  List<dynamic> _discoverViral = [];
  List<dynamic> _discoverRising = [];
  List<Map<String, dynamic>> _aiMixes = [];
  List<Map<String, dynamic>> _mixedRecommendations = [];
  List<Map<String, dynamic>> _thisIsArtists = [];
  List<dynamic> _radioStations = [];
  List<dynamic> _hotRightNow = [];
  bool _loading = true;
  bool _playingWeather = false;
  bool _chartsAreCityData = false;
  int _unreadNotifCount = 0;
  String _discoverCity = '';

  PlayerProvider? _playerProvider;
  String? _lastKnownTrackId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<PlayerProvider>();
    if (_playerProvider != player) {
      _playerProvider?.removeListener(_onPlayerChanged);
      _playerProvider = player;
      player.addListener(_onPlayerChanged);
    }
  }

  @override
  void dispose() {
    _playerProvider?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    final track = _playerProvider?.track;
    if (track == null) return;
    final id =
        (track['spotify_id'] ?? track['track_id'] ?? '').toString().trim();
    final title =
        (track['title'] ?? track['trackName'] ?? '').toString().trim();
    final artist =
        (track['artist'] ?? track['artistName'] ?? '').toString().trim();
    final compositeId = id.isNotEmpty ? id : '$title|$artist';
    if (compositeId.isEmpty || compositeId == '|') return;
    if (_lastKnownTrackId == compositeId) return;
    _lastKnownTrackId = compositeId;
    if (!mounted) return;
    setState(() {
      _recentlyPlayed = [
        Map<String, dynamic>.from(track),
        ..._recentlyPlayed,
      ];
    });
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    final city = user?['city'] ?? 'Astana';
    final api = ApiService();
    try {
      // Phase 1: critical content — show page as soon as this completes
      final phase1 = await Future.wait([
        api.getWeather(city).catchError((_) => <String, dynamic>{}), // 0
        api.getChartsByCity(city).catchError((_) =>
            <String, dynamic>{'tracks': <dynamic>[], 'source': 'global'}), // 1
        api.getRecentlyPlayed(limit: 20).catchError((_) => <dynamic>[]), // 2
        api.getDiscover(city: city).catchError((_) => <String, dynamic>{}), // 3
        api.getActiveRooms(limit: 5).catchError((_) => <dynamic>[]), // 4
        api
            .getTrendingTracks(city: city, limit: 10)
            .catchError((_) => <dynamic>[]), // 5
        api.getFriendsActivity().catchError((_) => <String, dynamic>{}), // 6
      ]);
      if (!mounted) return;

      final cityChartsData = phase1[1] as Map<String, dynamic>?;
      final cityCharts = (cityChartsData?['tracks'] as List?) ?? [];
      final cityChartsSource =
          (cityChartsData?['source'] as String?) ?? 'global';
      final discoverData = phase1[3] is Map
          ? Map<String, dynamic>.from(phase1[3] as Map)
          : <String, dynamic>{};
      final globalCharts = (discoverData['global_top'] as List?) ?? [];
      final discoverViral = (discoverData['viral'] as List?) ?? [];
      final discoverNew = (discoverData['new_releases'] as List?) ?? [];
      final discoverRising = (discoverData['rising'] as List?) ?? [];
      final recently = (phase1[2] as List?) ?? [];
      final trendingTracks = (phase1[5] as List?) ?? [];

      setState(() {
        _weather = phase1[0] as Map<String, dynamic>?;
        _charts = cityCharts.isNotEmpty ? cityCharts : globalCharts;
        _chartsAreCityData =
            cityCharts.isNotEmpty && cityChartsSource == 'city';
        _recentlyPlayed = recently;
        _freshWave = discoverNew.isNotEmpty ? discoverNew : globalCharts;
        _discoverGlobal = globalCharts;
        _discoverViral = discoverViral;
        _discoverRising = discoverRising;
        _discoverCity =
            (discoverData['city']?.toString().trim().isNotEmpty ?? false)
                ? discoverData['city'].toString().trim()
                : city.toString();
        _liveRooms = (phase1[4] as List?) ?? [];
        _hotRightNow =
            discoverViral.isNotEmpty ? discoverViral : trendingTracks;
        _friendsActivity = Map<String, dynamic>.from(phase1[6] as Map);
        _loading = false;
      });

      // Phase 2: enrichment — load in background, update UI when ready
      _loadEnrichment(api, recently, globalCharts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadEnrichment(ApiService api, List<dynamic> recently,
      List<dynamic> globalCharts) async {
    try {
      final phase2 = await Future.wait([
        api.getFollowedArtistsDetails().catchError((_) => <dynamic>[]), // 0
        api.getRadioStations().catchError((_) => <dynamic>[]), // 1
        api.getHomeFeed().catchError((_) => <String, dynamic>{}), // 2
        api.getLikedAlbums().catchError((_) => <Map<String, dynamic>>[]), // 3
        api.getPlaylists().catchError((_) => <dynamic>[]), // 4
        api.getRecommendations().catchError((_) => <dynamic>[]), // 5
        api.getGenreMixes().catchError((_) => <Map<String, dynamic>>[]), // 6
      ]);
      if (!mounted) return;

      final followedRaw = (phase2[0] as List?) ?? [];
      final feedRaw = phase2[2];
      final feed = feedRaw is Map
          ? Map<String, dynamic>.from(feedRaw)
          : <String, dynamic>{};
      final feedArtistsRaw = (feed['you_might_like'] as List?) ?? [];
      final likedAlbums = (phase2[3] as List?) ?? [];
      final playlists = (phase2[4] as List?) ?? [];
      final recommendations = (phase2[5] as List?) ?? [];
      final genreMixes = (phase2[6] as List?) ?? [];

      final artistGroups = await Future.wait([
        api
            .hydrateArtists(followedRaw)
            .catchError((_) => <Map<String, dynamic>>[]),
        api
            .hydrateArtists(feedArtistsRaw)
            .catchError((_) => <Map<String, dynamic>>[]),
        api.hydrateArtists(const [
          {'id': 1424821, 'name': 'Lana Del Rey'},
          {'id': 15356779, 'name': 'МЭЙБИ БЭЙБИ'},
          {'id': 288166, 'name': 'Justin Bieber'},
          {'id': 4050205, 'name': 'The Weeknd'},
        ]).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;

      final followed = artistGroups[0];
      final feedArtists = [...artistGroups[1], ...artistGroups[2]];
      final mixed = _buildMixedRecommendations(
        artists: [...followed, ...feedArtists],
        albums: likedAlbums,
        playlists: playlists,
      );
      final thisIs = _buildThisIsArtists(followed, feedArtists);
      final aiMixes = _buildAiMixes(
        mixes: genreMixes,
        fallbackTracks: [...recommendations, ...globalCharts],
      );
      final because = await _loadBecauseYouListened(api, recently, [
        ...recommendations,
        ...globalCharts,
        ...recently,
      ]);
      if (!mounted) return;

      setState(() {
        _followedArtists = followed;
        _radioStations = (phase2[1] as List?) ?? [];
        _becauseYouListened = because;
        _aiMixes = aiMixes;
        _mixedRecommendations = mixed;
        _thisIsArtists = thisIs;
      });

      // Notifications last — least critical
      final unreadCount = await api
          .getNotifications()
          .then((d) => (d['notifications'] as List? ?? []).length)
          .catchError((_) => 0);
      if (!mounted) return;
      setState(() => _unreadNotifCount = unreadCount);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _buildMixedRecommendations({
    required List<dynamic> artists,
    required List<dynamic> albums,
    required List<dynamic> playlists,
  }) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addItem(String type, Map<String, dynamic> item, String key) {
      if (seen.contains(key)) return;
      seen.add(key);
      items.add({'type': type, 'data': item});
    }

    final filteredArtists = artists
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((artist) => _isUsableArtistRecommendation(artist))
        .toList();

    final filteredAlbums = albums
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((album) => _isUsableAlbumRecommendation(album))
        .toList();

    final filteredPlaylists = playlists
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((playlist) => _isUsablePlaylistRecommendation(playlist))
        .toList();

    for (final artist in filteredArtists) {
      final key = 'artist:${_normalizedText(_entityName(artist))}';
      if (key.isNotEmpty) addItem('artist', artist, key);
    }

    for (final album in filteredAlbums) {
      final key =
          'album:${_normalizedText(_entityTitle(album))}|${_normalizedText(_entityArtist(album))}';
      if (key.isNotEmpty) addItem('album', album, key);
    }

    for (final playlist in filteredPlaylists) {
      final key = 'playlist:${_normalizedText(_entityTitle(playlist))}';
      if (key.isNotEmpty) addItem('playlist', playlist, key);
    }

    return items;
  }

  List<Map<String, dynamic>> _buildThisIsArtists(
      List<dynamic> followed, List<dynamic> suggested) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addArtist(Map<String, dynamic> artist) {
      if (!_isUsableArtistRecommendation(artist)) return;
      final key = _normalizedText(_entityName(artist));
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      items.add(artist);
    }

    final filteredFollowed = followed
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((artist) => _isUsableArtistRecommendation(artist))
        .toList();

    final filteredSuggested = suggested
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((artist) => _isUsableArtistRecommendation(artist))
        .toList();

    for (final artist in filteredFollowed) {
      addArtist(artist);
    }

    for (final artist in filteredSuggested) {
      addArtist(artist);
    }

    return items.take(10).toList();
  }

  List<Map<String, dynamic>> _buildAiMixes({
    required List<dynamic> mixes,
    required List<dynamic> fallbackTracks,
  }) {
    final normalized = mixes
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['tracks'] as List?)?.isNotEmpty == true)
        .toList();
    if (normalized.isNotEmpty) return normalized.take(8).toList();

    final tracks = fallbackTracks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (tracks.isEmpty) return [];

    List<Map<String, dynamic>> slice(int start) {
      final rotated = [
        ...tracks.skip(start % tracks.length),
        ...tracks.take(start % tracks.length),
      ];
      return rotated.take(12).toList();
    }

    final cover = (Map<String, dynamic> track) =>
        (track['cover_url'] ?? track['artworkUrl100'])?.toString();

    final definitions = [
      ['For You AI Mix', 'Built from your recent taste', '✨', 0],
      ['Late Night AI Mix', 'Soft tracks for night listening', '🌙', 3],
      ['Energy AI Mix', 'Faster picks when you need motion', '⚡', 6],
      ['Fresh Discovery AI Mix', 'New picks MoodWave thinks fit you', '🌊', 9],
    ];

    return definitions.map((def) {
      final mixTracks = slice(def[3] as int);
      return {
        'id': (def[0] as String).toLowerCase().replaceAll(' ', '_'),
        'title': def[0],
        'subtitle': def[1],
        'emoji': def[2],
        'cover_url': mixTracks.isNotEmpty ? cover(mixTracks.first) : null,
        'tracks': mixTracks,
      };
    }).toList();
  }

  Future<List<dynamic>> _loadBecauseYouListened(
    ApiService api,
    List<dynamic> recently,
    List<dynamic> fallback,
  ) async {
    if (recently.isEmpty) return fallback.take(12).toList();
    final seed = recently.first;
    if (seed is! Map) return fallback.take(12).toList();
    final artist = _entityArtist(Map<String, dynamic>.from(seed));
    final title = _entityTitle(Map<String, dynamic>.from(seed));
    final queries = <String>{
      if (artist.isNotEmpty && title.isNotEmpty) '$artist $title',
      if (artist.isNotEmpty) artist,
      if (title.isNotEmpty) title,
    }.where((query) => query.trim().isNotEmpty).toList();
    if (queries.isEmpty) {
      return _finalizeBecauseTracks(
        fallback
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        seedArtist: artist,
        seedTitle: title,
      );
    }
    try {
      final searchResults = await Future.wait(
        queries.map(
          (query) => api
              .searchTracksWithFallback(query, limit: 18)
              .catchError((_) => <Map<String, dynamic>>[]),
        ),
      );
      final fromSearch = <Map<String, dynamic>>[
        for (final batch in searchResults)
          ...batch
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
      ];
      // Only use global fallback if search returned nothing
      final candidates = fromSearch.isNotEmpty
          ? fromSearch
          : fallback
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      return _finalizeBecauseTracks(
        candidates,
        seedArtist: artist,
        seedTitle: title,
      );
    } catch (_) {
      return _finalizeBecauseTracks(
        fallback
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        seedArtist: artist,
        seedTitle: title,
      );
    }
  }

  List<dynamic> _finalizeBecauseTracks(
    List<Map<String, dynamic>> candidates, {
    required String seedArtist,
    required String seedTitle,
  }) {
    final cleaned = _dedupeTracks(
      candidates.where(_isUsableTrackRecommendation).toList(),
      onePerAlbum: true,
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

    final seedArtistKey = _normalizedText(seedArtist);
    final seedTitleKey = _normalizedText(seedTitle);
    final sameArtist = <Map<String, dynamic>>[];
    final adjacent = <Map<String, dynamic>>[];

    for (final track in cleaned) {
      final trackTitle = _normalizedText(_entityTitle(track));
      final trackArtist = _normalizedText(_entityArtist(track));
      if (trackTitle == seedTitleKey && trackArtist == seedArtistKey) continue;
      if (trackArtist == seedArtistKey) {
        sameArtist.add(track);
      } else {
        adjacent.add(track);
      }
    }

    final result = <Map<String, dynamic>>[];
    final artistCounts = <String, int>{};

    void tryAdd(Map<String, dynamic> track) {
      if (result.length >= 12) return;
      final artistKey = _normalizedText(_entityArtist(track));
      if (artistKey.isEmpty) return;
      final nextCount = (artistCounts[artistKey] ?? 0) + 1;
      if (nextCount > (artistKey == seedArtistKey ? 3 : 2)) return;
      artistCounts[artistKey] = nextCount;
      result.add(track);
    }

    var sameIndex = 0;
    var adjacentIndex = 0;
    while (result.length < 12 &&
        (sameIndex < sameArtist.length || adjacentIndex < adjacent.length)) {
      if (sameIndex < sameArtist.length) {
        tryAdd(sameArtist[sameIndex++]);
      }
      for (var i = 0; i < 2 && adjacentIndex < adjacent.length; i++) {
        tryAdd(adjacent[adjacentIndex++]);
      }
    }

    return result;
  }

  String _normalizedText(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _entityName(Map<String, dynamic> item) => (item['name'] ??
          item['display_name'] ??
          item['username'] ??
          item['artist'] ??
          '')
      .toString()
      .trim();

  String _entityTitle(Map<String, dynamic> item) => (item['title'] ??
          item['trackName'] ??
          item['album_name'] ??
          item['collectionName'] ??
          '')
      .toString()
      .trim();

  String _entityArtist(Map<String, dynamic> item) =>
      (item['artist'] ?? item['artistName'] ?? item['artist_name'] ?? '')
          .toString()
          .trim();

  String _artistImage(Map<String, dynamic> item) => (item['picture_xl'] ??
          item['picture_big'] ??
          item['picture_medium'] ??
          item['photo_url'] ??
          item['image_url'] ??
          item['avatar_url'] ??
          item['cover_url'] ??
          '')
      .toString()
      .trim();

  String _albumImage(Map<String, dynamic> item) => (item['cover_url'] ??
          item['artworkUrl100'] ??
          item['cover_xl'] ??
          item['image_url'] ??
          item['picture_xl'] ??
          item['picture_big'] ??
          item['picture_medium'] ??
          '')
      .toString()
      .trim();

  bool _hasUsableImage(String value) {
    final url = value.trim().toLowerCase();
    if (url.isEmpty) return false;
    if (url.contains('placeholder')) return false;
    if (url.contains('/default')) return false;
    if (url.endsWith('/null') || url.endsWith('null')) return false;
    // Deezer empty artist/album image — no ID segment (double-slash)
    if (url.contains('/images/artist//')) return false;
    if (url.contains('/images/album//')) return false;
    if (url.contains('/images/misc//')) return false;
    // Generic empty-ID pattern: path segment is empty between two slashes
    if (RegExp(r'/[a-z]+//\d+x\d+').hasMatch(url)) return false;
    return true;
  }

  bool _looksLikeNoiseEntity(String value) {
    final text = _normalizedText(value);
    if (text.isEmpty) return true;
    const blockedFragments = [
      'karaoke',
      'cover band',
      'covers',
      'piano covers',
      'tribute',
      'instrumental version',
      'feat.',
      'featuring',
    ];
    if (blockedFragments.any(text.contains)) return true;
    return false;
  }

  bool _looksLikeCollabArtist(String value) {
    final t = value.trim();
    if (t.isEmpty) return false;
    // Russian conjunction between two names: "Артист и Артист"
    if (RegExp(r'\s+и\s+', caseSensitive: false).hasMatch(t)) return true;
    // English collab patterns with "&" or "vs"
    if (RegExp(r'\s+vs\.?\s+', caseSensitive: false).hasMatch(t)) return true;
    // Comma-separated multi-artist: "Artist A, Artist B"
    // (exclude "Jr." style abbreviated names and single-word-after-comma)
    final commaIdx = t.indexOf(', ');
    if (commaIdx > 0) {
      final afterComma = t.substring(commaIdx + 2).trim();
      // if what follows comma is a capitalized word-or-more, it's a second artist
      if (afterComma.isNotEmpty &&
          afterComma[0] == afterComma[0].toUpperCase() &&
          afterComma.length > 2 &&
          !afterComma.startsWith('Jr') &&
          !afterComma.startsWith('Sr') &&
          !afterComma.startsWith('III')) {
        return true;
      }
    }
    return false;
  }

  bool _isUsableArtistRecommendation(Map<String, dynamic> item) {
    final name = _entityName(item);
    final image = _artistImage(item);
    return name.isNotEmpty &&
        !_looksLikeNoiseEntity(name) &&
        !_looksLikeCollabArtist(name) &&
        _hasUsableImage(image);
  }

  bool _isUsableAlbumRecommendation(Map<String, dynamic> item) {
    final title = _entityTitle(item);
    final artist = _entityArtist(item);
    final image = _albumImage(item);
    return title.isNotEmpty &&
        artist.isNotEmpty &&
        _hasUsableImage(image) &&
        !_looksLikeNoiseEntity(artist);
  }

  bool _isUsableTrackRecommendation(Map<String, dynamic> item) {
    final title = _entityTitle(item);
    final artist = _entityArtist(item);
    final image = _albumImage(item);
    return title.isNotEmpty &&
        artist.isNotEmpty &&
        _hasUsableImage(image) &&
        !_looksLikeNoiseEntity(artist);
  }

  bool _isUsablePlaylistRecommendation(Map<String, dynamic> item) {
    final title = _entityTitle(item);
    return title.isNotEmpty && !_looksLikeNoiseEntity(title);
  }

  String _becauseTitle() {
    if (_recentlyPlayed.isEmpty || _recentlyPlayed.first is! Map) {
      return 'Because you listened to...';
    }
    final first = _recentlyPlayed.first as Map;
    final title = (first['title'] ?? first['trackName'] ?? '').toString();
    if (title.isEmpty) return 'Because you listened to...';
    return 'Because you listened to $title';
  }

  String get _becauseSeedArtist {
    if (_recentlyPlayed.isEmpty || _recentlyPlayed.first is! Map) return '';
    final first = _recentlyPlayed.first as Map;
    return (first['artist'] ?? first['artistName'] ?? '').toString().trim();
  }

  List<dynamic> get _recentlyPlayedForHome {
    final seen = <String>{};
    final seenAlbums = <String>{};
    final deduped = <dynamic>[];
    for (final raw in _recentlyPlayed) {
      if (raw is! Map) continue;
      final track = Map<String, dynamic>.from(raw);
      final spotifyId =
          (track['spotify_id'] ?? track['track_id'] ?? '').toString().trim();
      final title = (track['title'] ?? track['trackName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final artist = (track['artist'] ?? track['artistName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final key = spotifyId.isNotEmpty ? spotifyId : '$title|$artist';
      if (key.isEmpty || key == '|') continue;
      if (!seen.add(key)) continue;
      final albumKey = _albumDedupeKey(track);
      if (albumKey.isNotEmpty && !seenAlbums.add(albumKey)) continue;
      deduped.add(track);
    }
    return deduped;
  }

  String _trackDedupeKey(Map<String, dynamic> track) {
    final spotifyId =
        (track['spotify_id'] ?? track['track_id'] ?? '').toString().trim();
    if (spotifyId.isNotEmpty) return 'id:$spotifyId';
    final title = (track['title'] ?? track['trackName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final artist = (track['artist'] ?? track['artistName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return '$title|$artist';
  }

  String _albumDedupeKey(Map<String, dynamic> track) {
    final albumId =
        (track['album_id'] ?? track['collectionId'] ?? '').toString().trim();
    if (albumId.isNotEmpty) return 'album:$albumId';
    final album =
        (track['album'] ?? track['album_name'] ?? track['collectionName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final artist = (track['artist'] ?? track['artistName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (album.isNotEmpty) return 'album:$album|$artist';
    final cover =
        (track['cover_url'] ?? track['artworkUrl100'] ?? '').toString().trim();
    return cover.isNotEmpty ? 'cover:$cover' : '';
  }

  List<dynamic> _dedupeTracks(List<dynamic> tracks,
      {bool onePerAlbum = false}) {
    final seen = <String>{};
    final seenAlbums = <String>{};
    final result = <dynamic>[];
    for (final raw in tracks) {
      if (raw is! Map) continue;
      final track = Map<String, dynamic>.from(raw);
      final key = _trackDedupeKey(track);
      if (key.isEmpty || key == '|') continue;
      if (!seen.add(key)) continue;
      if (onePerAlbum) {
        final albumKey = _albumDedupeKey(track);
        if (albumKey.isNotEmpty && !seenAlbums.add(albumKey)) continue;
      }
      result.add(track);
    }
    return result;
  }

  List<Map<String, dynamic>> get _friendItems {
    final live = (_friendsActivity['live'] as List? ?? const [])
        .whereType<Map>()
        .map((item) =>
            Map<String, dynamic>.from(item)..['activity_status'] = 'live');
    final recent = (_friendsActivity['recent'] as List? ?? const [])
        .whereType<Map>()
        .map((item) =>
            Map<String, dynamic>.from(item)..['activity_status'] = 'recent');
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final item in [...live, ...recent]) {
      final id =
          (item['id'] ?? item['username'] ?? item['display_name']).toString();
      final now = (item['now_playing'] as Map?)?.cast<String, dynamic>();
      final title = (now?['title'] ?? now?['track_title'] ?? '').toString();
      if (id.isEmpty || seen.contains(id)) continue;
      if (title.trim().isEmpty) continue;
      seen.add(id);
      merged.add(item);
    }
    return merged;
  }

  String _getWeatherEmoji(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('snow')) return '❄️';
    if (d.contains('rain') || d.contains('drizzle')) return '🌧';
    if (d.contains('cloud')) return '☁️';
    if (d.contains('thunder') || d.contains('storm')) return '⛈';
    if (d.contains('clear') || d.contains('sunny')) return '☀️';
    if (d.contains('fog') || d.contains('mist')) return '🌫';
    return '🌤';
  }

  IconData _weatherIconData(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('snow')) return Icons.ac_unit_rounded;
    if (d.contains('rain') || d.contains('drizzle')) {
      return Icons.grain_rounded;
    }
    if (d.contains('partly') || d.contains('few') || d.contains('scattered')) {
      return Icons.wb_cloudy_rounded;
    }
    if (d.contains('cloud')) return Icons.cloud_rounded;
    if (d.contains('thunder') || d.contains('storm')) {
      return Icons.thunderstorm_rounded;
    }
    if (d.contains('clear') || d.contains('sunny')) {
      return Icons.wb_sunny_rounded;
    }
    if (d.contains('fog') || d.contains('mist') || d.contains('haze')) {
      return Icons.blur_on_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  List<Color> _weatherCardGradient(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('clear') || d.contains('sunny')) {
      return const [
        Color(0xFF1B3655),
        Color(0xFF315D7D),
        Color(0xFF5A87A8),
      ];
    }
    if (d.contains('partly') || d.contains('few') || d.contains('scattered')) {
      return const [
        Color(0xFF26384F),
        Color(0xFF49627B),
        Color(0xFF7890A8),
      ];
    }
    if (d.contains('cloud')) {
      return const [
        Color(0xFF273244),
        Color(0xFF475569),
        Color(0xFF75849A),
      ];
    }
    if (d.contains('rain') || d.contains('drizzle')) {
      return const [
        Color(0xFF0C1B2A),
        Color(0xFF17314D),
        Color(0xFF215A8A),
      ];
    }
    if (d.contains('snow')) {
      return const [
        Color(0xFF1B2538),
        Color(0xFF3A4C68),
        Color(0xFF7C96B8),
      ];
    }
    if (d.contains('thunder') || d.contains('storm')) {
      return const [
        Color(0xFF131420),
        Color(0xFF2A2248),
        Color(0xFF4B3C82),
      ];
    }
    if (d.contains('fog') || d.contains('mist') || d.contains('haze')) {
      return const [
        Color(0xFF1A2430),
        Color(0xFF2A3946),
        Color(0xFF506473),
      ];
    }
    return const [
      Color(0xFF0D1A3D),
      Color(0xFF1A1060),
      Color(0xFF0D2040),
    ];
  }

  Color _weatherAccent(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('clear') || d.contains('sunny')) {
      return const Color(0xFFF8D66D);
    }
    if (d.contains('partly') || d.contains('few') || d.contains('scattered')) {
      return const Color(0xFFE9C46A);
    }
    if (d.contains('cloud')) return const Color(0xFFB9D6FF);
    if (d.contains('rain') || d.contains('drizzle')) {
      return const Color(0xFF7CC6FF);
    }
    if (d.contains('snow')) return const Color(0xFFE6F2FF);
    if (d.contains('thunder') || d.contains('storm')) {
      return const Color(0xFFC7B4FF);
    }
    if (d.contains('fog') || d.contains('mist') || d.contains('haze')) {
      return const Color(0xFFD5E2F0);
    }
    return const Color(0xFF93C5FD);
  }

  String _weatherListenersLabel(int count, String city) {
    if (count <= 0) return 'No one listening now';
    if (count == 1) return '1 person listening now';
    return '$count people listening now';
  }

  String _weatherMood(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('rain') || d.contains('drizzle')) return 'rainy';
    if (d.contains('snow')) return 'calm';
    if (d.contains('thunder') || d.contains('storm')) return 'stormy';
    if (d.contains('clear') || d.contains('sunny')) return 'sunny';
    if (d.contains('cloud')) return 'cloudy';
    if (d.contains('fog') || d.contains('mist')) return 'foggy';
    return 'chill';
  }

  Future<void> _playWeatherVibes() async {
    if (_playingWeather) return;
    final user = context.read<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    final desc =
        (_weather?['description'] ?? _weather?['condition'] ?? '').toString();
    setState(() => _playingWeather = true);
    try {
      final mood = _weatherMood(desc);
      final tracks = await ApiService().getRecommendations(mood: mood);
      if (!mounted) return;
      final queue = tracks
          .whereType<Map>()
          .map((track) => Map<String, dynamic>.from(track))
          .toList();
      if (queue.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeatherScreen()),
        );
        return;
      }
      final first = Map<String, dynamic>.from(queue.first)
        ..['queue'] = queue
        ..['source'] = '$city weather vibes';
      MiniPlayerOverlayController.forceVisible();
      MiniPlayerOverlayController.setBottomOffset(74);
      await context.read<PlayerProvider>().openTrack(first);
      MiniPlayerOverlayController.forceVisible();
      MiniPlayerOverlayController.setBottomOffset(74);
    } finally {
      if (mounted) setState(() => _playingWeather = false);
    }
  }

  void _openMoodExplore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MoodScreen(weather: _weather)),
    );
  }

  void _openMood(MoodData mood) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoodTracksScreen(mood: mood),
      ),
    );
  }

  List<Widget> _buildMoodSection() {
    final recommendedKey = getRecommendedMoodKey(_weather);
    final orderedMoods = [
      ...allMoods.where((m) => m.key == recommendedKey),
      ...allMoods.where((m) => m.key != recommendedKey),
    ];
    return [
      const SizedBox(height: 22),
      SectionHeader(
        title: 'Choose Your Mood',
        action: 'See all →',
        onAction: _openMoodExplore,
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 176,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          itemCount: orderedMoods.length,
          itemBuilder: (context, index) {
            final mood = orderedMoods[index];
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _MoodTile(
                mood: mood,
                onTap: () => _openMood(mood),
              ),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final city = user?['city'] ?? 'Astana';
    final displayName = user?['display_name'] ?? user?['username'] ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final weatherDisplayDesc =
        (_weather?['description'] ?? _weather?['condition'] ?? 'Clear')
            .toString();
    final weatherDesc = '${_weather?['condition'] ?? ''} $weatherDisplayDesc';
    final weatherTemp = _weather?['temperature'] ?? _weather?['temp'];
    final weatherIcon = _weatherIconData(weatherDesc);
    final weatherGradient = _weatherCardGradient(weatherDesc);
    final weatherAccent = _weatherAccent(weatherDesc);
    final listenersCount = (_weather?['listeners_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xE61a063d), Colors.transparent]),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [AppColors.purpleLight, AppColors.pink],
                              ).createShader(b),
                              child: Text('MoodWave',
                                  style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationsScreen()));
                            if (mounted) setState(() => _unreadNotifCount = 0);
                          },
                          child: Stack(clipBehavior: Clip.none, children: [
                            const AppIconButton(
                                icon: Icons.notifications_outlined),
                            if (_unreadNotifCount > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  constraints: const BoxConstraints(
                                      minWidth: 17, minHeight: 17),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _unreadNotifCount > 99
                                          ? '99+'
                                          : '$_unreadNotifCount',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ])),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileTabScreen()),
                        ),
                        child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.border2, width: 2)),
                            child: Center(
                                child: Text(initial,
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)))),
                      ),
                    ]),
                  ),
                ),
              ),

              // ─── Weather ───────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WeatherScreen())),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: weatherGradient,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: weatherAccent.withOpacity(0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: weatherGradient.last.withOpacity(0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -12,
                          top: -10,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: weatherAccent.withOpacity(0.10),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 18,
                          top: 18,
                          child: Icon(
                            weatherIcon,
                            size: 42,
                            color: weatherAccent.withOpacity(0.9),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.12))),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            weatherIcon,
                                            size: 13,
                                            color: weatherAccent,
                                          ),
                                          const SizedBox(width: 5),
                                          Text('Live Weather',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: weatherAccent,
                                                  letterSpacing: 0.05)),
                                        ],
                                      )),
                                  const SizedBox(height: 10),
                                  Text(
                                      weatherTemp != null
                                          ? '${weatherTemp.toStringAsFixed(0)}°'
                                          : '—°',
                                      style: GoogleFonts.outfit(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1)),
                                  const SizedBox(height: 2),
                                  Text('$weatherDisplayDesc · $city',
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color:
                                              Colors.white.withOpacity(0.78))),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF22C55E),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF22C55E)
                                                  .withOpacity(0.4),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                            _weatherListenersLabel(
                                                listenersCount, city),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withOpacity(0.62))),
                                      ),
                                    ],
                                  ),
                                ])),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _playWeatherVibes,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.14))),
                                  child: _playingWeather
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: weatherAccent),
                                        )
                                      : Text('Play Vibes',
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white))),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Recently Played ───────────────────────────────
              if (_recentlyPlayedForHome.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Recently Played',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecentHistoryScreen())),
                ),
                const SizedBox(height: 12),
                _RecentHorizontal(
                  tracks: _recentlyPlayedForHome.take(10).toList(),
                ),
              ],

              // ─── You Might Like ───────────────────────────────
              if (_mixedRecommendations.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'You Might Like',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _YouMightLikeScreen(
                        items: _mixedRecommendations,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 138,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _mixedRecommendations.length.clamp(0, 14),
                    itemBuilder: (ctx, i) {
                      return _RecommendationCard(
                          item: _mixedRecommendations[i]);
                    },
                  ),
                ),
              ],

              // ─── Because you listened to ───────────────────────
              if (_becauseYouListened.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: _becauseTitle(),
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _BecauseYouListenedScreen(
                        title: _becauseTitle(),
                        tracks: _becauseYouListened
                            .whereType<Map>()
                            .map((t) => Map<String, dynamic>.from(t))
                            .toList(),
                        seedArtist: _becauseSeedArtist,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _becauseYouListened.length.clamp(0, 12),
                    itemBuilder: (context, i) {
                      final track =
                          _becauseYouListened[i] as Map<String, dynamic>;
                      return _TrackCard(track: track);
                    },
                  ),
                ),
              ],

              // ─── This Is ───────────────────────────────────────
              if (_thisIsArtists.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'This Is',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ThisIsExploreScreen(
                        artists: _thisIsArtists,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 168,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _thisIsArtists.length.clamp(0, 10),
                    itemBuilder: (context, i) =>
                        _ThisIsCard(artist: _thisIsArtists[i]),
                  ),
                ),
              ],

              // ─── Live Rooms ───────────────────────────────────
              if (_liveRooms.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Live Rooms 🎙',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BrowseRoomsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 132,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _liveRooms.length.clamp(0, 5),
                    itemBuilder: (context, i) {
                      final room = _liveRooms[i] as Map<String, dynamic>;
                      return _LiveRoomCard(room: room);
                    },
                  ),
                ),
              ],

              // ─── Friends are listening ───────────────────────
              if (_friendItems.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Friends are listening',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SocialActivityScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _friendItems.length.clamp(0, 10),
                    itemBuilder: (context, i) =>
                        _FriendListeningCard(friend: _friendItems[i]),
                  ),
                ),
              ],

              ..._buildMoodSection(),

              if (_discoverGlobal.isNotEmpty ||
                  _discoverViral.isNotEmpty ||
                  _freshWave.isNotEmpty ||
                  _discoverRising.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Discover',
                  action: 'Open →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiscoverScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildDiscoverQuickChip(
                        label: '🌐 Global',
                        active: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(initialTab: 0),
                          ),
                        ),
                      ),
                      _buildDiscoverQuickChip(
                        label: '🔥 Viral',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(initialTab: 1),
                          ),
                        ),
                      ),
                      _buildDiscoverQuickChip(
                        label: '🆕 New Releases',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(initialTab: 2),
                          ),
                        ),
                      ),
                      _buildDiscoverQuickChip(
                        label: '📈 Rising',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(initialTab: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_discoverCity.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Text(
                      'Live chart discovery tuned for $_discoverCity',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.text3,
                      ),
                    ),
                  ),
              ],

              // ─── Top in City ───────────────────────────────────
              const SizedBox(height: 22),
              SectionHeader(
                  title: _chartsAreCityData ? 'Top in $city' : 'Global charts',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CityChartsScreen()))),
              if (!_chartsAreCityData && !_loading && _charts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    'Showing worldwide leaders while we keep the feed aligned to $city',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.text3),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loading
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.purpleLight)))
                    : _charts.isEmpty
                        ? _buildStaticCharts(context)
                        : Column(
                            children: _charts
                                .take(5)
                                .toList()
                                .asMap()
                                .entries
                                .map((e) {
                              final i = e.key;
                              final track = e.value as Map<String, dynamic>;
                              final rankColors = [
                                const Color(0xFFf59e0b),
                                const Color(0xFF94a3b8),
                                const Color(0xFFc2774a),
                                AppColors.text3,
                                AppColors.text3,
                              ];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PlayerScreen(track: track))),
                                child: _TopItem(
                                  rank: '${i + 1}',
                                  rankColor: rankColors[i],
                                  title: track['title'] ??
                                      track['trackName'] ??
                                      'Unknown',
                                  artist: track['artist'] ??
                                      track['artistName'] ??
                                      '',
                                  coverUrl: track['cover_url'] ??
                                      track['artworkUrl100'],
                                  isHot: i == 0,
                                ),
                              );
                            }).toList(),
                          ),
              ),

              // ─── Fresh Wave ────────────────────────────────────
              if (_freshWave.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'New Releases 🆕',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DiscoverScreen(initialTab: 2))),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _dedupeTracks(_freshWave).length.clamp(0, 10),
                    itemBuilder: (context, i) {
                      final track =
                          _dedupeTracks(_freshWave)[i] as Map<String, dynamic>;
                      return _TrackCard(track: track);
                    },
                  ),
                ),
              ],

              // ─── Radio For You ────────────────────────────────
              if (_radioStations.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Radio',
                  action: 'See all →',
                  onAction: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RadioScreen())),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _radioStations.length,
                    itemBuilder: (ctx, i) {
                      final s = _radioStations[i] as Map<String, dynamic>;
                      return _RadioStationCard(station: s);
                    },
                  ),
                ),
              ],

              // ─── Hot Right Now ────────────────────────────────
              if (_hotRightNow.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Hot Right Now 🔥',
                  action: 'Discover →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DiscoverScreen())),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _dedupeTracks(_hotRightNow, onePerAlbum: true)
                        .length
                        .clamp(0, 10),
                    itemBuilder: (ctx, i) {
                      final t =
                          _dedupeTracks(_hotRightNow, onePerAlbum: true)[i]
                              as Map<String, dynamic>;
                      return _HotTrackCard(track: t);
                    },
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

  Widget _buildStaticCharts(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_city_rounded,
              size: 28, color: AppColors.text3),
          const SizedBox(height: 10),
          Text('Local charts are updating',
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'We are showing the external chart feed first while local city layering catches up.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.text3, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverQuickChip({
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? AppColors.primaryBtn : null,
            color: active ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  active ? Colors.transparent : Colors.white.withOpacity(0.08),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.purple.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showMoodTracks(String moodKey, String emoji, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _MoodTracksSheet(moodKey: moodKey, emoji: emoji, name: name),
    );
  }
}

// ─── Mixed recommendation card ───────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double width;
  final double imageHeight;
  final bool compact;

  const _RecommendationCard({
    required this.item,
    this.width = 112,
    this.imageHeight = 92,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'track';
    final data = Map<String, dynamic>.from(item['data'] as Map);
    final title = _recommendationTitle(type, data);
    final subtitle = _recommendationSubtitle(type, data);
    final imageUrl = _recommendationImage(type, data);
    final emoji = _recommendationEmoji(type);

    return GestureDetector(
      onTap: () => _openRecommendation(context, type, data),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Container(
                width: width,
                height: imageHeight,
                decoration: BoxDecoration(
                  gradient: _recommendationGradient(type),
                  borderRadius:
                      BorderRadius.circular(type == 'artist' ? 46 : 18),
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(type == 'artist' ? 46 : 18),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      )
                    : Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _recommendationLabel(type),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 7),
            Text(title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: compact ? 10 : 11, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }

  String _recommendationTitle(String type, Map<String, dynamic> data) {
    if (type == 'this_is') return 'This Is ${data['name'] ?? data['artist']}';
    return (data['title'] ??
            data['trackName'] ??
            data['name'] ??
            data['album_name'] ??
            data['display_name'] ??
            data['username'] ??
            'MoodWave pick')
        .toString();
  }

  String _recommendationSubtitle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'artist':
        return 'Artist';
      case 'album':
        return (data['artist'] ?? data['artist_name'] ?? 'Album').toString();
      case 'playlist':
        return (data['track_count'] != null)
            ? '${data['track_count']} songs'
            : 'Playlist';
      case 'user':
        return 'Similar music taste';
      case 'this_is':
        return 'Essential playlist';
      default:
        return (data['artist'] ?? data['artistName'] ?? 'Track').toString();
    }
  }

  String _recommendationImage(String type, Map<String, dynamic> data) {
    if (type == 'artist') {
      return (data['picture_xl'] ??
              data['picture_big'] ??
              data['picture_medium'] ??
              data['photo_url'] ??
              data['image_url'] ??
              data['cover_url'] ??
              data['avatar_url'] ??
              '')
          .toString();
    }
    return (data['cover_url'] ??
            data['artworkUrl100'] ??
            data['cover_xl'] ??
            data['image_url'] ??
            data['picture_xl'] ??
            data['picture_big'] ??
            data['picture_medium'] ??
            data['photo_url'] ??
            data['avatar_url'] ??
            '')
        .toString();
  }

  String _recommendationEmoji(String type) {
    switch (type) {
      case 'artist':
        return '🎤';
      case 'album':
        return '💿';
      case 'playlist':
        return '💜';
      case 'user':
        return '👥';
      case 'this_is':
        return '▶';
      default:
        return '🎵';
    }
  }

  String _recommendationLabel(String type) {
    switch (type) {
      case 'this_is':
        return 'THIS IS';
      case 'user':
        return 'USER';
      default:
        return type.toUpperCase();
    }
  }

  LinearGradient _recommendationGradient(String type) {
    switch (type) {
      case 'album':
        return AppColors.gradBlue;
      case 'playlist':
        return AppColors.gradPurple;
      case 'user':
        return AppColors.gradTeal;
      case 'this_is':
        return AppColors.gradPink;
      case 'artist':
        return AppColors.gradMixed;
      default:
        return AppColors.gradOrange;
    }
  }
}

void _openRecommendation(
    BuildContext context, String type, Map<String, dynamic> data) {
  if (type == 'artist') {
    final id = data['id']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId: id,
          artistName: (data['name'] ?? '').toString(),
        ),
      ),
    );
    return;
  }
  if (type == 'album') {
    final rawId = data['id'] ?? data['album_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumScreen(albumId: id)),
    );
    return;
  }
  if (type == 'playlist') {
    final rawId = data['id'] ?? data['playlist_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistId: id,
          playlistTitle: data['name']?.toString(),
        ),
      ),
    );
    return;
  }
  if (type == 'this_is') {
    _openThisIs(context, data);
    return;
  }
  if (type == 'user') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SimilarUserScreen(user: data),
      ),
    );
    return;
  }
  final track = Map<String, dynamic>.from(data);
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
  );
}

Future<void> _openThisIs(
    BuildContext context, Map<String, dynamic> artist) async {
  final name = (artist['name'] ?? artist['artist'] ?? '').toString();
  if (name.isEmpty) return;
  final imageUrl = (artist['picture_xl'] ??
          artist['picture_big'] ??
          artist['picture_medium'] ??
          artist['photo_url'] ??
          artist['image_url'])
      ?.toString();
  final id = artist['id']?.toString();
  try {
    List<Map<String, dynamic>> tracks = const [];

    // Prefer real top tracks from the artist profile; fall back to text search
    if (id != null && id.isNotEmpty) {
      try {
        final profile = await ApiService().getArtistProfile(id);
        final topTracks = (profile['top_tracks'] as List?) ?? const [];
        if (topTracks.isNotEmpty) {
          tracks = topTracks
              .whereType<Map>()
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
        }
      } catch (_) {}
    }
    if (tracks.isEmpty) {
      final raw = await ApiService().searchTracksWithFallback(name, limit: 35);
      tracks = raw
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThisIsScreen(
          artistName: name,
          artistImageUrl: imageUrl,
          artistId: id,
          tracks: tracks,
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(artistId: id ?? name, artistName: name),
      ),
    );
  }
}

// ─── Radio station card ───────────────────────────────────────────────────────

class _RadioStationCard extends StatefulWidget {
  final Map<String, dynamic> station;
  const _RadioStationCard({required this.station});
  @override
  State<_RadioStationCard> createState() => _RadioStationCardState();
}

class _RadioStationCardState extends State<_RadioStationCard> {
  bool _loading = false;

  Future<void> _play() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final tracks =
          await ApiService().getRadioTracks(widget.station['id'].toString());
      if (!mounted) return;
      if (tracks.isNotEmpty) {
        final queue = tracks
            .whereType<Map>()
            .map((track) => Map<String, dynamic>.from(track))
            .toList();
        final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.station['name']?.toString() ?? '';
    final emoji = widget.station['emoji']?.toString() ?? '🎵';
    final subtitle = widget.station['subtitle']?.toString() ?? '';
    final accentHex = widget.station['accent_hex']?.toString() ?? '#7C3AED';
    final accentColor =
        Color(int.parse(accentHex.replaceFirst('#', 'FF'), radix: 16));

    return GestureDetector(
      onTap: _play,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(top: BorderSide(color: accentColor, width: 2.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor))
                : Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(name,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Hot track card ───────────────────────────────────────────────────────────

class _HotTrackCard extends StatelessWidget {
  final Map<String, dynamic> track;
  const _HotTrackCard({required this.track});

  Color get _badgeColor {
    final badge = (track['badge'] ?? 'HOT').toString();
    if (badge == 'NEW') return const Color(0xFF0EA5E9);
    if (badge.startsWith('+')) return const Color(0xFF7C3AED);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final title = track['title']?.toString() ??
        track['track_id']?.toString() ??
        'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final coverUrl = track['cover_url']?.toString();
    final badge = (track['badge'] ?? 'HOT').toString();

    return GestureDetector(
      onTap: () {
        final trackMap = Map<String, dynamic>.from(track)
          ..['spotify_id'] ??= track['track_id'];
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: trackMap)));
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppColors.gradMixed,
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                            child: Text('🎵', style: TextStyle(fontSize: 36))),
                      ),
                    )
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge,
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            Text(artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }
}

// ─── Recently Played Spotify-style horizontal scroll ──────────────────────────

class _RecentHorizontal extends StatelessWidget {
  final List<dynamic> tracks;
  const _RecentHorizontal({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: tracks.length,
        itemBuilder: (ctx, i) {
          final queue = tracks
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          final track = Map<String, dynamic>.from(tracks[i] as Map)
            ..['queue'] = queue
            ..['queue_context'] = 'Recently Played';
          final title =
              (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
          final artist = (track['artist'] ?? '').toString();
          final coverUrl =
              (track['cover_url'] ?? track['artworkUrl100'])?.toString();

          return GestureDetector(
            onTap: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
            onLongPress: () => showTrackMenu(
              ctx,
              track,
              onPlayNow: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: track))),
            ),
            child: Container(
              width: 96,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _recentFallback(title),
                          )
                        : _recentFallback(title),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                  ),
                  // Subtitle
                  Text(
                    artist.isNotEmpty ? artist : 'Трек',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.text3),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _recentFallback(String title, {double size = 96}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: AppColors.gradMixed,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : '♪',
        style: TextStyle(
            fontSize: size * 0.33,
            fontWeight: FontWeight.w800,
            color: Colors.white),
      ),
    ),
  );
}

class _RecentAlbumCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _RecentAlbumCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final title = (entry['album'] ?? 'Album').toString();
    final artist = (entry['artist'] ?? '').toString();
    final coverUrl = (entry['cover_url'] ?? '').toString();
    final count = (entry['track_count'] as num?)?.toInt() ?? 0;
    final tracks = (entry['tracks'] as List?) ?? const [];
    final firstTrack = tracks.whereType<Map>().isNotEmpty
        ? Map<String, dynamic>.from(tracks.whereType<Map>().first)
        : null;

    return GestureDetector(
      onTap: () {
        if (firstTrack != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: firstTrack)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecentHistoryScreen()),
          );
        }
      },
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.24)),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _recentFallback(title, size: 58),
                  )
                : _recentFallback(title, size: 58),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 3),
              Text(
                'Played $count tracks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3),
              ),
              if (artist.isNotEmpty)
                Text(
                  'Album · $artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 10, color: AppColors.text3),
                ),
              const Spacer(),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── For You / Fresh Wave card ────────────────────────────────────────────────

class _TrackCard extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback? onDontPlay;
  const _TrackCard({required this.track, this.onDontPlay});

  Future<void> _openArtist(BuildContext context) async {
    final artistName = track['artist'] ?? track['artistName'] ?? '';
    final directId = track['artist_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ArtistScreen(artistId: directId, artistName: artistName),
          ));
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
          ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      onLongPress: () => showTrackMenu(
        context,
        track,
        onPlayNow: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
        onGoToArtist: () => _openArtist(context),
        onDontPlay: onDontPlay,
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
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
                          errorWidget: (_, __, ___) => const Center(
                              child:
                                  Text('🎵', style: TextStyle(fontSize: 40)))))
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            GestureDetector(
              onTap: () => _openArtist(context),
              child: Text(artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mood tile ────────────────────────────────────────────────────────────────

class _MoodTile extends StatefulWidget {
  final MoodData mood;
  final VoidCallback onTap;

  const _MoodTile({
    required this.mood,
    required this.onTap,
  });

  @override
  State<_MoodTile> createState() => _MoodTileState();
}

class _MoodTileState extends State<_MoodTile> {
  bool _hovered = false;
  bool _pressed = false;

  Future<void> _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    final active = _hovered || _pressed;
    final pressed = _pressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.965 : (active ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 158,
            transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: pressed
                      ? mood.glowColor.withValues(alpha: 0.48)
                      : Colors.black.withValues(alpha: active ? 0.34 : 0.22),
                  blurRadius: pressed ? 32 : (active ? 24 : 16),
                  spreadRadius: pressed ? 1 : 0,
                  offset: Offset(0, active ? 12 : 6),
                ),
              ],
              border: Border.all(
                color: mood.glowColor.withValues(alpha: active ? 0.62 : 0.0),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo background
                  AnimatedScale(
                    scale: active ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutCubic,
                    child: Image.asset(
                      mood.artUrl,
                      fit: BoxFit.cover,
                      alignment: mood.imageAlignment,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(gradient: mood.gradient),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          mood.glowColor.withValues(alpha: 0.12),
                          mood.gradient.colors.last.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Dark gradient for readable text
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00000000), Color(0xBB000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          mood.glowColor
                              .withValues(alpha: pressed ? 0.34 : 0.0),
                          mood.gradient.colors.last
                              .withValues(alpha: pressed ? 0.18 : 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Text content
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 46,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mood.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSerifDisplay(
                            color: Colors.white,
                            fontSize: 17,
                            shadows: const [
                              Shadow(color: Color(0x88000000), blurRadius: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          mood.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play button — bottom-right
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: AnimatedOpacity(
                      opacity: active ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: AnimatedScale(
                        scale: active ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.92),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.black87, size: 19),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mood tracks bottom sheet ─────────────────────────────────────────────────

class _MoodTracksSheet extends StatefulWidget {
  final String moodKey, emoji, name;
  const _MoodTracksSheet(
      {required this.moodKey, required this.emoji, required this.name});
  @override
  State<_MoodTracksSheet> createState() => _MoodTracksSheetState();
}

class _MoodTracksSheetState extends State<_MoodTracksSheet> {
  List<dynamic> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var tracks = await ApiService().getMoodTracks(widget.moodKey);
      if (tracks.isEmpty) {
        tracks = await ApiService().getRecommendations(mood: widget.moodKey);
      }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF0f0d1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.purpleLight,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text('${widget.name} Vibes',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight))
              : _tracks.isEmpty
                  ? Center(
                      child: Text('No tracks for this mood yet',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: AppColors.text3)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _tracks.length,
                      itemBuilder: (context, i) {
                        final track = _tracks[i] as Map<String, dynamic>;
                        final title =
                            track['title'] ?? track['trackName'] ?? 'Unknown';
                        final artist =
                            track['artist'] ?? track['artistName'] ?? '';
                        final coverUrl =
                            track['cover_url'] ?? track['artworkUrl100'];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            final queue = _tracks
                                .whereType<Map>()
                                .map((t) => Map<String, dynamic>.from(t))
                                .toList();
                            final selected = Map<String, dynamic>.from(track)
                              ..['queue'] = queue;
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerScreen(track: selected)));
                          },
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
                                      borderRadius: BorderRadius.circular(12)),
                                  child: coverUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                              imageUrl: coverUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) =>
                                                  const SizedBox(),
                                              errorWidget: (_, __, ___) =>
                                                  const Center(
                                                      child: Text('🎵'))))
                                      : const Center(
                                          child: Text('🎵',
                                              style: TextStyle(fontSize: 22)))),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    Text(artist,
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text2)),
                                  ])),
                              const Icon(Icons.play_arrow_rounded,
                                  color: AppColors.text3, size: 22),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _AiMixCard extends StatelessWidget {
  final Map<String, dynamic> mix;

  const _AiMixCard({required this.mix});

  void _open(BuildContext context) {
    final tracks = ((mix['tracks'] as List?) ?? const [])
        .whereType<Map>()
        .map((track) => Map<String, dynamic>.from(track))
        .toList();
    if (tracks.isEmpty) return;
    final first = Map<String, dynamic>.from(tracks.first)..['queue'] = tracks;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (mix['title'] ?? 'AI Mix').toString();
    final subtitle = (mix['subtitle'] ?? 'Made for you').toString();
    final emoji = (mix['emoji'] ?? '✨').toString();
    final cover = (mix['cover_url'] ?? '').toString();
    final tracksCount = ((mix['tracks'] as List?) ?? const []).length;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D145B), Color(0xFF0D2547)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: cover.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(child: Text(emoji)),
                      ),
                    )
                  : Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 5),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.text3)),
                  const Spacer(),
                  Text('$tracksCount tracks',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purpleLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home see-all screens ────────────────────────────────────────────────────

class _BecauseYouListenedScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> tracks;
  final String seedArtist;

  const _BecauseYouListenedScreen({
    required this.title,
    required this.tracks,
    required this.seedArtist,
  });

  @override
  Widget build(BuildContext context) {
    final seedKey = seedArtist.trim().toLowerCase();
    final fromArtist = seedKey.isNotEmpty
        ? tracks.where((t) {
            final a = (t['artist'] ?? t['artistName'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            return a == seedKey;
          }).toList()
        : <Map<String, dynamic>>[];
    final others = tracks.where((t) {
      final a = (t['artist'] ?? t['artistName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return a != seedKey;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _PushedHeader(title: title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                if (fromArtist.isNotEmpty) ...[
                  _BecauseSectionLabel(
                      'From ${seedArtist.isNotEmpty ? seedArtist : "this artist"}'),
                  ...fromArtist
                      .map((t) => _BecauseTrackRow(track: t, queue: tracks)),
                  const SizedBox(height: 10),
                ],
                if (others.isNotEmpty) ...[
                  _BecauseSectionLabel(
                      fromArtist.isEmpty ? 'Tracks' : 'Similar vibe'),
                  ...others
                      .map((t) => _BecauseTrackRow(track: t, queue: tracks)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _BecauseSectionLabel extends StatelessWidget {
  final String text;
  const _BecauseSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text3,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _BecauseTrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  final List<Map<String, dynamic>> queue;
  const _BecauseTrackRow({required this.track, required this.queue});

  @override
  Widget build(BuildContext context) {
    final title =
        (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
    final artist = (track['artist'] ?? track['artistName'] ?? '').toString();
    final cover = (track['cover_url'] ?? track['artworkUrl100'])?.toString();
    final durationMs =
        track['duration_ms'] as int? ?? track['trackTimeMillis'] as int? ?? 0;
    final durationStr = durationMs > 0
        ? '${(durationMs ~/ 60000).toString().padLeft(1, '0')}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}'
        : '';
    final withQueue = Map<String, dynamic>.from(track)..['queue'] = queue;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: withQueue))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: cover != null && cover.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Center(child: Text('🎵')),
                    ),
                  )
                : const Center(child: Text('🎵')),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text(artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text2)),
              ],
            ),
          ),
          if (durationStr.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(durationStr,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.play_arrow_rounded,
              color: AppColors.text3, size: 22),
        ]),
      ),
    );
  }
}

class _TrackListScreen extends StatelessWidget {
  final String title;
  final List<dynamic> tracks;

  const _TrackListScreen({required this.title, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _PushedHeader(title: title),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final track = Map<String, dynamic>.from(tracks[i] as Map)
                  ..['queue'] = tracks;
                final title =
                    (track['title'] ?? track['trackName'] ?? 'Unknown')
                        .toString();
                final artist =
                    (track['artist'] ?? track['artistName'] ?? '').toString();
                final cover =
                    (track['cover_url'] ?? track['artworkUrl100'])?.toString();
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerScreen(track: track)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradMixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: cover != null && cover.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: cover,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const Center(child: Text('🎵')),
                                ),
                              )
                            : const Center(child: Text('🎵')),
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
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            Text(artist,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text2)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          color: AppColors.text3, size: 22),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _HomeShelfScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _HomeShelfScreen({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _PushedHeader(title: title),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                mainAxisExtent: 158,
              ),
              itemBuilder: (context, i) => _RecommendationCard(item: items[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RecommendationListRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _RecommendationListRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'album';
    final data = Map<String, dynamic>.from(item['data'] as Map);
    final title = (data['title'] ??
            data['trackName'] ??
            data['album_name'] ??
            data['collectionName'] ??
            'MoodWave pick')
        .toString();
    final subtitle =
        (data['artist'] ?? data['artistName'] ?? data['artist_name'] ?? '')
            .toString();
    final imageUrl = (data['cover_url'] ??
            data['artworkUrl100'] ??
            data['cover_xl'] ??
            data['image_url'] ??
            '')
        .toString();

    return GestureDetector(
      onTap: () => _openRecommendation(context, type, data),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.gradBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('💿')),
                      ),
                    )
                  : const Center(child: Text('💿')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'ALBUM',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

class _ShelfSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ShelfSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.text3,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ShelfEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ShelfEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.music_note_rounded,
                color: AppColors.text3, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouMightLikeScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _YouMightLikeScreen({required this.items});

  @override
  Widget build(BuildContext context) {
    final artists = items.where((item) => item['type'] == 'artist').toList();
    final albums = items.where((item) => item['type'] == 'album').toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const _PushedHeader(title: 'You Might Like'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (artists.isNotEmpty) ...[
                      _ShelfSectionTitle(
                        title: 'Artists for you',
                        subtitle: 'Based on your follows and recent listening',
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: artists.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 210,
                        ),
                        itemBuilder: (context, i) => _RecommendationCard(
                          item: artists[i],
                          width: double.infinity,
                          imageHeight: 140,
                          compact: false,
                        ),
                      ),
                    ],
                    if (albums.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _ShelfSectionTitle(
                        title: 'Albums you may like',
                        subtitle:
                            'A cleaner set of records close to your taste',
                      ),
                      const SizedBox(height: 12),
                      ...albums.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecommendationListRow(item: item),
                        ),
                      ),
                    ],
                    if (artists.isEmpty && albums.isEmpty)
                      const _ShelfEmptyState(
                        title: 'No recommendations yet',
                        subtitle:
                            'Play more music and follow a few artists to unlock better picks.',
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

class _AiMixesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> mixes;

  const _AiMixesScreen({required this.mixes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          const _PushedHeader(title: 'AI Mixes'),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: mixes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                mainAxisExtent: 148,
              ),
              itemBuilder: (context, i) => _AiMixCard(mix: mixes[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ArtistGridScreen extends StatelessWidget {
  final String title;
  final List<dynamic> artists;

  const _ArtistGridScreen({required this.title, required this.artists});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _PushedHeader(title: title),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: artists.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                mainAxisExtent: 122,
              ),
              itemBuilder: (context, i) {
                final artist = Map<String, dynamic>.from(artists[i] as Map);
                return _FollowingItem(artist: artist);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ThisIsExploreScreen extends StatelessWidget {
  final List<Map<String, dynamic>> artists;

  const _ThisIsExploreScreen({required this.artists});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          const _PushedHeader(title: 'This Is'),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: artists.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                mainAxisExtent: 178,
              ),
              itemBuilder: (context, i) => _ThisIsCard(artist: artists[i]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FriendsListeningScreen extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const _FriendsListeningScreen({required this.friends});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          const _PushedHeader(title: 'Friends are listening'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: friends.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FriendListeningCard(
                  friend: friends[i],
                  wide: true,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SimilarUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const _SimilarUserScreen({required this.user});

  @override
  State<_SimilarUserScreen> createState() => _SimilarUserScreenState();
}

class _SimilarUserScreenState extends State<_SimilarUserScreen> {
  bool _following = false;
  bool _loading = false;

  Future<void> _follow() async {
    final rawId = widget.user['user_id'] ?? widget.user['id'];
    final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (userId == null || _loading) return;
    setState(() => _loading = true);
    try {
      await ApiService().followUser(userId);
      if (!mounted) return;
      setState(() => _following = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Followed successfully'),
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['display_name'] ??
            widget.user['username'] ??
            'MoodWave user')
        .toString();
    final username = (widget.user['username'] ?? '').toString();
    final avatar = (widget.user['avatar_url'] ?? '').toString();
    final city = (widget.user['city'] ?? '').toString();
    final score = widget.user['compatibility'] ?? widget.user['score'];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          const _PushedHeader(title: 'Similar Taste'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a063d), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    gradient: AppColors.gradTeal,
                    shape: BoxShape.circle,
                  ),
                  child: avatar.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Center(child: Text(initial)),
                          ),
                        )
                      : Center(
                          child: Text(initial,
                              style: GoogleFonts.outfit(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                ),
                const SizedBox(height: 14),
                Text(name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
                if (username.isNotEmpty)
                  Text('@$username',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.text3)),
                const SizedBox(height: 10),
                Text(
                  [
                    if (city.isNotEmpty) city,
                    if (score != null) '$score% music match',
                    'Likes similar music',
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text2),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _following ? null : _follow,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _following ? null : AppColors.primaryBtn,
                      color: _following ? AppColors.surface3 : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_following ? 'Following' : 'Follow',
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PushedHeader extends StatelessWidget {
  final String title;

  const _PushedHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
        ),
      ]),
    );
  }
}

class _ThisIsCard extends StatelessWidget {
  final Map<String, dynamic> artist;

  const _ThisIsCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = (artist['name'] ?? artist['artist'] ?? 'Artist').toString();
    final imageUrl = (artist['picture_xl'] ??
            artist['picture_big'] ??
            artist['picture_medium'] ??
            artist['photo_url'] ??
            artist['image_url'])
        ?.toString();
    return GestureDetector(
      onTap: () => _openThisIs(context, artist),
      child: Container(
        width: 138,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.82),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('THIS IS',
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Is $name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.05)),
                const SizedBox(height: 4),
                Text('The essential playlist',
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: Colors.white70)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _FindArtistsCard extends StatelessWidget {
  const _FindArtistsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open Search and follow artists you love'),
            backgroundColor: AppColors.surface,
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a063d), Color(0xFF111827)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find artists to follow',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  Text('Your followed artists will appear here.',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: AppColors.purpleLight),
          ]),
        ),
      ),
    );
  }
}

class _FriendListeningCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  final bool wide;

  const _FriendListeningCard({required this.friend, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final name =
        (friend['display_name'] ?? friend['username'] ?? 'Friend').toString();
    final userId =
        (friend['id'] as num?)?.toInt() ?? (friend['user_id'] as num?)?.toInt();
    final now = (friend['now_playing'] as Map?)?.cast<String, dynamic>();
    final track =
        (now?['title'] ?? now?['track_title'] ?? 'Listening now').toString();
    final artist = (now?['artist'] ?? now?['track_artist'] ?? '').toString();
    final cover = buildMediaUrl(
      (now?['cover_url'] ??
              now?['image'] ??
              now?['thumbnail_url'] ??
              now?['track_cover_url'] ??
              now?['album_cover_url'] ??
              now?['artworkUrl100'] ??
              now?['picture_medium'] ??
              friend['cover_url'] ??
              friend['track_cover_url'] ??
              friend['album_cover_url'] ??
              '')
          .toString(),
    );
    final avatarGradients = const [
      AppColors.gradPurple,
      AppColors.gradTeal,
      AppColors.gradMixed,
      LinearGradient(colors: [Color(0xFFfb7185), Color(0xFFf97316)]),
    ];
    final avatarGradient =
        avatarGradients[name.hashCode.abs() % avatarGradients.length];
    final isLive = (friend['activity_status'] ?? '').toString() == 'live';
    final dotColor = isLive ? AppColors.green : const Color(0xFFFBBF24);
    final dotLabel = isLive ? 'listening now' : 'listened recently';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: userId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: userId,
                    initialUser: friend,
                  ),
                ),
              ),
      child: Container(
        width: wide ? double.infinity : 206,
        margin: wide ? EdgeInsets.zero : const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.glass,
                border: Border.all(
                    color: AppColors.purpleLight.withOpacity(0.4), width: 2),
              ),
              child: cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(gradient: avatarGradient),
                      ),
                    )
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: dotLabel,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withOpacity(0.36),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.76),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top item row ─────────────────────────────────────────────────────────────

class _TopItem extends StatelessWidget {
  final String rank, title, artist;
  final Color rankColor;
  final String? coverUrl;
  final String? duration;
  final bool isHot;
  const _TopItem(
      {required this.rank,
      required this.rankColor,
      required this.title,
      required this.artist,
      this.coverUrl,
      this.duration,
      this.isHot = false});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Row(children: [
        SizedBox(
            width: 22,
            child: Text(rank,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: rankColor))),
        const SizedBox(width: 14),
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(12)),
            child: coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('🎵'))))
                : const Center(
                    child: Text('🎵', style: TextStyle(fontSize: 22)))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          Text(artist,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        if (isHot)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.pink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.pink.withOpacity(0.25))),
              child: Text('HOT',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pink,
                      letterSpacing: 0.05)))
        else if (duration != null)
          Text(duration!,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
      ]));
}

// ─── Following item ───────────────────────────────────────────────────────────

class _FollowingItem extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _FollowingItem({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = (artist['name'] ?? '').toString();
    final pictureUrl = (artist['picture_xl'] ??
            artist['picture_big'] ??
            artist['picture_medium'])
        ?.toString();

    return GestureDetector(
      onTap: () {
        final id = artist['id']?.toString() ?? '';
        if (id.isEmpty) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ArtistScreen(artistId: id, artistName: name)));
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradMixed,
                border: Border.all(
                    color: AppColors.purpleLight.withOpacity(0.4), width: 2),
              ),
              child: pictureUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: pictureUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                            child: Text('🎵', style: TextStyle(fontSize: 26))),
                      ),
                    )
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Room card ───────────────────────────────────────────────────────────

class _LiveRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  const _LiveRoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final name = (room['name'] ?? 'Live Room').toString();
    final host = (room['host'] as Map?)?.cast<String, dynamic>() ?? {};
    final hostName =
        (host['first_name'] ?? host['username'] ?? 'Host').toString();
    final track = (room['current_track'] as Map?)?.cast<String, dynamic>();
    final rawBackground =
        (room['background_url'] ?? room['room_background_url'] ?? '')
            .toString();
    final backgroundUrl =
        rawBackground.isNotEmpty ? buildMediaUrl(rawBackground) : null;
    final rawTrackCover =
        (track?['track_cover_url'] ?? track?['cover_url'] ?? '').toString();
    final trackCoverUrl =
        rawTrackCover.isNotEmpty ? buildMediaUrl(rawTrackCover) : null;
    final count = room['participant_count'] ?? 0;
    final state = (room['state'] ?? 'live').toString();
    final badge = state == 'draft'
        ? 'WAITING'
        : state == 'paused'
            ? 'PAUSED'
            : 'LIVE';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListeningPartyScreen(room: room),
          ),
        );
      },
      child: Container(
        width: 188,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: backgroundUrl != null && backgroundUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: backgroundUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => Container(
                        decoration:
                            BoxDecoration(gradient: AppColors.gradPurple),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(gradient: AppColors.gradPurple),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.12),
                      Colors.black.withOpacity(0.68),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: AppColors.pink.withOpacity(0.35)),
                      ),
                      child: Text(badge,
                          style: GoogleFonts.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.pink)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.headphones_rounded,
                              size: 11, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text('$count',
                              style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ]),
                  const Spacer(),
                  if (track != null) ...[
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: trackCoverUrl != null &&
                                  trackCoverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: trackCoverUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: AppColors.purpleDark),
                                )
                              : Container(color: AppColors.purpleDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (track['track_title'] ?? 'Waiting for music')
                                  .toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            Text(
                              (track['track_artist'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  color: Colors.white.withOpacity(0.72)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                  ],
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Hosted by $hostName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
