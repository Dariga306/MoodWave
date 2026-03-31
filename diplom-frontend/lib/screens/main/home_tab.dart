import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../player_screen.dart';
import '../weather_screen.dart';
import '../playlist_screen.dart';
import '../extra_screens.dart';
import '../ai_playlist_screen.dart';
import '../artist_screen.dart';
import '../album_screen.dart';
import '../notifications_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _weather;
  List<dynamic> _charts = [];
  List<dynamic> _recommendations = [];
  bool _loading = true;

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
        api.getRecommendations().catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _weather = results[0] as Map<String, dynamic>?;
        _charts = (results[1] as List?) ?? [];
        _recommendations = (results[2] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 18) return 'Good afternoon ☀️';
    if (h < 22) return 'Good evening 🌙';
    return 'Late night 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'there';
    final city = user?['city'] ?? 'Astana';
    final firstName = displayName.split(' ').first;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';

    final weatherDesc = _weather?['description'] ?? _weather?['condition'] ?? 'Clear';
    final weatherTemp = _weather?['temperature'] ?? _weather?['temp'];
    final weatherEmoji = _getWeatherEmoji(weatherDesc);
    final listenersCount = _weather?['listeners_count'] ?? 0;

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
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xE61a063d), Colors.transparent]),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_greeting(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                        const SizedBox(height: 2),
                        RichText(text: TextSpan(
                          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text),
                          children: [
                            TextSpan(text: '$firstName '),
                            WidgetSpan(child: ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [AppColors.purpleLight, AppColors.pink]).createShader(b),
                              child: Text('✦', style: GoogleFonts.outfit(
                                  fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)))),
                          ],
                        )),
                      ]),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        child: const AppIconButton(icon: Icons.notifications_outlined)),
                      const SizedBox(width: 10),
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(gradient: AppColors.gradMixed, shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border2, width: 2)),
                        child: Center(child: Text(initial, style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
                    ]),
                  ),
                ),
              ),

              // Weather tile
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF0d1a3d), Color(0xFF1a1060), Color(0xFF0d2040)]),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.blue.withOpacity(0.25))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.blue.withOpacity(0.25))),
                          child: Text('$weatherEmoji Live Weather', style: GoogleFonts.outfit(
                              fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF93c5fd), letterSpacing: 0.05))),
                        const SizedBox(height: 8),
                        Text(
                          weatherTemp != null ? '${weatherTemp.toStringAsFixed(0)}°' : '—°',
                          style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                        Text('$weatherDesc · $city', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF93c5fd).withOpacity(0.7))),
                        const SizedBox(height: 4),
                        Text('$weatherEmoji $listenersCount people listening now',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF93c5fd).withOpacity(0.55))),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blue.withOpacity(0.3))),
                        child: Text('Play Vibes', style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF93c5fd)))),
                    ]),
                  ),
                ),
              ),

              // Mood tiles
              const SizedBox(height: 20),
              const SectionHeader(title: 'Choose Your Mood', action: 'All →'),
              const SizedBox(height: 12),
              SizedBox(height: 130,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 20),
                  children: [
                    _MoodTile(emoji: '📚', name: 'Study', gradient: AppColors.gradBlue,
                        onTap: () => _showMoodTracks('study', '📚', 'Study')),
                    _MoodTile(emoji: '🏃', name: 'Sport',
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF7c3d12), Color(0xFFf59e0b)]),
                        onTap: () => _showMoodTracks('workout', '🏃', 'Sport')),
                    _MoodTile(emoji: '🚗', name: 'Drive', gradient: AppColors.gradPurple,
                        onTap: () => _showMoodTracks('driving', '🚗', 'Drive')),
                    _MoodTile(emoji: '😴', name: 'Sleep',
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                        onTap: () => _showMoodTracks('sleep', '😴', 'Sleep')),
                    _MoodTile(emoji: '🎉', name: 'Party', gradient: AppColors.gradPink,
                        onTap: () => _showMoodTracks('party', '🎉', 'Party')),
                  ])),

              // Top in city (from API)
              const SizedBox(height: 20),
              SectionHeader(title: 'Top in $city', action: 'Chart →',
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityChartsScreen()))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loading
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)))
                    : _charts.isEmpty
                        ? _buildStaticCharts(context)
                        : Column(
                            children: _charts.take(5).toList().asMap().entries.map((e) {
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
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PlayerScreen(track: track))),
                                child: _TopItem(
                                  rank: '${i + 1}',
                                  rankColor: rankColors[i],
                                  title: track['title'] ?? track['trackName'] ?? 'Unknown',
                                  artist: track['artist'] ?? track['artistName'] ?? '',
                                  coverUrl: track['cover_url'] ?? track['artworkUrl100'],
                                  isHot: i == 0,
                                ),
                              );
                            }).toList(),
                          ),
              ),

              // Recommended
              if (_recommendations.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'For You', action: 'See all'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: _recommendations.length.clamp(0, 8),
                    itemBuilder: (context, i) {
                      final track = _recommendations[i] as Map<String, dynamic>;
                      return _TrackCard(track: track);
                    },
                  ),
                ),
              ],

              // Explore grid
              const SizedBox(height: 20),
              const SectionHeader(title: 'Explore'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4,
                  children: [
                    _ExploreCard('🌍', 'Discover', AppColors.gradBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverScreen()))),
                    _ExploreCard('🏙', 'Charts', AppColors.gradPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CityChartsScreen()))),
                    _ExploreCard('📻', 'Radio', AppColors.gradMixed, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioScreen()))),
                    _ExploreCard('🎉', 'Party', AppColors.gradPink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningPartyScreen()))),
                    _ExploreCard('✦', 'AI Mix', AppColors.gradOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPlaylistScreen()))),
                    _ExploreCard('🌨', 'Weather', AppColors.gradCyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticCharts(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen())),
        child: const _TopItem(rank: '1', rankColor: Color(0xFFf59e0b),
            title: 'Sweater Weather', artist: 'The Neighbourhood', isHot: true)),
      const _TopItem(rank: '2', rankColor: Color(0xFF94a3b8),
          title: 'Midnight Rain', artist: 'Taylor Swift'),
      const _TopItem(rank: '3', rankColor: Color(0xFFc2774a),
          title: 'Snowfall', artist: 'NIKI'),
    ]);
  }

  void _showMoodTracks(String moodKey, String emoji, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoodTracksSheet(moodKey: moodKey, emoji: emoji, name: name),
    );
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
}

class _TrackCard extends StatelessWidget {
  final Map<String, dynamic> track;
  const _TrackCard({required this.track});

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(track: track))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(coverUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Text('🎵', style: TextStyle(fontSize: 40)))))
                  : const Center(child: Text('🎵', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
          ],
        ),
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
    child: Container(decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ])));
}

class _MoodTile extends StatelessWidget {
  final String emoji, name;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  const _MoodTile({required this.emoji, required this.name, required this.gradient, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 120, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        const Spacer(),
        Text(name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ])));
}

class _MoodTracksSheet extends StatefulWidget {
  final String moodKey, emoji, name;
  const _MoodTracksSheet({required this.moodKey, required this.emoji, required this.name});
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
      setState(() { _tracks = tracks; _loading = false; });
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
        Container(width: 38, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('${widget.name} Vibes', style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight))
              : _tracks.isEmpty
                  ? Center(child: Text('No tracks for this mood yet',
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3)))
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
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PlayerScreen(track: track)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
                              Container(width: 48, height: 48,
                                  decoration: BoxDecoration(gradient: AppColors.gradMixed,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: coverUrl != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(12),
                                          child: Image.network(coverUrl, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Center(child: Text('🎵'))))
                                      : const Center(child: Text('🎵', style: TextStyle(fontSize: 22)))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                                Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
                              ])),
                              const Icon(Icons.play_arrow_rounded, color: AppColors.text3, size: 22),
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

class _TopItem extends StatelessWidget {
  final String rank, title, artist;
  final Color rankColor;
  final String? coverUrl;
  final String? duration;
  final bool isHot;
  const _TopItem({required this.rank, required this.rankColor,
      required this.title, required this.artist,
      this.coverUrl, this.duration, this.isHot = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
    child: Row(children: [
      SizedBox(width: 22, child: Text(rank, textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: rankColor))),
      const SizedBox(width: 14),
      Container(width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.gradMixed,
          borderRadius: BorderRadius.circular(12)),
        child: coverUrl != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Image.network(coverUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Text('🎵'))))
            : const Center(child: Text('🎵', style: TextStyle(fontSize: 22)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
      ])),
      if (isHot) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.pink.withOpacity(0.15),
            borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.pink.withOpacity(0.25))),
        child: Text('HOT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.pink, letterSpacing: 0.05)))
      else if (duration != null)
        Text(duration!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
    ]));
}
