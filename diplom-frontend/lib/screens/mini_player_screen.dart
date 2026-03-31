import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

/// Floating mini player bar — place above bottom nav
class MiniPlayerBar extends StatefulWidget {
  final VoidCallback? onTap;
  const MiniPlayerBar({super.key, this.onTap});
  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar> with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xF2120826),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: AppColors.purpleDark.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, -8)),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Row(children: [
            const SizedBox(width: 16),
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: child,
              ),
              child: Container(width: 46, height: 46,
                decoration: BoxDecoration(gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('🌨', style: TextStyle(fontSize: 22)))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sweater Weather', style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    overflow: TextOverflow.ellipsis),
                Text('The Neighbourhood', style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.text2)),
                const SizedBox(height: 5),
                Container(height: 2, decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100)),
                  child: FractionallySizedBox(widthFactor: 0.38, alignment: Alignment.centerLeft,
                    child: Container(decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                      borderRadius: BorderRadius.circular(100))))),
              ],
            )),
            const SizedBox(width: 6),
            Row(children: [
              SizedBox(width: 36, height: 36,
                child: const Icon(Icons.skip_previous_rounded, color: AppColors.text2, size: 22)),
              GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradPurple, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.45), blurRadius: 12)],
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 20)),
              ),
              SizedBox(width: 36, height: 36,
                child: const Icon(Icons.skip_next_rounded, color: AppColors.text2, size: 22)),
            ]),
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}

/// Home screen with mini player visible
class HomeWithMiniPlayer extends StatelessWidget {
  const HomeWithMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good night 🌙', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                        Text('Aigerim', style: GoogleFonts.outfit(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: AppColors.text, letterSpacing: -0.02 * 26)),
                      ],
                    ),
                  ),
                ),
                // Continue Listening card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.purpleDark.withOpacity(0.1),
                        AppColors.pink.withOpacity(0.07),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.purple.withOpacity(0.15)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CONTINUE LISTENING', style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.text3, letterSpacing: 0.08)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Container(width: 64, height: 64,
                          decoration: BoxDecoration(gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Center(child: Text('🌨', style: TextStyle(fontSize: 28)))),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Sweater Weather', style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          Text('The Neighbourhood', style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.text2)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: Container(height: 3, decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                              borderRadius: BorderRadius.circular(100)))),
                            const SizedBox(width: 4),
                            Container(width: 60, height: 3, decoration: BoxDecoration(
                                color: AppColors.surface3, borderRadius: BorderRadius.circular(100))),
                          ]),
                        ])),
                      ]),
                    ]),
                  ),
                ),
                // Playlists grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Your Playlists', style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                    Text('See all', style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.purpleLight)),
                  ]),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      _PlaylistCard('❄️', 'Winter Nights', '18 songs',
                          const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed)])),
                      _PlaylistCard('🌙', 'Late Night', '32 songs',
                          const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)])),
                      _PlaylistCard('🏃', 'Workout', '24 songs',
                          const LinearGradient(colors: [Color(0xFF064e3b), Color(0xFF10b981)])),
                      _PlaylistCard('☀️', 'Summer', '56 songs',
                          const LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mini player
          Positioned(
            bottom: 84 + 12, left: 12, right: 12,
            child: MiniPlayerBar(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final String emoji, name, count;
  final LinearGradient gradient;
  const _PlaylistCard(this.emoji, this.name, this.count, this.gradient);
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))))),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              Text(count, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text2)),
            ])),
          ]),
        ),
      ]),
    );
  }
}
