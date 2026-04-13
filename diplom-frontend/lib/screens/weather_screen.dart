import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  Map<String, dynamic>? _weather;
  List<dynamic> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _blinkController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
          ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    try {
      final results = await Future.wait([
        ApiService().getWeather(city).catchError((_) => <String, dynamic>{}),
        ApiService()
            .getRecommendations(mood: _weatherMood(''))
            .catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      final weather = results[0] as Map<String, dynamic>?;
      final mood = _weatherMood(
          weather?['description']?.toString() ?? weather?['condition']?.toString() ?? '');
      // Re-fetch tracks with correct mood
      List<dynamic> tracks = results[1] as List<dynamic>;
      if (mood.isNotEmpty) {
        try {
          tracks = await ApiService().getRecommendations(mood: mood);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _weatherMood(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('rain') || d.contains('drizzle')) return 'rainy';
    if (d.contains('snow')) return 'calm';
    if (d.contains('thunder') || d.contains('storm')) return 'stormy';
    if (d.contains('clear') || d.contains('sunny')) return 'sunny';
    if (d.contains('cloud')) return 'cloudy';
    if (d.contains('fog') || d.contains('mist')) return 'foggy';
    return 'neutral';
  }

  String _weatherEmoji(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('snow')) return '❄️';
    if (d.contains('rain') || d.contains('drizzle')) return '🌧';
    if (d.contains('cloud')) return '☁️';
    if (d.contains('thunder') || d.contains('storm')) return '⛈';
    if (d.contains('clear') || d.contains('sunny')) return '☀️';
    if (d.contains('fog') || d.contains('mist')) return '🌫';
    return '🌤';
  }

  void _playAll() {
    final queue = _tracks.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
    if (queue.isEmpty) return;
    final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    final desc = _weather?['description']?.toString() ??
        _weather?['condition']?.toString() ?? 'Clear';
    final temp = _weather?['temperature'] ?? _weather?['temp'];
    final listeners = _weather?['listeners_count'] ?? 0;
    final emoji = _weatherEmoji(desc);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06101e), Color(0xFF0a1528), Color(0xFF060e1a)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: RefreshIndicator(
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      children: [
                        // Back
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(Icons.arrow_back_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.purpleLight),
                          )
                        else ...[
                          Text(emoji, style: const TextStyle(fontSize: 72)),
                          const SizedBox(height: 12),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Color(0xB393C5FD)],
                            ).createShader(b),
                            child: Text(
                              temp != null
                                  ? '${temp.toStringAsFixed(0)}°'
                                  : '—°',
                              style: GoogleFonts.outfit(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.04 * 64),
                            ),
                          ),
                          Text('$city',
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: const Color(0xFF93c5fd).withOpacity(0.6))),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(desc,
                                  style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.8))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Live listeners badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                              border:
                                  Border.all(color: AppColors.blue.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _blinkController,
                                  builder: (_, __) => Opacity(
                                    opacity: 0.3 + 0.7 * _blinkController.value,
                                    child: Container(
                                      width: 7, height: 7,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22c55e),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: const Color(0xFF22c55e)
                                                  .withOpacity(0.6),
                                              blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('$listeners people listening now',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF93c5fd))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Tracks for this weather
              if (_tracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tracks for this weather',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        GestureDetector(
                          onTap: _playAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 15),
                              const SizedBox(width: 4),
                              Text('Play all',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final track =
                          Map<String, dynamic>.from(_tracks[i] as Map)
                            ..['queue'] = _tracks;
                      final title =
                          track['title']?.toString() ?? 'Unknown';
                      final artist = track['artist']?.toString() ?? '';
                      final coverUrl = track['cover_url']?.toString();
                      final ms = track['duration_ms'];
                      final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
                      final dur = v > 0
                          ? '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}'
                          : '';

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlayerScreen(track: track)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Color(0x0AFFFFFF))),
                          ),
                          child: Row(children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: coverUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(coverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                                  child: Text('🎵',
                                                      style: TextStyle(
                                                          fontSize: 20)))))
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                  if (artist.isNotEmpty)
                                    Text(artist,
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text2)),
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
                    childCount: _tracks.length.clamp(0, 20),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
