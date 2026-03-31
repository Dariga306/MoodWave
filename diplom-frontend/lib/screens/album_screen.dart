import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xE61e0846), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)),
                        ),
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.glass,
                              borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.text2)),
                      ]),
                      const SizedBox(height: 20),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)]),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))],
                          ),
                          child: const Center(child: Text('🌧', style: TextStyle(fontSize: 58))),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Album · 2013', style: GoogleFonts.outfit(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.purpleLight, letterSpacing: 0.1)),
                          const SizedBox(height: 8),
                          Text('I Love You.', style: GoogleFonts.outfit(
                              fontSize: 24, fontWeight: FontWeight.w900,
                              color: AppColors.text, letterSpacing: -0.02 * 24, height: 1.1)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(width: 28, height: 28, decoration: BoxDecoration(
                              gradient: AppColors.gradMixed, shape: BoxShape.circle),
                              child: Center(child: Text('TN', style: GoogleFonts.outfit(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
                            const SizedBox(width: 8),
                            Text('The Neighbourhood', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text2)),
                          ]),
                          const SizedBox(height: 6),
                          Text('10 songs · 39 min · ★ 4.9',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                        ])),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PlayerScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.35), blurRadius: 20)],
                            ),
                            child: Row(children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text('Play', style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.glass,
                              borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.favorite_rounded, color: AppColors.pink, size: 20)),
                        const SizedBox(width: 10),
                        Container(width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.glass,
                              borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.more_horiz_rounded, color: AppColors.text2, size: 18)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            // Track list
            _AlbumTrack(num: '▶', title: 'Sweater Weather', isPlaying: true, explicit: true, duration: '3:51'),
            _AlbumTrack(num: '2', title: 'Female Robbery', explicit: true, duration: '3:30'),
            _AlbumTrack(num: '3', title: 'Afraid', duration: '3:27'),
            _AlbumTrack(num: '4', title: 'R.I.P. 2 My Youth', duration: '3:14'),
            _AlbumTrack(num: '5', title: 'A Little Death', duration: '4:02'),
            _AlbumTrack(num: '6', title: 'Wires', duration: '3:54'),
            _AlbumTrack(num: '7', title: 'W.D.Y.W.F.M?', duration: '3:46'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text('© 2013 Columbia Records · 428M total plays',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ),
            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }
}

class _AlbumTrack extends StatelessWidget {
  final String num, title, duration;
  final bool isPlaying, explicit;
  const _AlbumTrack({required this.num, required this.title, required this.duration,
      this.isPlaying = false, this.explicit = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Row(children: [
        SizedBox(width: 22,
          child: Text(num, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: isPlaying ? 12 : 14, fontWeight: FontWeight.w600,
                  color: isPlaying ? AppColors.purpleLight : AppColors.text3))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600,
              color: isPlaying ? AppColors.purpleLight : AppColors.text)),
          Text('The Neighbourhood', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        if (explicit) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(4)),
            child: Text('E', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700,
                color: AppColors.text3, letterSpacing: 0.05)),
          ),
          const SizedBox(width: 8),
        ],
        Text(duration, style: GoogleFonts.outfit(fontSize: 12,
            color: isPlaying ? AppColors.purpleLight : AppColors.text3)),
      ]),
    );
  }
}
