import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../artist_screen.dart';
import '../extra_screens.dart';
import '../notifications_screen.dart';
import '../player_screen.dart';
import '../weather_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _weather;
  List<dynamic> _charts = [];
  List<dynamic> _recentlyPlayed = [];
  List<dynamic> _freshWave = [];
  List<dynamic> _followedArtists = [];
  List<dynamic> _liveRooms = [];
  List<dynamic> _youMightLike = [];
  List<dynamic> _radioStations = [];
  List<dynamic> _hotRightNow = [];
  bool _loading = true;
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
      ]);
      if (!mounted) return;

      final cityCharts = (results[1] as List?) ?? [];
      final globalCharts = (results[3] as List?) ?? [];
      final charts = cityCharts.isNotEmpty ? cityCharts : globalCharts;
      final feed = results[8] as Map<String, dynamic>;

      setState(() {
        _weather = results[0] as Map<String, dynamic>?;
        _charts = charts;
        _chartsAreCityData = cityCharts.isNotEmpty;
        _recentlyPlayed = (results[2] as List?) ?? [];
        _freshWave = globalCharts;
        _followedArtists = (results[4] as List?) ?? [];
        _liveRooms = (results[5] as List?) ?? [];
        _radioStations = (results[6] as List?) ?? [];
        _hotRightNow = (results[7] as List?) ?? [];
        _youMightLike = (feed['you_might_like'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final city = user?['city'] ?? 'Astana';
    final displayName = user?['display_name'] ?? user?['username'] ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final weatherDesc =
        _weather?['description'] ?? _weather?['condition'] ?? 'Clear';
    final weatherTemp = _weather?['temperature'] ?? _weather?['temp'];
    final weatherEmoji = _getWeatherEmoji(weatherDesc);
    final listenersCount = _liveRooms.fold<int>(0, (sum, r) => sum + ((r['participant_count'] as int?) ?? 0));

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
                      const Spacer(),
                      GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen())),
                          child: const AppIconButton(
                              icon: Icons.notifications_outlined)),
                      const SizedBox(width: 10),
                      Container(
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
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                              color: AppColors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.blue.withOpacity(0.3))),
                          child: Text('Play Vibes',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF93c5fd)))),
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
                        onTap: () => Navigator.push(context,
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
              if (_youMightLike.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'You Might Like', action: 'See all →'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _youMightLike.length.clamp(0, 12),
                    itemBuilder: (ctx, i) {
                      final a = _youMightLike[i] as Map<String, dynamic>;
                      return _YouMightLikeItem(artist: a);
                    },
                  ),
                ),
              ],

              // ─── Mood tiles ────────────────────────────────────
              const SizedBox(height: 22),
              const SectionHeader(title: 'Choose Your Mood', action: 'All →'),
              const SizedBox(height: 12),
              SizedBox(
                  height: 130,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 20),
                      children: [
                        _MoodTile(
                            emoji: '📚',
                            name: 'Study',
                            gradient: AppColors.gradBlue,
                            onTap: () =>
                                _showMoodTracks('study', '📚', 'Study')),
                        _MoodTile(
                            emoji: '🏃',
                            name: 'Sport',
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF7c3d12), Color(0xFFf59e0b)]),
                            onTap: () =>
                                _showMoodTracks('workout', '🏃', 'Sport')),
                        _MoodTile(
                            emoji: '🚗',
                            name: 'Drive',
                            gradient: AppColors.gradPurple,
                            onTap: () =>
                                _showMoodTracks('driving', '🚗', 'Drive')),
                        _MoodTile(
                            emoji: '😴',
                            name: 'Sleep',
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                            onTap: () =>
                                _showMoodTracks('sleep', '😴', 'Sleep')),
                        _MoodTile(
                            emoji: '🎉',
                            name: 'Party',
                            gradient: AppColors.gradPink,
                            onTap: () =>
                                _showMoodTracks('party', '🎉', 'Party')),
                        _MoodTile(
                            emoji: '💔',
                            name: 'Sad',
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1a0a2e), Color(0xFF4c1d95)]),
                            onTap: () => _showMoodTracks('sad', '💔', 'Sad')),
                      ])),

              // ─── Top in City ───────────────────────────────────
              const SizedBox(height: 22),
              SectionHeader(
                  title: _chartsAreCityData ? 'Top in $city' : 'Trending Now',
                  action: 'Chart →',
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

              // ─── Radio For You ────────────────────────────────
              if (_radioStations.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'Radio For You', action: 'See all →'),
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
                  onAction: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CityChartsScreen())),
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

              // ─── Following ────────────────────────────────────
              if (_followedArtists.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'Following'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _followedArtists.length.clamp(0, 6),
                    itemBuilder: (context, i) {
                      final artist =
                          _followedArtists[i] as Map<String, dynamic>;
                      return _FollowingItem(artist: artist);
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

              // ─── Fresh Wave ────────────────────────────────────
              if (_freshWave.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Fresh Wave 🌊',
                  action: 'All →',
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
                    itemCount: _freshWave.length.clamp(0, 10),
                    itemBuilder: (context, i) {
                      final track = _freshWave[i] as Map<String, dynamic>;
                      return _TrackCard(track: track);
                    },
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
            style:
                GoogleFonts.outfit(fontSize: 12, color: AppColors.text3, height: 1.5),
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

// ─── You Might Like item ──────────────────────────────────────────────────────

class _YouMightLikeItem extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _YouMightLikeItem({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = (artist['name'] ?? '').toString();
    final photoUrl = artist['photo_url']?.toString();
    final id = artist['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (id.isEmpty) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ArtistScreen(artistId: id, artistName: name)));
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradMixed,
                border: Border.all(color: Colors.white.withOpacity(0.07), width: 1.5),
              ),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '♪',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '♪',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ],
        ),
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
      final tracks = await ApiService().getRadioTracks(widget.station['id'].toString());
      if (!mounted) return;
      if (tracks.isNotEmpty) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: tracks.first as Map<String, dynamic>)));
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
    final accentColor = Color(int.parse(accentHex.replaceFirst('#', 'FF'), radix: 16));

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
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                : Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(name,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
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
    final title = track['title']?.toString() ?? track['track_id']?.toString() ?? 'Unknown';
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
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('🎵', style: TextStyle(fontSize: 36))),
                      ),
                    )
                  : const Center(child: Text('🎵', style: TextStyle(fontSize: 36))),
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
                      fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
            Text(artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
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
              onPlayNow: () => Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
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
                        fontSize: 11,
                        color: AppColors.text3),
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
      final tracks = await ApiService().getRecommendations(mood: widget.moodKey);
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
                        final title = track['title'] ?? track['trackName'] ?? 'Unknown';
                        final artist = track['artist'] ?? track['artistName'] ?? '';
                        final coverUrl = track['cover_url'] ?? track['artworkUrl100'];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PlayerScreen(track: track)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
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
                                              imageUrl: coverUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => const SizedBox(),
                                              errorWidget: (_, __, ___) =>
                                                  const Center(child: Text('🎵'))))
                                      : const Center(
                                          child: Text('🎵', style: TextStyle(fontSize: 22)))),
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
                                        style: GoogleFonts.outfit(
                                            fontSize: 12, color: AppColors.text2)),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                builder: (_) =>
                    ArtistScreen(artistId: id, artistName: name)));
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
                border:
                    Border.all(color: AppColors.purpleLight.withOpacity(0.4), width: 2),
              ),
              child: pictureUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: pictureUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('🎵', style: TextStyle(fontSize: 26))),
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
                            errorWidget: (_, __, ___) =>
                                const Center(child: Text('🎵', style: TextStyle(fontSize: 14)))))
                    : const Center(
                        child: Text('🎙', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.pink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppColors.pink.withOpacity(0.3))),
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
                style: GoogleFonts.outfit(
                    fontSize: 10, color: AppColors.text3)),
            const Spacer(),
            Row(children: [
              const Icon(Icons.headphones_rounded,
                  size: 12, color: AppColors.text3),
              const SizedBox(width: 3),
              Text('$count',
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: AppColors.text3)),
            ]),
          ],
        ),
      ),
    );
  }
}
