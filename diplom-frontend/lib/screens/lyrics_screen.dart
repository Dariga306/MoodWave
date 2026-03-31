import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1a0240), Color(0xFF0d0d20), Color(0xFF001230)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 80, left: -40,
              child: Container(width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.purple.withOpacity(0.2), Colors.transparent])))),
            Positioned(bottom: 100, right: -20,
              child: Container(width: 180, height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.pink.withOpacity(0.15), Colors.transparent])))),
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)),
                        ),
                        Text('LYRICS', style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: const Color(0x80C8B4FF), letterSpacing: 0.1)),
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.white)),
                      ],
                    ),
                  ),
                  // Mini player
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(children: [
                        Container(width: 50, height: 50,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('🌨', style: TextStyle(fontSize: 24)))),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Sweater Weather', style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('The Neighbourhood', style: GoogleFonts.outfit(
                              fontSize: 13, color: const Color(0xB3C8B4FF))),
                          const SizedBox(height: 6),
                          Container(height: 2, decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                          ), child: FractionallySizedBox(
                            widthFactor: 0.38, alignment: Alignment.centerLeft,
                            child: Container(decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                              borderRadius: BorderRadius.circular(100),
                            )),
                          )),
                        ])),
                        const SizedBox(width: 14),
                        Container(width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Lyrics
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LyricLine('All I am is a man', state: _LineState.past),
                          _LyricLine('I want the world in my hands', state: _LineState.past),
                          _LyricLine('I hate the beach', state: _LineState.past),
                          _LyricLine('But I stand in California with my toes in the sand', state: _LineState.past),
                          const SizedBox(height: 16),
                          _LyricLine('Use the sleeves of my sweater', state: _LineState.active),
                          _LyricLine("Let's have an adventure", state: _LineState.upcoming),
                          _LyricLine("Head in the clouds but my gravity's centered", state: _LineState.upcoming),
                          _LyricLine('Touch my neck and I\'ll touch yours', state: _LineState.upcoming),
                          const SizedBox(height: 16),
                          _LyricLine('You in those little high waisted shorts', state: _LineState.upcoming),
                          _LyricLine('Oh yeah oh yeah, oh yeah oh yeah', state: _LineState.upcoming),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lyrics · Genius · Auto-scrolling',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LineState { past, active, upcoming }

class _LyricLine extends StatelessWidget {
  final String text;
  final _LineState state;
  const _LyricLine(this.text, {required this.state});
  @override
  Widget build(BuildContext context) {
    double fontSize = state == _LineState.active ? 26 : state == _LineState.past ? 20 : 18;
    FontWeight fw = state == _LineState.active ? FontWeight.w800
        : state == _LineState.past ? FontWeight.w700 : FontWeight.w500;
    Color color = state == _LineState.active ? Colors.white
        : state == _LineState.past ? const Color(0x66A08CC8) : const Color(0x40A08CC8);
    List<Shadow>? shadows = state == _LineState.active
        ? [BoxShadow(color: AppColors.purple.withOpacity(0.5), blurRadius: 20) as Shadow] : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: GoogleFonts.outfit(
          fontSize: fontSize, fontWeight: fw, color: color,
          height: 1.5, shadows: shadows)),
    );
  }
}
