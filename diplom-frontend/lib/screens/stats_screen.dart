import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int _periodIndex = 0; // 0=All Time, 1=This Month, 2=This Week
  final GlobalKey _shareKey = GlobalKey();

  static const _periodKeys = ['all_time', 'month', 'week'];
  static const _periodLabels = ['All Time', 'This Month', 'This Week'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getUserStats(period: _periodKeys[_periodIndex]);
      if (!mounted) return;
      setState(() { _stats = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmtHours(dynamic val) {
    if (val == null) return '0h';
    final h = val is double ? val : (val as num).toDouble();
    if (h >= 1000) return '${(h / 1000).toStringAsFixed(1)}Kh';
    if (h == h.truncate()) return '${h.toInt()}h';
    return '${h.toStringAsFixed(1)}h';
  }

  String _fmtNum(dynamic val) {
    if (val == null) return '0';
    final n = val is int ? val : (val as num).toInt();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _fmtInt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _stats?['songs_count'] ?? 0;
    final artists = _stats?['unique_artists_count'] ?? 0;
    final playlists = _stats?['playlists_count'] ?? 0;
    final topArtists = (_stats?['top_artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topTracks = (_stats?['top_tracks'] as List?)
        ?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final genres = (_stats?['genres'] as List?)?.cast<String>() ?? [];
    final genreCounts = (_stats?['genre_counts'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    final listeningByTime = (_stats?['listening_by_time'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    final currentStreak = _stats?['current_streak'] as int? ?? 0;
    final bestStreak = _stats?['best_streak'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF08080f), Color(0xFF1a0533), Color(0xFF0d1a3d), Color(0xFF08080f)],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 60, left: -60,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.25), Colors.transparent])))),
            Positioned(top: 300, right: -40,
              child: Container(width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.pink.withOpacity(0.2), Colors.transparent])))),
            SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.purpleLight,
                      backgroundColor: AppColors.surface,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    AppColors.purpleDark.withOpacity(0.2),
                                    AppColors.pink.withOpacity(0.15),
                                  ]),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                                ),
                                child: Text('Your Listening Stats', style: GoogleFonts.outfit(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            // Period switcher
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(children: List.generate(_periodLabels.length, (i) {
                                final active = _periodIndex == i;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_periodIndex != i) {
                                        setState(() => _periodIndex = i);
                                        _load();
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        gradient: active ? AppColors.gradPurple : null,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Center(
                                        child: Text(_periodLabels[i],
                                            style: GoogleFonts.outfit(
                                                fontSize: 12, fontWeight: FontWeight.w700,
                                                color: active ? Colors.white : AppColors.text3)),
                                      ),
                                    ),
                                  ),
                                );
                              })),
                            ),
                            const SizedBox(height: 14),
                            Text("You've been busy…", style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              key: ValueKey('h_${_periodIndex}_${(_stats?['total_hours'] as num?)?.toDouble() ?? 0.0}'),
                              tween: Tween(begin: 0.0, end: (_stats?['total_hours'] as num?)?.toDouble() ?? 0.0),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOut,
                              builder: (_, val, __) => ShaderMask(
                                shaderCallback: (b) => const LinearGradient(
                                  colors: [AppColors.purpleLight, AppColors.pink, AppColors.blueLight],
                                ).createShader(b),
                                child: Text(_fmtHours(val), style: GoogleFonts.outfit(
                                    fontSize: 56, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: -0.04 * 56, height: 1)),
                              ),
                            ),
                            Text(
                              _periodIndex == 1 ? 'listened this month'
                                  : _periodIndex == 2 ? 'listened this week'
                                  : 'listened this year',
                              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2),
                            ),
                            const SizedBox(height: 20),
                            _StatCard(
                              gradient: const LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
                              value: _fmtNum(songs), label: 'songs played', icon: Icons.music_note_rounded,
                              animTarget: songs is int ? songs : (songs as num?)?.toInt() ?? 0,
                              formatter: _fmtInt,
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _StatCard(
                                gradient: const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                                value: _fmtNum(artists), label: 'artists discovered', icon: Icons.people_rounded, small: true,
                                animTarget: artists is int ? artists : (artists as num?)?.toInt() ?? 0,
                                formatter: _fmtInt,
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _StatCard(
                                gradient: const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]),
                                value: _fmtNum(playlists), label: 'playlists created', icon: Icons.queue_music_rounded, small: true,
                                animTarget: playlists is int ? playlists : (playlists as num?)?.toInt() ?? 0,
                                formatter: _fmtInt,
                              )),
                            ]),
                            const SizedBox(height: 14),

                            // Top Tracks
                            if (topTracks.isNotEmpty) ...[
                              Text('Top Songs', style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                              const SizedBox(height: 10),
                              ...topTracks.asMap().entries.map((e) {
                                final i = e.key;
                                final t = e.value;
                                return _TopTrackRow(rank: i + 1, track: t);
                              }),
                              const SizedBox(height: 14),
                            ],

                            // Top Artists
                            Text('Top Artists', style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 12),
                            topArtists.isEmpty
                                ? _EmptySection(text: 'Listen to music to build your top artists')
                                : _buildTopArtists(topArtists),

                            const SizedBox(height: 14),

                            // Listening Activity by time of day
                            if (listeningByTime.isNotEmpty &&
                                listeningByTime.values.any((v) => (v as int? ?? 0) > 0)) ...[
                              Text('Listening Activity', style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                              const SizedBox(height: 12),
                              _ListeningActivityBars(data: listeningByTime),
                              const SizedBox(height: 14),
                            ],

                            // Streak
                            if (currentStreak > 0 || bestStreak > 0) ...[
                              _StreakCard(current: currentStreak, best: bestStreak),
                              const SizedBox(height: 14),
                            ],

                            // Genre section — donut chart if real data, bars otherwise
                            Text('Genre Breakdown', style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 12),
                            if (genreCounts.isNotEmpty)
                              _GenreDonut(genreCounts: genreCounts)
                            else if (genres.isNotEmpty)
                              _buildGenreBars(genres)
                            else
                              _EmptySection(text: 'Listen to more music to see your genres'),

                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _showShareDialog,
                              child: Container(
                                width: double.infinity, padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryBtn,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
                                ),
                                child: Text('Share My Stats', textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog() {
    final songs = _stats?['songs_count'] ?? 0;
    final hours = _fmtHours(_stats?['total_hours']);
    final artists = _stats?['unique_artists_count'] ?? 0;
    final topArtists = (_stats?['top_artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final top1 = topArtists.isNotEmpty ? topArtists[0]['name'] ?? '' : '';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: RepaintBoundary(
          key: _shareKey,
          child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1a0533), Color(0xFF0d1a3d)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MoodWave Stats', style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.purpleLight)),
              const SizedBox(height: 16),
              _ShareRow('Songs played', '$songs'),
              _ShareRow('Hours listened', hours),
              _ShareRow('Artists explored', '$artists'),
              if (top1.isNotEmpty) _ShareRow('Top artist', top1),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('moodwave.app', textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.purpleLight, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildTopArtists(List<Map<String, dynamic>> artists) {
    final gradients = [
      AppColors.gradMixed,
      const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]),
      const LinearGradient(colors: [Color(0xFF065f46), Color(0xFF10b981)]),
    ];

    final padded = List<Map<String, dynamic>>.from(artists);
    while (padded.length < 3) {
      padded.add({'name': '—', 'plays': 0});
    }
    final ordered = [padded[1], padded[0], padded[2]];
    final rankLabels = ['#2', '#1', '#3'];

    return Row(children: List.generate(3, (i) {
      final a = ordered[i];
      final name = a['name']?.toString() ?? '—';
      final plays = a['plays'] as int? ?? 0;
      final playsStr = plays > 0 ? '${plays}x' : '—';
      final initial = name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?';
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
        child: _Top3Card(
          rank: rankLabels[i],
          initial: initial,
          gradient: gradients[i],
          name: name,
          plays: playsStr,
          highlighted: i == 1,
        ),
      ));
    }));
  }

  Widget _buildGenreBars(List<String> genres) {
    final weights = [0.38, 0.26, 0.18, 0.12, 0.06];
    final colors = [AppColors.purpleLight, AppColors.pinkLight, AppColors.blueLight,
        const Color(0xFF5eead4), const Color(0xFFfbbf24)];
    final gradients = [
      const LinearGradient(colors: [Color(0xFF7c3aed), AppColors.purple]),
      const LinearGradient(colors: [Color(0xFF9d174d), AppColors.pink]),
      const LinearGradient(colors: [Color(0xFF1e3a8a), AppColors.blue]),
      const LinearGradient(colors: [Color(0xFF065f46), Color(0xFF10b981)]),
      const LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)]),
    ];

    return Column(
      children: List.generate(genres.length.clamp(0, 5), (i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _GenreBar(genres[i], weights[i], colors[i], gradients[i]),
      )),
    );
  }
}

// ─── Top Track Row ────────────────────────────────────────────────────────────

class _TopTrackRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> track;
  const _TopTrackRow({required this.rank, required this.track});

  @override
  Widget build(BuildContext context) {
    final title = track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final coverUrl = track['cover_url']?.toString();
    final plays = track['play_count'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 22, child: Text('$rank',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(10)),
          child: coverUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.network(coverUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 20))))
              : const Center(child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        Text('${plays}x', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Listening Activity Bar Chart (fl_chart) ─────────────────────────────────

class _ListeningActivityBars extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ListeningActivityBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = ['morning', 'afternoon', 'evening', 'night'];
    final labels = ['Morn', 'Aft', 'Eve', 'Night'];
    final values = keys.map((k) => (data[k] as int? ?? 0).toDouble()).toList();
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 130,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.35,
            barGroups: List.generate(4, (i) {
              final isMax = values[i] == maxVal && values[i] > 0;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    gradient: isMax
                        ? const LinearGradient(
                            colors: [AppColors.purpleDark, AppColors.purpleLight],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter)
                        : null,
                    color: isMax ? null : const Color(0xFF374151),
                    width: 32,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[val.toInt()],
                        style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
                  ),
                  reservedSize: 32,
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
          swapAnimationDuration: const Duration(milliseconds: 500),
          swapAnimationCurve: Curves.easeInOut,
        ),
      ),
    );
  }
}

// ─── Streak Card ─────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int current;
  final int best;
  const _StreakCard({required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2d1654), Color(0xFF1a0a3d)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.local_fire_department_rounded, size: 28, color: Color(0xFFf97316)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Listening Streak', style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Current: $current day${current == 1 ? '' : 's'}  ·  Best: $best day${best == 1 ? '' : 's'}',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text('$current days', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.purpleLight)),
        ),
      ]),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String label, value;
  const _ShareRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
          Text(value, style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
    );
  }
}

// ─── Genre Pie Chart (fl_chart) ───────────────────────────────────────────────

class _GenreDonut extends StatelessWidget {
  final List<Map<String, dynamic>> genreCounts;
  const _GenreDonut({required this.genreCounts});

  @override
  Widget build(BuildContext context) {
    final total = genreCounts.fold<int>(0, (s, e) {
      final p = e['plays'];
      return s + (p is int ? p : int.tryParse(p?.toString() ?? '') ?? 0);
    });
    if (total == 0) return const SizedBox.shrink();

    const colors = [
      AppColors.purpleLight,
      AppColors.pink,
      AppColors.blueLight,
      Color(0xFF5eead4),
      Color(0xFFfbbf24),
      Color(0xFFf87171),
      Color(0xFFa3e635),
      Color(0xFF38bdf8),
    ];

    final items = genreCounts.take(8).toList();

    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: items.asMap().entries.map((e) {
                  final i = e.key;
                  final plays = e.value['plays'];
                  final p = plays is int ? plays : int.tryParse(plays?.toString() ?? '') ?? 0;
                  return PieChartSectionData(
                    value: p.toDouble(),
                    color: colors[i % colors.length],
                    title: '',
                    radius: 40,
                  );
                }).toList(),
                centerSpaceRadius: 38,
                sectionsSpace: 3,
                startDegreeOffset: -90,
              ),
              swapAnimationDuration: const Duration(milliseconds: 800),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(items.length.clamp(0, 5), (i) {
                final name = items[i]['name']?.toString() ?? '';
                final plays = items[i]['plays'];
                final p = plays is int ? plays : int.tryParse(plays?.toString() ?? '') ?? 0;
                final pct = total > 0 ? (p / total * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: colors[i % colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name,
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text),
                        overflow: TextOverflow.ellipsis)),
                    Text('$pct%',
                        style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: colors[i % colors.length])),
                  ]),
                );
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ]);
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String text;
  const _EmptySection({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        const Icon(Icons.music_note_rounded, size: 32, color: AppColors.text3),
        const SizedBox(height: 8),
        Text(text, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final LinearGradient gradient;
  final String value, label;
  final IconData icon;
  final bool small;
  final int? animTarget;
  final String Function(int)? formatter;
  const _StatCard({required this.gradient, required this.value, required this.label, required this.icon, this.small = false, this.animTarget, this.formatter});

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 28.0 : 40.0;
    final valueStyle = GoogleFonts.outfit(
        fontSize: fontSize, fontWeight: FontWeight.w900,
        color: Colors.white, letterSpacing: -0.03 * fontSize, height: 1);

    final valueWidget = animTarget != null && formatter != null
        ? TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: animTarget!),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(formatter!(v), style: valueStyle),
          )
        : Text(value, style: valueStyle);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          valueWidget,
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(
              fontSize: 13, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500)),
        ]),
        Positioned(right: 0, top: 0,
          child: Opacity(opacity: 0.25,
            child: Icon(icon, size: 48, color: Colors.white))),
      ]),
    );
  }
}

class _Top3Card extends StatelessWidget {
  final String rank, initial, name, plays;
  final LinearGradient gradient;
  final bool highlighted;
  const _Top3Card({required this.rank, required this.initial, required this.gradient,
      required this.name, required this.plays, this.highlighted = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: highlighted ? LinearGradient(colors: [
          AppColors.purpleDark.withOpacity(0.15), AppColors.pink.withOpacity(0.1)]) : null,
        color: highlighted ? null : AppColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlighted ? AppColors.purple.withOpacity(0.3) : AppColors.border),
      ),
      child: Column(children: [
        Text(rank, style: GoogleFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: highlighted ? const Color(0xFFf59e0b) : AppColors.text3, letterSpacing: 0.08)),
        const SizedBox(height: 8),
        Container(
          width: highlighted ? 60 : 52, height: highlighted ? 60 : 52,
          decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle,
              border: Border.all(color: AppColors.border2, width: 2)),
          child: Center(child: Text(initial, style: GoogleFonts.outfit(
              fontSize: highlighted ? 22 : 18, fontWeight: FontWeight.w800, color: Colors.white)))),
        const SizedBox(height: 8),
        Text(name, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
        const SizedBox(height: 3),
        Text(plays, style: GoogleFonts.outfit(
            fontSize: 10, color: highlighted ? AppColors.purpleLight : AppColors.text3,
            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400)),
      ]),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String name;
  final double pct;
  final Color color;
  final LinearGradient gradient;
  const _GenreBar(this.name, this.pct, this.color, this.gradient);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        Text('${(pct * 100).toInt()}%', style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 5),
      Stack(children: [
        Container(height: 6, decoration: BoxDecoration(
            color: AppColors.surface3, borderRadius: BorderRadius.circular(100))),
        FractionallySizedBox(widthFactor: pct, child: Container(height: 6,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(100)))),
      ]),
    ]);
  }
}
