import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

// ─── Mood data ────────────────────────────────────────────────────────────────

class _MoodData {
  final String key;
  final String name;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;

  const _MoodData({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

const List<_MoodData> _moods = [
  _MoodData(
    key: 'study',
    name: 'Study',
    subtitle: 'Focus and concentration',
    icon: Icons.headphones_rounded,
    gradient: AppColors.gradBlue,
  ),
  _MoodData(
    key: 'sport',
    name: 'Sport',
    subtitle: 'Energy and motivation',
    icon: Icons.bolt_rounded,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFc2410c), Color(0xFFf97316)],
    ),
  ),
  _MoodData(
    key: 'drive',
    name: 'Drive',
    subtitle: 'Open road feeling',
    icon: Icons.directions_car_rounded,
    gradient: AppColors.gradPurple,
  ),
  _MoodData(
    key: 'sleep',
    name: 'Sleep',
    subtitle: 'Calm and peaceful',
    icon: Icons.dark_mode_rounded,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0f172a), Color(0xFF312e81)],
    ),
  ),
  _MoodData(
    key: 'party',
    name: 'Party',
    subtitle: 'Dance and celebrate',
    icon: Icons.celebration_rounded,
    gradient: AppColors.gradPink,
  ),
  _MoodData(
    key: 'chill',
    name: 'Chill',
    subtitle: 'Relax and unwind',
    icon: Icons.waves_rounded,
    gradient: AppColors.gradTeal,
  ),
];

String _getRecommendedMoodKey(Map<String, dynamic>? weather) {
  final hour = DateTime.now().hour;
  final desc =
      (weather?['description'] ?? weather?['condition'] ?? '').toString().toLowerCase();

  if (desc.contains('rain') || desc.contains('drizzle')) return 'chill';
  if (desc.contains('snow')) return 'sleep';
  if (desc.contains('clear') || desc.contains('sunny')) {
    return (hour >= 6 && hour < 12) ? 'sport' : 'party';
  }

  if (hour >= 22 || hour < 6) return 'sleep';
  if (hour >= 6 && hour < 10) return 'sport';
  if (hour >= 10 && hour < 17) return 'study';
  if (hour >= 17 && hour < 20) return 'chill';
  return 'party';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MoodScreen extends StatefulWidget {
  final Map<String, dynamic>? weather;

  const MoodScreen({super.key, this.weather});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  String? _loadingMood;

  Future<void> _play(String moodKey, String moodName) async {
    if (_loadingMood != null) return;
    setState(() => _loadingMood = moodKey);
    try {
      List<dynamic> tracks = [];
      await Future.wait([
        ApiService().getMoodTracks(moodKey).then((v) => tracks = v),
        Future.delayed(const Duration(milliseconds: 500)),
      ]);
      if (!mounted) return;
      if (tracks.isNotEmpty) {
        final firstTrack = Map<String, dynamic>.from(tracks.first as Map)
          ..['queue'] = tracks;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: firstTrack)),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Playing: $moodName vibes'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.surface,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingMood = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendedKey = _getRecommendedMoodKey(widget.weather);
    final recommended = _moods.firstWhere((m) => m.key == recommendedKey);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a063d), AppColors.bg],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── App bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                  Text(
                    'Choose Your Mood',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ]),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Recommended card ──────────────────────────────
                      Text(
                        'Currently Matching Your Vibe',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _play(recommended.key, recommended.name),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: recommended.gradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _loadingMood == recommended.key
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(children: [
                                    Icon(recommended.icon,
                                        size: 52, color: Colors.white),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            recommended.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Recommended for right now',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color:
                                                  Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.play_circle_filled_rounded,
                                        size: 36,
                                        color: Colors.white),
                                  ]),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Text(
                        'All Moods',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── 2-column grid ─────────────────────────────────
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _moods.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 160,
                        ),
                        itemBuilder: (context, i) {
                          final mood = _moods[i];
                          final isLoading = _loadingMood == mood.key;
                          return GestureDetector(
                            onTap: () => _play(mood.key, mood.name),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: mood.gradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(mood.icon,
                                            size: 44, color: Colors.white),
                                        const SizedBox(height: 10),
                                        Text(
                                          mood.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mood.subtitle,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.65),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
