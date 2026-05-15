import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import 'modals.dart';
import 'player_screen.dart';
import 'user_profile_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _conditionLabel(String? condition) {
  const labels = {
    'clear': 'Clear Sky',
    'clouds': 'Cloudy',
    'rain': 'Rainy',
    'drizzle': 'Light Rain',
    'snow': 'Snowy',
    'thunderstorm': 'Thunderstorm',
    'storm': 'Stormy',
    'mist': 'Misty',
    'fog': 'Foggy',
    'haze': 'Hazy',
    'smoke': 'Smoky',
  };
  if (condition == null || condition.isEmpty) return 'Clear Sky';
  return labels[condition.toLowerCase()] ??
      condition[0].toUpperCase() + condition.substring(1);
}

String _weatherEmoji(String? condition, String? description) {
  final d = (description ?? condition ?? '').toLowerCase();
  if (d.contains('snow') || d.contains('blizzard')) return '❄️';
  if (d.contains('thunder') || d.contains('storm')) return '⛈️';
  if (d.contains('drizzle') || d.contains('rain')) return '🌧️';
  if (d.contains('overcast')) return '☁️';
  if (d.contains('cloud')) return '🌥️';
  if (d.contains('mist') || d.contains('fog') || d.contains('haze'))
    return '🌫️';
  if (d.contains('clear') || d.contains('sunny')) return '☀️';
  return '🌤️';
}

IconData _weatherIconData(String? condition, String? description) {
  final d = (description ?? condition ?? '').toLowerCase();
  if (d.contains('snow') || d.contains('blizzard')) {
    return Icons.ac_unit_rounded;
  }
  if (d.contains('thunder') || d.contains('storm')) {
    return Icons.thunderstorm_rounded;
  }
  if (d.contains('drizzle') || d.contains('rain')) {
    return Icons.grain_rounded;
  }
  if (d.contains('overcast') || d.contains('cloud')) {
    return Icons.cloud_rounded;
  }
  if (d.contains('mist') || d.contains('fog') || d.contains('haze')) {
    return Icons.blur_on_rounded;
  }
  if (d.contains('clear') || d.contains('sunny')) {
    return Icons.wb_sunny_rounded;
  }
  return Icons.wb_cloudy_rounded;
}

// Returns the Twemoji CDN URL for an emoji string.
String _twemojiUrl(String emoji) {
  if (emoji.isEmpty) return '';
  final points = emoji.runes
      .where((cp) => cp != 0xFE0F) // strip variation selectors
      .map((cp) => cp.toRadixString(16).toLowerCase())
      .toList();
  if (points.isEmpty) return '';
  return 'https://cdn.jsdelivr.net/npm/twemoji@14.0.2/assets/72x72/${points.join('-')}.png';
}

String _listenersLabel(int count, String city) {
  if (count <= 0) return 'Be first in $city today';
  if (count == 1) return '1 person listening now';
  return '$count people listening now';
}

String _playlistListenersLabel(int count, String city) {
  if (count <= 0) return 'Be first in this playlist';
  if (count == 1) return '1 person in $city';
  return '$count people in $city';
}

String _compactCount(int count) {
  if (count >= 1000000) {
    final value = count / 1000000;
    return '${value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    final value = count / 1000;
    return '${value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}K';
  }
  return '$count';
}

// ─── Per-condition gradient colours ───────────────────────────────────────────

List<Color> _headerGradient(String condition) {
  switch (condition) {
    case 'clear':
      return const [Color(0xFF0f1b2d), Color(0xFF1a2d4a), Color(0xFF0d1825)];
    case 'clouds':
      return const [Color(0xFF111d2e), Color(0xFF1e2f44), Color(0xFF0e1822)];
    case 'rain':
    case 'drizzle':
      return const [Color(0xFF080f1a), Color(0xFF0f1d30), Color(0xFF070c14)];
    case 'snow':
      return const [Color(0xFF131c2e), Color(0xFF1b2840), Color(0xFF0f1625)];
    case 'storm':
    case 'thunderstorm':
      return const [Color(0xFF08090f), Color(0xFF13141e), Color(0xFF060608)];
    case 'mist':
    case 'fog':
    case 'haze':
      return const [Color(0xFF101820), Color(0xFF1a2530), Color(0xFF0c1318)];
    default:
      return const [Color(0xFF06101e), Color(0xFF0a1528), Color(0xFF060e1a)];
  }
}

Color _accentColor(String condition) {
  switch (condition) {
    case 'clear':
      return const Color(0xFFfbbf24);
    case 'clouds':
      return const Color(0xFF93c5fd);
    case 'rain':
    case 'drizzle':
      return const Color(0xFF60a5fa);
    case 'snow':
      return const Color(0xFFe0f2fe);
    case 'storm':
    case 'thunderstorm':
      return const Color(0xFFa78bfa);
    case 'mist':
    case 'fog':
    case 'haze':
      return const Color(0xFF94a3b8);
    default:
      return const Color(0xFF93c5fd);
  }
}

// ─── WeatherScreen ─────────────────────────────────────────────────────────────

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  Map<String, dynamic>? _payload;
  bool _loading = true;
  String? _playingPlaylistId;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
    setState(() => _loading = true);
    try {
      final data = await ApiService().getWeatherPlaylist(city);
      if (!mounted) return;
      setState(() {
        _payload = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist) async {
    final playlistId = (playlist['id'] ?? '').toString();
    if (playlistId.isEmpty || _playingPlaylistId != null) return;
    setState(() => _playingPlaylistId = playlistId);
    try {
      // Use first 2 artists for a quick 40-track queue
      final artistQueries =
          (playlist['artist_queries'] as List?)?.whereType<String>().toList() ??
              [];
      final fallback = (playlist['search_query'] ?? '').toString();
      final queries = artistQueries.isNotEmpty
          ? artistQueries.take(2).toList()
          : fallback.isNotEmpty
              ? [fallback]
              : <String>[];

      List<Map<String, dynamic>> queue = [];
      if (queries.isNotEmpty) {
        final results = await Future.wait(
          queries.map(
            (q) => ApiService()
                .searchTracksWithFallback(q, limit: 25)
                .catchError((_) => <Map<String, dynamic>>[]),
          ),
        );
        final seen = <String>{};
        for (final batch in results) {
          for (final t in batch) {
            final id =
                (t['track_id'] ?? t['spotify_id'] ?? t['id'] ?? '').toString();
            if (id.isNotEmpty && seen.add(id)) queue.add(t);
          }
        }
        queue.shuffle(Random());
      }
      if (!mounted) return;
      if (queue.isEmpty) return;
      final first = Map<String, dynamic>.from(queue.first)
        ..['queue'] = queue
        ..['source'] =
            '${(_payload?['city'] ?? 'City')} weather · ${playlist['title'] ?? 'Vibes'}';
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
      );
    } finally {
      if (mounted) setState(() => _playingPlaylistId = null);
    }
  }

  void _openPlaylistDetail(Map<String, dynamic> playlist) {
    final condition = (_payload?['condition'] ?? '').toString().toLowerCase();
    final city = (_payload?['city'] ?? 'City').toString();
    final topListeners = ((_payload?['top_listeners'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherPlaylistDetailScreen(
          playlist: playlist,
          condition: condition,
          city: city,
          weatherIcon: (_payload?['icon'] ?? '').toString(),
          topListeners: topListeners,
        ),
      ),
    );
  }

  Color _hexToColor(String value) {
    final hex = value.replaceAll('#', '');
    if (hex.length != 6) return const Color(0xFF4a6fa5);
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final condition = (_payload?['condition'] ?? '').toString().toLowerCase();
    final condLabel =
        (_payload?['condition_label']?.toString().isNotEmpty == true
                ? _payload!['condition_label']
                : _conditionLabel(condition))
            .toString();
    final description = (_payload?['description'] ?? '').toString();
    final emoji = _weatherEmoji(condition, description);
    final weatherIcon = _weatherIconData(condition, description);
    final icon = (_payload?['icon'] ?? '').toString();

    final rawTemp = _payload?['temp'];
    final temp = rawTemp is num ? rawTemp.toDouble() : null;

    final city = (_payload?['city'] ?? 'City').toString();
    final listeners = (_payload?['listeners_count'] as num?)?.toInt() ?? 0;

    final topListeners = ((_payload?['top_listeners'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final playlists = ((_payload?['playlists'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final headerColors = _headerGradient(condition);
    final accent = _accentColor(condition);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: headerColors,
            stops: const [0.0, 0.4, 1.0],
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purpleLight,
                            ),
                          )
                        else ...[
                          // ── Weather icon (OWM image or emoji fallback) ──
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withOpacity(0.26),
                                  accent.withOpacity(0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Center(
                              child: icon.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          'https://openweathermap.org/img/wn/${icon}@4x.png',
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) => Icon(
                                        weatherIcon,
                                        size: 56,
                                        color: accent,
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        weatherIcon,
                                        size: 56,
                                        color: accent,
                                      ),
                                    )
                                  : Icon(
                                      weatherIcon,
                                      size: 56,
                                      color: accent,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Temperature
                          Text(
                            temp != null ? '${temp.toStringAsFixed(0)}°' : '—°',
                            style: GoogleFonts.outfit(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -3,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Condition label
                          Text(
                            condLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // City
                          Text(
                            city,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: accent.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Listener pill
                          GestureDetector(
                            onTap: topListeners.isEmpty
                                ? null
                                : () => _showListenersSheet(
                                    topListeners, listeners, city),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _blinkController,
                                    builder: (_, __) => Opacity(
                                      opacity:
                                          0.35 + 0.65 * _blinkController.value,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22c55e),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF22c55e)
                                                  .withOpacity(0.55),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _listenersLabel(listeners, city),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: accent.withOpacity(0.9),
                                    ),
                                  ),
                                  if (topListeners.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right_rounded,
                                        size: 14, color: Colors.white38),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Section header ──────────────────────────────────
              if (!_loading && playlists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      'Playlists for this weather',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlist = playlists[index];
                      return _PlaylistCard(
                        playlist: playlist,
                        city: city,
                        isFeatured:
                            playlist['is_featured'] == true && index == 0,
                        playing: _playingPlaylistId ==
                            (playlist['id'] ?? '').toString(),
                        onPlay: () => _playPlaylist(playlist),
                        onViewDetail: () => _openPlaylistDetail(playlist),
                        hexToColor: _hexToColor,
                      );
                    },
                    childCount: playlists.length,
                  ),
                ),
              ],

              // ─── Empty state ─────────────────────────────────────
              if (!_loading && playlists.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: icon.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl:
                                      'https://openweathermap.org/img/wn/${icon}@4x.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 52))),
                                  errorWidget: (_, __, ___) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 52))),
                                )
                              : Center(
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 52))),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$condLabel in $city',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Playlists are loading — pull to refresh.',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.text3),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  void _showListenersSheet(
      List<Map<String, dynamic>> listeners, int total, String city) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text(
              _listenersLabel(total, city),
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'People currently listening to $city weather playlists',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
            const SizedBox(height: 16),
            ...listeners.map((u) {
              final name =
                  (u['display_name'] ?? u['username'] ?? 'User').toString();
              final username = (u['username'] ?? '').toString();
              final avatarUrl =
                  buildMediaUrl((u['avatar_url'] ?? '').toString());
              final userId = (u['id'] as num?)?.toInt();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: userId == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: userId,
                              initialUser: Map<String, dynamic>.from(u),
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient:
                            avatarUrl.isEmpty ? AppColors.gradMixed : null,
                        color: avatarUrl.isNotEmpty ? AppColors.glass : null,
                        shape: BoxShape.circle,
                      ),
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                  child: Text(initial,
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                          : Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            if (username.isNotEmpty)
                              Text('@$username',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.text3),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Playlist card widget (Browse Genres style, used in 2-col grid) ───────────

class _PlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final String city;
  final bool isFeatured;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onViewDetail;
  final Color Function(String) hexToColor;

  const _PlaylistCard({
    required this.playlist,
    required this.city,
    required this.isFeatured,
    required this.playing,
    required this.onPlay,
    required this.onViewDetail,
    required this.hexToColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentStart =
        hexToColor((playlist['accent_start'] ?? '#4a6fa5').toString());
    final accentEnd =
        hexToColor((playlist['accent_end'] ?? '#2d4e7e').toString());
    final listenerCount = (playlist['listeners_count'] as num?)?.toInt() ?? 0;
    final title = (playlist['title'] ?? 'Playlist').toString();
    final description = (playlist['description'] ?? '').toString();
    final emoji = (playlist['emoji'] ?? '🎵').toString();
    final twemojiUrl = _twemojiUrl(emoji);

    return GestureDetector(
      onTap: onViewDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accentStart, accentEnd.withOpacity(0.82)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Stack(
            children: [
              // Faded large emoji background right
              if (twemojiUrl.isNotEmpty)
                Positioned(
                  right: 52,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.12,
                    child: CachedNetworkImage(
                      imageUrl: twemojiUrl,
                      width: 88,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Emoji icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: twemojiUrl.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CachedNetworkImage(
                                  imageUrl: twemojiUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 24))),
                                  errorWidget: (_, __, ___) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 24))),
                                ),
                              )
                            : Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 24))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.62),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (listenerCount > 0) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.graphic_eq_rounded,
                                  size: 11, color: Color(0xFFbbf7d0)),
                              const SizedBox(width: 3),
                              Text(
                                '$listenerCount in $city',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFbbf7d0),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Play button
                    GestureDetector(
                      onTap: playing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onPlay();
                            },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(playing ? 0.1 : 0.22),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Center(
                          child: playing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded,
                                  size: 22, color: Colors.white),
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
    );
  }
}

// ─── Weather Playlist Detail Screen ──────────────────────────────────────────

class WeatherPlaylistDetailScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final String condition;
  final String city;
  final String weatherIcon;
  final List<Map<String, dynamic>> topListeners;

  const WeatherPlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.condition,
    required this.city,
    required this.weatherIcon,
    this.topListeners = const [],
  });

  @override
  State<WeatherPlaylistDetailScreen> createState() =>
      _WeatherPlaylistDetailScreenState();
}

class _WeatherPlaylistDetailScreenState
    extends State<WeatherPlaylistDetailScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      // Prefer artist_queries (5 artists) for ~100 tracks; fall back to single search_query
      final artistQueries = (widget.playlist['artist_queries'] as List?)
              ?.whereType<String>()
              .toList() ??
          [];
      final fallback = (widget.playlist['search_query'] ?? '').toString();
      final queries = artistQueries.isNotEmpty
          ? artistQueries
          : fallback.isNotEmpty
              ? [fallback]
              : <String>[];

      if (queries.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Run all artist searches in parallel (5 × 25 = ~100 tracks)
      final results = await Future.wait(
        queries.map(
          (q) => ApiService()
              .searchTracksWithFallback(q, limit: 25)
              .catchError((_) => <Map<String, dynamic>>[]),
        ),
      );

      // Merge + deduplicate by track id, max 4 tracks per artist
      final merged = <Map<String, dynamic>>[];
      final seen = <String>{};
      final artistCount = <String, int>{};
      for (final batch in results) {
        for (final t in batch) {
          final id = (t['track_id'] ??
                  t['spotify_id'] ??
                  t['deezer_id'] ??
                  t['id'] ??
                  '')
              .toString();
          if (id.isEmpty || !seen.add(id)) continue;
          final artist = (t['artist'] ?? '').toString().trim().toLowerCase();
          if (artist.isNotEmpty) {
            if ((artistCount[artist] ?? 0) >= 4) continue;
            artistCount[artist] = (artistCount[artist] ?? 0) + 1;
          }
          merged.add(t);
        }
      }
      merged.shuffle(Random());

      if (!mounted) return;
      setState(() {
        _tracks = merged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    var queue = List<Map<String, dynamic>>.from(_tracks);
    if (shuffle) {
      final rng = Random();
      for (int i = queue.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = queue[i];
        queue[i] = queue[j];
        queue[j] = tmp;
      }
    }
    final first = Map<String, dynamic>.from(queue.first)
      ..['queue'] = queue
      ..['source'] =
          '${widget.city} weather · ${widget.playlist['title'] ?? 'Vibes'}';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
    );
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  Color _hexToColor(String value) {
    final hex = value.replaceAll('#', '');
    if (hex.length != 6) return const Color(0xFF4a6fa5);
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.playlist['title'] ?? 'Playlist').toString();
    final description = (widget.playlist['description'] ?? '').toString();
    final emoji = (widget.playlist['emoji'] ?? '🎵').toString();
    final twemojiUrl = _twemojiUrl(emoji);
    final trackCount = _tracks.length;
    final listenerCount =
        (widget.playlist['listeners_count'] as num?)?.toInt() ?? 0;
    final accentStart =
        _hexToColor((widget.playlist['accent_start'] ?? '#4a6fa5').toString());
    final accentEnd =
        _hexToColor((widget.playlist['accent_end'] ?? '#2d4e7e').toString());

    final headerColors = _headerGradient(widget.condition);
    final accent = _accentColor(widget.condition);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [headerColors[0], headerColors[1], AppColors.bg],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
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
                      const SizedBox(height: 24),
                      // Playlist header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Playlist icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [accentStart, accentEnd],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: accentStart.withOpacity(0.4),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: twemojiUrl.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: CachedNetworkImage(
                                        imageUrl: twemojiUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, __) => Center(
                                            child: Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 52))),
                                        errorWidget: (_, __, ___) => Center(
                                            child: Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 52))),
                                      ),
                                    )
                                  : Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 52))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Weather badge
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                          color: accent.withOpacity(0.25)),
                                    ),
                                    child: Text(
                                      _conditionLabel(widget.condition),
                                      style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: accent),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (!_loading) '$trackCount songs',
                                    if (listenerCount > 0)
                                      _playlistListenersLabel(
                                          listenerCount, widget.city),
                                  ].join(' · '),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.text2,
                            height: 1.45,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // ── Also listening (compact pill) ──────────────
                      if (widget.topListeners.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showListenersBottomSheet(context),
                          child: Row(
                            children: [
                              // Overlapping mini avatars
                              SizedBox(
                                width: 16.0 +
                                    widget.topListeners.take(4).length * 18.0,
                                height: 26,
                                child: Stack(
                                  children: List.generate(
                                    widget.topListeners.take(4).length,
                                    (i) {
                                      final u = widget.topListeners[i];
                                      final name = (u['display_name'] ??
                                              u['username'] ??
                                              '')
                                          .toString();
                                      final avatarUrl = buildMediaUrl(
                                          (u['avatar_url'] ?? '').toString());
                                      final initial = name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?';
                                      return Positioned(
                                        left: i * 18.0,
                                        child: ClipOval(
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: avatarUrl.isEmpty
                                                  ? AppColors.gradMixed
                                                  : null,
                                              color: avatarUrl.isNotEmpty
                                                  ? AppColors.glass
                                                  : null,
                                              border: Border.all(
                                                  color: AppColors.bg,
                                                  width: 2),
                                            ),
                                            child: avatarUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        Center(
                                                      child: Text(initial,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .white)),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(initial,
                                                        style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Colors.white)),
                                                  ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  listenerCount > 0
                                      ? '${_compactCount(listenerCount)} also listening'
                                      : '${widget.topListeners.length} also listening',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 14, color: AppColors.text3),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // Controls
                      Row(children: [
                        Consumer<PlayerProvider>(
                          builder: (_, provider, __) => GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.toggleShuffle();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: provider.shuffleOn
                                    ? accent.withOpacity(0.2)
                                    : AppColors.glass,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: provider.shuffleOn
                                      ? accent
                                      : AppColors.border,
                                  width: provider.shuffleOn ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(Icons.shuffle_rounded,
                                  size: 22,
                                  color: provider.shuffleOn
                                      ? accent
                                      : AppColors.text3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _tracks.isEmpty
                                ? null
                                : () => _playAll(shuffle: false),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _tracks.isEmpty
                                    ? null
                                    : LinearGradient(
                                        colors: [accentStart, accentEnd]),
                                color: _tracks.isEmpty ? AppColors.glass : null,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _tracks.isEmpty
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: accentStart.withOpacity(0.35),
                                          blurRadius: 20,
                                        )
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: _tracks.isEmpty
                                          ? AppColors.text3
                                          : Colors.white,
                                      size: 20),
                                  const SizedBox(width: 6),
                                  Text('Play All',
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _tracks.isEmpty
                                              ? AppColors.text3
                                              : Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Track list ───────────────────────────────────────
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  ),
                ),
              )
            else if (_tracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Center(
                    child: Text('No tracks found',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text3)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final track = Map<String, dynamic>.from(_tracks[i])
                      ..['queue'] = _tracks
                      ..['queue_context'] = title;
                    final trackTitle = track['title']?.toString() ?? 'Unknown';
                    final artist = track['artist']?.toString() ?? '';
                    final coverUrl = track['cover_url']?.toString();
                    final duration = _fmt(track['duration_ms']);

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
                              bottom: BorderSide(color: Color(0x0AFFFFFF))),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 30,
                            child: Text('${i + 1}',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: coverUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: CachedNetworkImage(
                                      imageUrl: coverUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const SizedBox(),
                                      errorWidget: (_, __, ___) => const Center(
                                          child: Icon(Icons.music_note_rounded,
                                              size: 20, color: Colors.white54)),
                                    ))
                                : const Center(
                                    child: Icon(Icons.music_note_rounded,
                                        size: 20, color: Colors.white54)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trackTitle,
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
                          if (duration.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(duration,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                            ),
                          GestureDetector(
                            onTap: () => showTrackMenu(
                              context,
                              track: track,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.text3),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  void _showListenersBottomSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text(
              'Listening in ${widget.city}',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text),
            ),
            const SizedBox(height: 14),
            ...widget.topListeners.map((u) {
              final name =
                  (u['display_name'] ?? u['username'] ?? 'User').toString();
              final username = (u['username'] ?? '').toString();
              final avatarUrl =
                  buildMediaUrl((u['avatar_url'] ?? '').toString());
              final userId = (u['id'] as num?)?.toInt();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: userId == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: userId,
                              initialUser: Map<String, dynamic>.from(u),
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient:
                            avatarUrl.isEmpty ? AppColors.gradMixed : null,
                        color: avatarUrl.isNotEmpty ? AppColors.glass : null,
                        shape: BoxShape.circle,
                      ),
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                  child: Text(initial,
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                          : Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            if (username.isNotEmpty)
                              Text('@$username',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.text3),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
