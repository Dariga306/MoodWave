import 'dart:math' as math;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getUserStats();
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

  @override
  Widget build(BuildContext context) {
    final songs = _stats?['songs_count'] ?? 0;
    final artists = _stats?['unique_artists_count'] ?? 0;
    final playlists = _stats?['playlists_count'] ?? 0;
    final hours = _fmtHours(_stats?['total_hours']);
    final topArtists = (_stats?['top_artists'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final genres = (_stats?['genres'] as List?)?.cast<String>() ?? [];
    final genreCounts = (_stats?['genre_counts'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];

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
                              child: Text('✦ Your Listening Stats', style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                            ),
                            const SizedBox(height: 12),
                            Text("You've been busy…", style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                            const SizedBox(height: 2),
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [AppColors.purpleLight, AppColors.pink, AppColors.blueLight],
                              ).createShader(b),
                              child: Text(hours, style: GoogleFonts.outfit(
                                  fontSize: 56, fontWeight: FontWeight.w900,
                                  color: Colors.white, letterSpacing: -0.04 * 56, height: 1)),
                            ),
                            Text('listened this year', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                            const SizedBox(height: 20),
                            _StatCard(
                              gradient: const LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
                              value: _fmtNum(songs), label: 'songs played', emoji: '🎵',
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _StatCard(
                                gradient: const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                                value: _fmtNum(artists), label: 'artists discovered', emoji: '🎤', small: true)),
                              const SizedBox(width: 10),
                              Expanded(child: _StatCard(
                                gradient: const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]),
                                value: _fmtNum(playlists), label: 'playlists created', emoji: '📱', small: true)),
                            ]),
                            const SizedBox(height: 14),

                            // Top Artists
                            Text('Top Artists', style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 12),
                            topArtists.isEmpty
                                ? _EmptySection(emoji: '🎤', text: 'Listen to music to build your top artists')
                                : _buildTopArtists(topArtists),

                            const SizedBox(height: 14),

                            // Genre section — donut chart if real data, bars otherwise
                            Text('Genre Breakdown', style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 12),
                            if (genreCounts.isNotEmpty)
                              _GenreDonut(genreCounts: genreCounts)
                            else if (genres.isNotEmpty)
                              _buildGenreBars(genres)
                            else
                              _EmptySection(emoji: '🎸', text: 'Listen to more music to see your genres'),

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
                                child: Text('Share My Stats ✦', textAlign: TextAlign.center,
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
              Text('🎵 MoodWave Stats', style: GoogleFonts.outfit(
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
    );
  }

  Widget _buildTopArtists(List<Map<String, dynamic>> artists) {
    final gradients = [
      AppColors.gradMixed,
      const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]),
      const LinearGradient(colors: [Color(0xFF065f46), Color(0xFF10b981)]),
    ];
    final emojis = ['🎸', '🎹', '🎤'];

    final padded = List<Map<String, dynamic>>.from(artists);
    while (padded.length < 3) {
      padded.add({'name': '—', 'plays': 0});
    }
    final ordered = [padded[1], padded[0], padded[2]];
    final medalOrdered = ['🥈 #2', '🥇 #1', '🥉 #3'];

    return Row(children: List.generate(3, (i) {
      final a = ordered[i];
      final name = a['name']?.toString() ?? '—';
      final plays = a['plays'] as int? ?? 0;
      final playsStr = plays > 0 ? '${plays}x' : '—';
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
        child: _Top3Card(
          rank: medalOrdered[i],
          emoji: emojis[i],
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

// ─── Genre Donut Chart ────────────────────────────────────────────────────────

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

    final colors = [
      AppColors.purpleLight,
      AppColors.pink,
      AppColors.blueLight,
      const Color(0xFF5eead4),
      const Color(0xFFfbbf24),
      const Color(0xFFf87171),
      const Color(0xFFa3e635),
      const Color(0xFF38bdf8),
    ];

    final items = genreCounts.take(8).toList();

    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _DonutPainter(items: items, total: total, colors: colors),
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

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int total;
  final List<Color> colors;
  const _DonutPainter({required this.items, required this.total, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    double startAngle = -math.pi / 2;
    for (int i = 0; i < items.length; i++) {
      final plays = items[i]['plays'];
      final p = plays is int ? plays : int.tryParse(plays?.toString() ?? '') ?? 0;
      final sweep = 2 * math.pi * p / total;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep - 0.03, false, paint);
      startAngle += sweep;
    }
    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2,
          size.height / 2 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.items != items || old.total != total;
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String emoji, text;
  const _EmptySection({required this.emoji, required this.text});
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
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(text, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final LinearGradient gradient;
  final String value, label, emoji;
  final bool small;
  const _StatCard({required this.gradient, required this.value, required this.label, required this.emoji, this.small = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.outfit(
              fontSize: small ? 28 : 40, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: -0.03 * (small ? 28 : 40), height: 1)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(
              fontSize: 13, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500)),
        ]),
        Positioned(right: 0, top: 0,
          child: Opacity(opacity: 0.3,
            child: Text(emoji, style: const TextStyle(fontSize: 48)))),
      ]),
    );
  }
}

class _Top3Card extends StatelessWidget {
  final String rank, emoji, name, plays;
  final LinearGradient gradient;
  final bool highlighted;
  const _Top3Card({required this.rank, required this.emoji, required this.gradient,
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
          child: Center(child: Text(emoji, style: TextStyle(fontSize: highlighted ? 26 : 22)))),
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
