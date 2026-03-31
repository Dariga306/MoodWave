import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC280A50), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: [
                      // Top nav
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                          Text('Playlist',
                              style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          Container(
                            width: 40, height: 40,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (_) => Container(
                                width: 4, height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 1.5),
                                decoration: const BoxDecoration(
                                    color: AppColors.text2, shape: BoxShape.circle),
                              )),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Cover + meta
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 130, height: 130,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 40, offset: const Offset(0, 20))
                              ],
                            ),
                            child: const Center(child: Text('❄️', style: TextStyle(fontSize: 52))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Playlist',
                                        style: GoogleFonts.outfit(
                                            fontSize: 11, fontWeight: FontWeight.w700,
                                            color: AppColors.purpleLight, letterSpacing: 0.1)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.purple.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(color: AppColors.purple.withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.people_alt_rounded, size: 10, color: AppColors.purpleLight),
                                          const SizedBox(width: 4),
                                          Text('Collab',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 10, fontWeight: FontWeight.w700,
                                                  color: AppColors.purpleLight)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Winter Nights',
                                    style: GoogleFonts.outfit(
                                        fontSize: 24, fontWeight: FontWeight.w800,
                                        color: AppColors.text, height: 1.2)),
                                const SizedBox(height: 6),
                                Text('By Aigerim & Daniyar',
                                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                                Text('18 songs · 1h 12m',
                                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Controls
                      Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.glass,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.shuffle_rounded, size: 22, color: AppColors.purpleLight),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PlayerScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradPurple,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(
                                      color: AppColors.purpleDark.withOpacity(0.35), blurRadius: 20)],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Play All',
                                        style: GoogleFonts.outfit(
                                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.glass,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.more_horiz_rounded, size: 22, color: AppColors.text2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Track list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: const [
                  _TrackItem(idx: '▶', emoji: '🌨', gradient: AppColors.gradMixed,
                      title: 'Sweater Weather', artist: 'The Neighbourhood', duration: '3:51', isPlaying: true),
                  _TrackItem(idx: '2', emoji: '🌙',
                      gradient: LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF06b6d4)]),
                      title: 'Snowfall', artist: 'NIKI', duration: '3:18'),
                  _TrackItem(idx: '3', emoji: '⭐',
                      gradient: LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                      title: 'Somebody Else', artist: 'The 1975', duration: '5:02'),
                  _TrackItem(idx: '4', emoji: '🌿', gradient: AppColors.gradTeal,
                      title: 'Midnight Rain', artist: 'Taylor Swift', duration: '3:42'),
                  _TrackItem(idx: '5', emoji: '✨', gradient: AppColors.gradOrange,
                      title: 'Superstar', artist: 'Lorde', duration: '3:26'),
                  _TrackItem(idx: '6', emoji: '🎸',
                      gradient: LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
                      title: 'R U Mine?', artist: 'Arctic Monkeys', duration: '3:21'),
                ],
              ),
            ),

            // Add songs
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: AppColors.purpleLight),
                    const SizedBox(width: 8),
                    Text('Add Songs',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
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

class _TrackItem extends StatelessWidget {
  final String idx;
  final String emoji;
  final LinearGradient gradient;
  final String title;
  final String artist;
  final String duration;
  final bool isPlaying;
  const _TrackItem({
    required this.idx, required this.emoji, required this.gradient,
    required this.title, required this.artist, required this.duration,
    this.isPlaying = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        children: [
          SizedBox(width: 20,
            child: Text(idx, textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: isPlaying ? AppColors.purpleLight : AppColors.text3))),
          const SizedBox(width: 14),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(11)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isPlaying ? AppColors.purpleLight : AppColors.text)),
                Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
              ],
            ),
          ),
          Text(duration, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(width: 8),
          const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.text3),
        ],
      ),
    );
  }
}
