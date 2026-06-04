import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'modals.dart';
import 'player_screen.dart';

class CityChartsScreen extends StatefulWidget {
  const CityChartsScreen({super.key});

  @override
  State<CityChartsScreen> createState() => _CityChartsScreenState();
}

// World cities available for chart browsing
const _kWorldCities = [
  'Dubai',
  'Abu Dhabi',
  'Riyadh',
  'Doha',
  'Muscat',
  'Cairo',
  'New York',
  'Los Angeles',
  'Chicago',
  'Houston',
  'Miami',
  'Atlanta',
  'Toronto',
  'London',
  'Paris',
  'Berlin',
  'Amsterdam',
  'Madrid',
  'Barcelona',
  'Milan',
  'Rome',
  'Ibiza',
  'Tokyo',
  'Seoul',
  'Beijing',
  'Shanghai',
  'Singapore',
  'Bangkok',
  'Jakarta',
  'Mumbai',
  'Delhi',
  'Lagos',
  'Nairobi',
  'Accra',
  'Johannesburg',
  'Mexico City',
  'Bogota',
  'Sao Paulo',
  'Buenos Aires',
  'Lima',
  'Santiago',
  'Sydney',
  'Melbourne',
  'Moscow',
  'Istanbul',
  'Tel Aviv',
  'Astana',
  'Almaty',
];

class _CityChartsScreenState extends State<CityChartsScreen>
    with TickerProviderStateMixin {
  List<dynamic> _tracks = [];
  bool _loading = true;
  String? _error;
  String _source = 'global';
  String? _selectedCity;

  late final AnimationController _pulseCtrl;
  late final AnimationController _counterCtrl;
  late final Animation<double> _counterAnim;
  int _listenerTarget = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _counterAnim =
        CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOutCubic);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  String _resolveCity() {
    if (_selectedCity != null && _selectedCity!.isNotEmpty)
      return _selectedCity!;
    final user = context.read<AuthProvider>().user;
    return user?['city']?.toString() ?? 'Astana';
  }

  Future<void> _load() async {
    final city = _resolveCity();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getChartsByCity(city);
      if (!mounted) return;
      final tracks = data['tracks'] as List? ?? [];
      final source = data['source'] as String? ?? 'global';
      final totalLive = tracks
          .whereType<Map>()
          .map((raw) => (raw['play_count'] as num?)?.toInt() ?? 0)
          .fold<int>(0, (sum, count) => sum + count);
      final target = totalLive > 0
          ? totalLive
          : tracks.length * 120 + 821 + math.Random().nextInt(200);
      setState(() {
        _tracks = tracks;
        _loading = false;
        _listenerTarget = target;
        _source = source;
      });
      _counterCtrl.forward(from: 0);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CityPickerSheet(),
    );
    if (picked != null && picked != _selectedCity) {
      setState(() => _selectedCity = picked);
      _load();
    }
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : (int.tryParse('$ms') ?? 0);
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> get _artists {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final raw in _tracks.whereType<Map>()) {
      final t = Map<String, dynamic>.from(raw);
      final name = (t['artist'] ?? '').toString();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      result.add({
        'name': name,
        'id': t['artist_id'] ?? '',
        'image': t['artist_picture'] ?? t['cover_url'],
      });
      if (result.length >= 12) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final city = _resolveCity();

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: _buildHeader(city)),
            ),
            SliverToBoxAdapter(child: _buildHero(city)),
            if (_source == 'global')
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'No local data yet — showing global charts',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (_tracks.isEmpty)
              SliverFillRemaining(child: _EmptyState(city: city))
            else ...[
              if (_artists.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Shelf(
                    title: 'Top Artists in $city',
                    child: SizedBox(
                      height: 116,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20),
                        itemCount: _artists.length,
                        itemBuilder: (ctx, i) =>
                            _ArtistChip(artist: _artists[i]),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Tracks',
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      Text('${_tracks.length} tracks',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.text3)),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TrackRow(
                    index: i,
                    track: Map<String, dynamic>.from(_tracks[i] as Map)
                      ..['queue'] = _tracks,
                    fmt: _fmt,
                  ),
                  childCount: _tracks.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String city) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _GlassButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop()),
          const Spacer(),
          GestureDetector(
            onTap: _pickCity,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$city Charts',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.text2),
            ]),
          ),
          const Spacer(),
          _GlassButton(icon: Icons.refresh_rounded, onTap: _load),
        ],
      ),
    );
  }

  Widget _buildHero(String city) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF080A30), Color(0xFF0A0A1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.blue.withOpacity(0.18)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.blue.withOpacity(0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickCity,
                  child: Row(children: [
                    const Text('📍', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(city,
                        style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                            letterSpacing: -0.4)),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_location_alt_outlined,
                        size: 16, color: AppColors.text3),
                  ]),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Row(children: [
                    Opacity(
                      opacity: 0.3 + 0.7 * _pulseCtrl.value,
                      child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFF22c55e),
                              shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 6),
                    Text('Updated live · just now',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF22c55e))),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  _StatBlock(
                    value: AnimatedBuilder(
                      animation: _counterAnim,
                      builder: (_, __) {
                        final v =
                            (_listenerTarget * _counterAnim.value).toInt();
                        return ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                                  colors: [AppColors.blueLight, AppColors.cyan])
                              .createShader(b),
                          child: Text(_fmtNum(v),
                              style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        );
                      },
                    ),
                    label: 'streaming now',
                  ),
                  const SizedBox(width: 24),
                  _StatBlock(
                    value: Text('${_tracks.length}',
                        style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.purpleLight)),
                    label: 'charting tracks',
                  ),
                  const SizedBox(width: 24),
                  _StatBlock(
                    value: Text('24h',
                        style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.amber)),
                    label: 'window',
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _TrackRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> track;
  final String Function(dynamic) fmt;

  const _TrackRow(
      {required this.index, required this.track, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final title = track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final coverUrl = track['cover_url']?.toString();
    final dur = fmt(track['duration_ms']);
    final isTop3 = index < 3;
    final isTopTen = index < 10;
    final plays = (track['play_count'] as num?)?.toInt() ?? 0;
    const rankEmojis = ['🥇', '🥈', '🥉'];
    final rankColors = [
      const Color(0xFFf59e0b),
      const Color(0xFF94a3b8),
      const Color(0xFFc2774a),
    ];

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isTopTen ? Colors.white.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isTopTen ? Colors.white.withOpacity(0.06) : Colors.transparent,
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: isTop3
                ? Text(rankEmojis[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18))
                : Text('${index + 1}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text3)),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 52,
              height: 52,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, __, ___) => _CoverFallback(),
                    )
                  : _CoverFallback(),
            ),
          ),
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
                      color: isTop3 ? Colors.white : AppColors.text)),
              if (artist.isNotEmpty)
                Text(artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isTop3
                            ? rankColors[index].withOpacity(0.8)
                            : AppColors.text2)),
            ]),
          ),
          if (plays > 0)
            _CountPill(
              label: _fmtShort(plays),
              color: isTop3 ? rankColors[index] : AppColors.purpleLight,
            ),
          if (dur.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dur,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showTrackActions(context, track),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.text3.withOpacity(0.86)),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtShort(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ArtistChip extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistChip({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['name']?.toString() ?? '';
    final image = artist['image']?.toString();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(
          child: SizedBox(
            width: 72,
            height: 72,
            child: image != null
                ? CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.surface2),
                    errorWidget: (_, __, ___) => _AvatarFallback(name: name),
                  )
                : _AvatarFallback(name: name),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text2)),
        ),
      ]),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface2,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.purpleLight),
          ),
        ),
      );
}

class _Shelf extends StatelessWidget {
  final String title;
  final Widget child;
  const _Shelf({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          child,
        ],
      );
}

class _StatBlock extends StatelessWidget {
  final Widget value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          value,
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ],
      );
}

class _CountPill extends StatelessWidget {
  final String label;
  final Color color;
  const _CountPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.32)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      );
}

void _showTrackActions(BuildContext context, Map<String, dynamic> track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF12071f),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            title: Text('Play now',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              );
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.playlist_play_rounded, color: Colors.white),
            title: Text('Add to playlist',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylist(context, track: track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: Colors.white),
            title: Text('Share track',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showShareTrack(context, track: track);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _CoverFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface2,
        child: const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
      );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  List<String> get _filtered {
    if (_query.isEmpty) return _kWorldCities;
    final q = _query.toLowerCase();
    return _kWorldCities.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Text('Choose City',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              style: GoogleFonts.outfit(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search city…',
                hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.text3),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final city = _filtered[i];
                return ListTile(
                  dense: true,
                  leading: const Text('📍', style: TextStyle(fontSize: 16)),
                  title: Text(city,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text)),
                  onTap: () => Navigator.of(context).pop(city),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Could not load charts',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text('Tap to retry',
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.purpleLight)),
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final String city;
  const _EmptyState({required this.city});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('$city is still warming up',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Play some tracks to build local charts',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
        ]),
      );
}
