import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../album_screen.dart';
import '../artist_screen.dart';
import '../extra_screens.dart';
import '../mood_screen.dart';
import '../notifications_screen.dart';
import '../player_screen.dart';
import '../playlist_screen.dart';
import '../profile_tab_screen.dart';
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
  List<Map<String, dynamic>> _aiMixes = [];
  List<Map<String, dynamic>> _mixedRecommendations = [];
  List<Map<String, dynamic>> _thisIsArtists = [];
  List<dynamic> _radioStations = [];
  List<dynamic> _hotRightNow = [];
  bool _loading = true;
  bool _playingWeather = false;
  bool _chartsAreCityData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    final city = user?['city'] ?? 'Astana';
    final api = ApiService();
    try {
      final results = await Future.wait([
        api.getWeather(city).catchError((_) => <String, dynamic>{}),
        api.getChartsByCity(city).catchError((_) => <dynamic>[]),
        api.getRecentlyPlayed(limit: 20).catchError((_) => <dynamic>[]),
        api.getCharts(genre: '').catchError((_) => <dynamic>[]),
        api.getFollowedArtistsDetails().catchError((_) => <dynamic>[]),
        api.getActiveRooms(limit: 5).catchError((_) => <dynamic>[]),
        // Radio stations (no auth required)
        api.getRadioStations().catchError((_) => <dynamic>[]),
        // Trending tracks (auth optional)
        api.getTrendingTracks(limit: 10).catchError((_) => <dynamic>[]),
        // Home feed (auth required — youMightLike artists)
        api.getHomeFeed().catchError((_) => <String, dynamic>{}),
        api.getFriendsActivity().catchError((_) => <String, dynamic>{}),
        api.getLikedAlbums().catchError((_) => <Map<String, dynamic>>[]),
        api.getPlaylists().catchError((_) => <dynamic>[]),
        api.getRecommendations().catchError((_) => <dynamic>[]),
        api.getMatchCandidates().catchError((_) => <dynamic>[]),
        api.getGenreMixes().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;

      final cityCharts = (results[1] as List?) ?? [];
      final globalCharts = (results[3] as List?) ?? [];
      final charts = cityCharts.isNotEmpty ? cityCharts : globalCharts;
      final feed = results[8] as Map<String, dynamic>;
      final recently = (results[2] as List?) ?? [];
      final followedRaw = (results[4] as List?) ?? [];
      final feedArtistsRaw = (feed['you_might_like'] as List?) ?? [];
      final artistGroups = await Future.wait([
        api.hydrateArtists(followedRaw),
        api.hydrateArtists(feedArtistsRaw),
        api.hydrateArtists(const [
          {'id': 1424821, 'name': 'Lana Del Rey'},
          {'id': 15356779, 'name': 'МЭЙБИ БЭЙБИ'},
          {'id': 288166, 'name': 'Justin Bieber'},
          {'id': 4050205, 'name': 'The Weeknd'},
        ]),
      ]);
      final followed = artistGroups[0];
      final feedArtists = [...artistGroups[1], ...artistGroups[2]];
      final likedAlbums = (results[10] as List?) ?? [];
      final playlists = (results[11] as List?) ?? [];
      final recommendations = (results[12] as List?) ?? [];
      final people = (results[13] as List?) ?? [];
      final genreMixes = (results[14] as List?) ?? [];
      final mixed = _buildMixedRecommendations(
        artists: [...followed, ...feedArtists],
        albums: likedAlbums,
        playlists: playlists,
        tracks: [...recommendations, ...globalCharts],
        people: people,
      );
      final thisIs = _buildThisIsArtists(followed, feedArtists);
      final aiMixes = _buildAiMixes(
        mixes: genreMixes,
        fallbackTracks: [...recommendations, ...globalCharts],
      );
      final because =
          await _loadBecauseYouListened(api, recently, recommendations);
      if (!mounted) return;

      setState(() {
        _weather = results[0] as Map<String, dynamic>?;
        _friendsActivity = Map<String, dynamic>.from(results[9] as Map);
        _charts = charts;
        _chartsAreCityData = cityCharts.isNotEmpty;
        _recentlyPlayed = recently;
        _freshWave = globalCharts;
        _followedArtists = followed;
        _liveRooms = (results[5] as List?) ?? [];
        _radioStations = (results[6] as List?) ?? [];
        _hotRightNow = (results[7] as List?) ?? [];
        _becauseYouListened = because;
        _aiMixes = aiMixes;
        _mixedRecommendations = mixed;
        _thisIsArtists = thisIs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildMixedRecommendations({
    required List<dynamic> artists,
    required List<dynamic> albums,
    required List<dynamic> playlists,
    required List<dynamic> tracks,
    required List<dynamic> people,
  }) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(String type, dynamic value) {
      if (value is! Map) return;
      final item = Map<String, dynamic>.from(value);
      final id = (item['id'] ??
              item['album_id'] ??
              item['playlist_id'] ??
              item['spotify_id'] ??
              item['track_id'] ??
              item['title'] ??
              item['name'] ??
              item['username'])
          .toString();
      final key = '$type:$id';
      if (id.isEmpty || seen.contains(key)) return;
      seen.add(key);
      items.add({'type': type, 'data': item});
    }

    for (var i = 0; i < 8; i++) {
      if (i < artists.length) add('artist', artists[i]);
      if (i < tracks.length) add('track', tracks[i]);
      if (i < albums.length) add('album', albums[i]);
      if (i < playlists.length) add('playlist', playlists[i]);
      if (i < people.length) add('user', people[i]);
      if (i < artists.length) add('this_is', artists[i]);
    }
    return items.take(18).toList();
  }

  List<Map<String, dynamic>> _buildThisIsArtists(
      List<dynamic> followed, List<dynamic> suggested) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(dynamic value) {
      if (value is! Map) return;
      final item = Map<String, dynamic>.from(value);
      final name = (item['name'] ?? item['artist'] ?? '').toString();
      if (name.isEmpty) return;
      final key = name.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      items.add(item);
    }

    for (final item in followed) add(item);
    for (final item in suggested) add(item);
    for (final item in const [
      {'name': 'Lana Del Rey'},
      {'name': 'МЭЙБИ БЭЙБИ'},
      {'name': 'Justin Bieber'},
      {'name': 'The Weeknd'},
    ]) {
      add(item);
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
    final artist = (seed['artist'] ?? seed['artistName'] ?? '').toString();
    final title = (seed['title'] ?? seed['trackName'] ?? '').toString();
    final query = artist.isNotEmpty ? artist : title;
    if (query.isEmpty) return fallback.take(12).toList();
    try {
      final tracks = await api.searchTracksWithFallback(query, limit: 16);
      return tracks
          .where((track) =>
              (track['title'] ?? track['trackName'] ?? '').toString() != title)
          .take(12)
          .toList();
    } catch (_) {
      return fallback.take(12).toList();
    }
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

  List<Map<String, dynamic>> get _friendItems {
    final live = (_friendsActivity['live'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item));
    final recent = (_friendsActivity['recent'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item));
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final item in [...live, ...recent]) {
      final id =
          (item['id'] ?? item['username'] ?? item['display_name']).toString();
      if (id.isEmpty || seen.contains(id)) continue;
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still vibing';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
      );
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

  List<Widget> _buildMoodSection() {
    return [
      const SizedBox(height: 22),
      SectionHeader(
        title: 'Choose Your Mood',
        action: 'See all →',
        onAction: _openMoodExplore,
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 130,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          children: [
            _MoodTile(
                emoji: '😊',
                name: 'Happy',
                gradient: AppColors.gradOrange,
                onTap: () => _showMoodTracks('happy', '😊', 'Happy')),
            _MoodTile(
                emoji: '🌙',
                name: 'Chill',
                gradient: AppColors.gradCyan,
                onTap: () => _showMoodTracks('chill', '🌙', 'Chill')),
            _MoodTile(
                emoji: '💘',
                name: 'Romantic',
                gradient: AppColors.gradPink,
                onTap: () => _showMoodTracks('romantic', '💘', 'Romantic')),
            _MoodTile(
                emoji: '🏃',
                name: 'Workout',
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7c3d12), Color(0xFFf59e0b)]),
                onTap: () => _showMoodTracks('workout', '🏃', 'Workout')),
            _MoodTile(
                emoji: '📚',
                name: 'Focus',
                gradient: AppColors.gradBlue,
                onTap: () => _showMoodTracks('study', '📚', 'Focus')),
            _MoodTile(
                emoji: '🎉',
                name: 'Party',
                gradient: AppColors.gradPurple,
                onTap: () => _showMoodTracks('party', '🎉', 'Party')),
            _MoodTile(
                emoji: '🌧',
                name: 'Rainy',
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0f172a), Color(0xFF2563eb)]),
                onTap: () => _showMoodTracks('rainy', '🌧', 'Rainy')),
            _MoodTile(
                emoji: '🔥',
                name: 'Angry',
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF450a0a), Color(0xFFdc2626)]),
                onTap: () => _showMoodTracks('angry', '🔥', 'Angry')),
            _MoodTile(
                emoji: '☁️',
                name: 'Dreamy',
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF312e81), Color(0xFFa855f7)]),
                onTap: () => _showMoodTracks('dreamy', '☁️', 'Dreamy')),
            _MoodTile(
                emoji: '🚗',
                name: 'Drive',
                gradient: AppColors.gradPurple,
                onTap: () => _showMoodTracks('driving', '🚗', 'Drive')),
            _MoodTile(
                emoji: '💔',
                name: 'Sad',
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1a0a2e), Color(0xFF4c1d95)]),
                onTap: () => _showMoodTracks('sad', '💔', 'Sad')),
          ],
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
    final firstName = displayName.toString().trim().split(' ').first;

    final weatherDesc =
        _weather?['description'] ?? _weather?['condition'] ?? 'Clear';
    final weatherTemp = _weather?['temperature'] ?? _weather?['temp'];
    final weatherEmoji = _getWeatherEmoji(weatherDesc);
    final listenersCount = _liveRooms.fold<int>(
        0, (sum, r) => sum + ((r['participant_count'] as int?) ?? 0));

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
                            const SizedBox(height: 2),
                            Text(
                              '${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.text3),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen())),
                          child: const AppIconButton(
                              icon: Icons.notifications_outlined)),
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0d1a3d),
                              Color(0xFF1a1060),
                              Color(0xFF0d2040)
                            ]),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.blue.withOpacity(0.25))),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: AppColors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                        color:
                                            AppColors.blue.withOpacity(0.25))),
                                child: Text('$weatherEmoji Live Weather',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF93c5fd),
                                        letterSpacing: 0.05))),
                            const SizedBox(height: 8),
                            Text(
                                weatherTemp != null
                                    ? '${weatherTemp.toStringAsFixed(0)}°'
                                    : '—°',
                                style: GoogleFonts.outfit(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1)),
                            Text('$weatherDesc · $city',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: const Color(0xFF93c5fd)
                                        .withOpacity(0.7))),
                            const SizedBox(height: 4),
                            Text(
                                '$weatherEmoji $listenersCount people listening now',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF93c5fd)
                                        .withOpacity(0.55))),
                          ])),
                      GestureDetector(
                        onTap: _playWeatherVibes,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                                color: AppColors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.blue.withOpacity(0.3))),
                            child: _playingWeather
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF93c5fd)),
                                  )
                                : Text('Play Vibes',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF93c5fd)))),
                      ),
                    ]),
                  ),
                ),
              ),

              // ─── Recently Played ───────────────────────────────
              if (_recentlyPlayed.isNotEmpty) ...[
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Recently Played',
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.3)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RecentHistoryScreen())),
                        child: Text('See all',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text2)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _RecentHorizontal(tracks: _recentlyPlayed.take(10).toList()),
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
                      builder: (_) => _HomeShelfScreen(
                        title: 'You Might Like',
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

              // ─── AI Mixes ────────────────────────────────────
              if (_aiMixes.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'AI Mixes',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AiMixesScreen(mixes: _aiMixes),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 146,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _aiMixes.length.clamp(0, 8),
                    itemBuilder: (context, i) => _AiMixCard(mix: _aiMixes[i]),
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
                      builder: (_) => _TrackListScreen(
                        title: _becauseTitle(),
                        tracks: _becauseYouListened,
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

              // ─── Following ────────────────────────────────────
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Following',
                action: _followedArtists.isEmpty ? null : 'See all →',
                onAction: _followedArtists.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ArtistGridScreen(
                              title: 'Following',
                              artists: _followedArtists,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 12),
              if (_followedArtists.isEmpty)
                const _FindArtistsCard()
              else
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _followedArtists.length.clamp(0, 10),
                    itemBuilder: (context, i) {
                      final artist =
                          _followedArtists[i] as Map<String, dynamic>;
                      return _FollowingItem(artist: artist);
                    },
                  ),
                ),

              ..._buildMoodSection(),

              // ─── Top in City ───────────────────────────────────
              const SizedBox(height: 22),
              SectionHeader(
                  title: _chartsAreCityData ? 'Top in $city' : 'Trending Now',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CityChartsScreen()))),
              if (!_chartsAreCityData && !_loading && _charts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    'Global charts • Play more to unlock $city trends',
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
                  title: 'Fresh Wave 🌊',
                  action: 'See all →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _TrackListScreen(
                                title: 'Fresh Wave',
                                tracks: _freshWave,
                              ))),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _freshWave.length.clamp(0, 10),
                    itemBuilder: (context, i) {
                      final track = _freshWave[i] as Map<String, dynamic>;
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
                  action: 'Charts →',
                  onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CityChartsScreen())),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _hotRightNow.length.clamp(0, 10),
                    itemBuilder: (ctx, i) {
                      final t = _hotRightNow[i] as Map<String, dynamic>;
                      return _HotTrackCard(track: t);
                    },
                  ),
                ),
              ],

              // ─── Live Rooms ───────────────────────────────────
              if (_liveRooms.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'Live Rooms 🎙'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
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
                      builder: (_) => _FriendsListeningScreen(
                        friends: _friendItems,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 122,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _friendItems.length.clamp(0, 10),
                    itemBuilder: (context, i) =>
                        _FriendListeningCard(friend: _friendItems[i]),
                  ),
                ),
              ],

              const SizedBox(height: 32),
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
            'Play a few tracks or refresh to see real city results.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.text3, height: 1.5),
          ),
        ],
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
  const _RecommendationCard({required this.item});

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
        width: 112,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Container(
                width: 112,
                height: 92,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
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
    final tracks = await ApiService().searchTracksWithFallback(name, limit: 35);
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
          final track = tracks[i] as Map<String, dynamic>;
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

Widget _recentFallback(String title) {
  return Container(
    width: 96,
    height: 96,
    decoration: BoxDecoration(
      gradient: AppColors.gradMixed,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : '♪',
        style: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    ),
  );
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

class _MoodTile extends StatelessWidget {
  final String emoji, name;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  const _MoodTile(
      {required this.emoji,
      required this.name,
      required this.gradient,
      this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 120,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: gradient, borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(name,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ])));
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
            Text(widget.emoji, style: const TextStyle(fontSize: 24)),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          color: AppColors.text3),
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
                  colors: [Color(0xFF1a063d), Color(0xFF0f172a)],
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF1f103d)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
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
    final avatar = (friend['avatar_url'] ?? '').toString();
    final now = (friend['now_playing'] as Map?)?.cast<String, dynamic>();
    final track =
        (now?['title'] ?? now?['track_title'] ?? 'Listening now').toString();
    final artist = (now?['artist'] ?? now?['track_artist'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: wide ? double.infinity : 196,
      margin: wide ? EdgeInsets.zero : const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradTeal,
          ),
          child: avatar.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                )
              : Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(track,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2)),
              if (artist.isNotEmpty)
                Text(artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.text3)),
            ],
          ),
        ),
      ]),
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
    final coverUrl = track?['track_cover_url']?.toString();
    final count = room['participant_count'] ?? 0;

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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a063d), Color(0xFF0d1a3d)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: AppColors.gradMixed,
                ),
                child: coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget: (_, __, ___) => const Center(
                                child: Text('🎵',
                                    style: TextStyle(fontSize: 14)))))
                    : const Center(
                        child: Text('🎙', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.pink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.pink.withOpacity(0.3))),
                child: Text('LIVE',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pink)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text(hostName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
            const Spacer(),
            Row(children: [
              const Icon(Icons.headphones_rounded,
                  size: 12, color: AppColors.text3),
              const SizedBox(width: 3),
              Text('$count',
                  style:
                      GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
            ]),
          ],
        ),
      ),
    );
  }
}
