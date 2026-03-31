import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';

class ArtistScreen extends StatefulWidget {
  const ArtistScreen({super.key});
  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  bool _following = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            SizedBox(
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1a0533), Color(0xFF0d1a3d)]),
                    ),
                    child: const Center(child: Text('🎸', style: TextStyle(fontSize: 120))),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0x1A000000), Color(0x99080810), Color(0xFF08080f)],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Top buttons
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _following = !_following),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: _following ? null : AppColors.gradPurple,
                                  color: _following ? AppColors.glass2 : null,
                                  borderRadius: BorderRadius.circular(100),
                                  border: _following ? Border.all(color: AppColors.border2) : null,
                                  boxShadow: _following ? null : [BoxShadow(
                                      color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 16)],
                                ),
                                child: Text(_following ? 'Following ✓' : 'Follow',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom info
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.blue.withOpacity(0.25)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF60a5fa)),
                            const SizedBox(width: 5),
                            Text('Verified Artist', style: GoogleFonts.outfit(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppColors.blueLight, letterSpacing: 0.05)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text('The Neighbourhood',
                            style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.03 * 36,
                                shadows: [const Shadow(color: Colors.black54, blurRadius: 20)])),
                        Text('14.2M monthly listeners',
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _StatItem(value: '14.2M', label: 'Listeners'),
                  _StatItem(value: '28', label: 'Albums'),
                  _StatItem(value: '312', label: 'Songs'),
                  _StatItem(value: '4.8', label: 'Rating'),
                ],
              ),
            ),

            // Play row
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlayerScreen())),
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.glass, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.shuffle_rounded, size: 20, color: AppColors.text2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.purple.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.local_drink_outlined, size: 16, color: AppColors.purpleLight),
                      const SizedBox(width: 8),
                      Text('Buy Tickets', style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                    ]),
                  ),
                ),
              ]),
            ),

            // Popular tracks
            const SectionHeader(title: 'Popular', action: 'See all'),
            const SizedBox(height: 4),
            _TrackRow(rank: '▶', emoji: '🌨',
                gradient: AppColors.gradMixed,
                title: 'Sweater Weather', plays: '428M plays', duration: '3:51', isPlaying: true),
            _TrackRow(rank: '2', emoji: '🌙',
                gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF312e81)]),
                title: 'Afraid', plays: '218M plays', duration: '3:27'),
            _TrackRow(rank: '3', emoji: '🌑',
                gradient: const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF78350f)]),
                title: 'R.I.P. 2 My Youth', plays: '196M plays', duration: '3:14'),
            _TrackRow(rank: '4', emoji: '💙',
                gradient: const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF1e3a8a)]),
                title: 'A Little Death', plays: '182M plays', duration: '4:02'),

            // Similar Artists
            const SizedBox(height: 8),
            const SectionHeader(title: 'Similar Artists'),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                children: const [
                  _SimilarArtist(label: 'The 1975',
                      gradient: LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)])),
                  _SimilarArtist(label: 'Lana Del Rey',
                      gradient: LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)])),
                  _SimilarArtist(label: 'Radiohead',
                      gradient: LinearGradient(colors: [Color(0xFF064e3b), Color(0xFF10b981)])),
                  _SimilarArtist(label: 'Arctic Monkeys',
                      gradient: LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)])),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.purpleLight, AppColors.pink]).createShader(b),
            child: Text(value, style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String rank, emoji, title, plays, duration;
  final LinearGradient gradient;
  final bool isPlaying;
  const _TrackRow({required this.rank, required this.emoji, required this.gradient,
      required this.title, required this.plays, required this.duration, this.isPlaying = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        SizedBox(width: 20,
          child: Text(rank, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isPlaying ? AppColors.purpleLight : AppColors.text3))),
        const SizedBox(width: 14),
        Container(width: 46, height: 46,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(11)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600,
              color: isPlaying ? AppColors.purpleLight : AppColors.text)),
          Text(plays, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        Text(duration, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
      ]),
    );
  }
}

class _SimilarArtist extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  const _SimilarArtist({required this.label, required this.gradient});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(children: [
        Container(width: 68, height: 68,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2))),
        const SizedBox(height: 8),
        SizedBox(width: 72,
          child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
      ]),
    );
  }
}
