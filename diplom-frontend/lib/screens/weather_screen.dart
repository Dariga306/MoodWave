import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Weather info
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    children: [
                      const Text('❄️', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 12),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xB393C5FD)],
                        ).createShader(b),
                        child: Text('−4°',
                            style: GoogleFonts.outfit(
                                fontSize: 64, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: -0.04 * 64)),
                      ),
                      Text('Astana, Kazakhstan',
                          style: GoogleFonts.outfit(
                              fontSize: 16, color: const Color(0xFF93c5fd).withOpacity(0.6))),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Heavy Snow',
                              style: GoogleFonts.outfit(
                                  fontSize: 20, fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8))),
                          const SizedBox(width: 8),
                          const Icon(Icons.wb_sunny_outlined,
                              size: 16, color: Color(0x8093C5FD)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Listeners badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.blue.withOpacity(0.2)),
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
                                    boxShadow: [BoxShadow(
                                        color: const Color(0xFF22c55e).withOpacity(0.6),
                                        blurRadius: 6)],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('42 people listening now',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: const Color(0xFF93c5fd))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Playlists section
              const SectionHeader(title: 'Playlists for this weather'),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _WeatherPlaylistCard(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0d1a3d), Color(0xFF1a3060)]),
                      emoji: '❄️',
                      title: 'Snow Day',
                      subtitle: 'Soft melodies for white mornings',
                      trackCount: '24 songs',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlayerScreen())),
                    ),
                    const SizedBox(height: 14),
                    _WeatherPlaylistCard(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0f172a), Color(0xFF1e1b4b)]),
                      emoji: '🌙',
                      title: 'Winter Night Drive',
                      subtitle: 'Dark roads & city lights in the snow',
                      trackCount: '18 songs',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlayerScreen())),
                    ),
                    const SizedBox(height: 14),
                    _WeatherPlaylistCard(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1c1917), Color(0xFF292524)]),
                      emoji: '☕',
                      title: 'Indoor Warmth',
                      subtitle: 'Jazz & indie for cozy days inside',
                      trackCount: '31 songs',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlayerScreen())),
                    ),
                    const SizedBox(height: 16),
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

class _WeatherPlaylistCard extends StatelessWidget {
  final LinearGradient gradient;
  final String emoji;
  final String title;
  final String subtitle;
  final String trackCount;
  final VoidCallback? onTap;

  const _WeatherPlaylistCard({
    required this.gradient, required this.emoji, required this.title,
    required this.subtitle, required this.trackCount, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 36)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(trackCount,
                            style: GoogleFonts.outfit(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8))),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: Colors.white.withOpacity(0.65))),
                ],
              ),
            ),
            // Play button
            Positioned(
              bottom: 18, right: 18,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
