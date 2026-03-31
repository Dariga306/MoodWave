import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: AppColors.bg2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Up Next', style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.text, letterSpacing: -0.02 * 22)),
                      Text('Clear all', style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          // Now playing
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.purpleDark.withOpacity(0.12),
                  AppColors.pink.withOpacity(0.08),
                ]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.purple.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Center(child: Text('🌨', style: TextStyle(fontSize: 26)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NOW PLAYING', style: GoogleFonts.outfit(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.purpleLight, letterSpacing: 0.1)),
                  const SizedBox(height: 4),
                  Text('Sweater Weather', style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text('The Neighbourhood · 1:24 / 3:51',
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                ])),
              ]),
            ),
          ),
          // Shuffle/Repeat row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              _CtrlBtn(icon: Icons.shuffle_rounded, active: true),
              const SizedBox(width: 6),
              _CtrlBtn(icon: Icons.repeat_rounded, active: true),
              const SizedBox(width: 4),
              Text('Shuffle · Repeat', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              const Spacer(),
              Text('6 songs left', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('UP NEXT — WINTER NIGHTS PLAYLIST',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.text3, letterSpacing: 0.1)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                _QueueItem(emoji: '🌙',
                    gradient: LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF06b6d4)]),
                    title: 'Snowfall', artist: 'NIKI', duration: '3:18'),
                _QueueItem(emoji: '⭐',
                    gradient: LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                    title: 'Somebody Else', artist: 'The 1975', duration: '5:02'),
                _QueueItem(emoji: '🌿', gradient: AppColors.gradTeal,
                    title: 'Midnight Rain', artist: 'Taylor Swift', duration: '3:42'),
                _QueueItem(emoji: '✨', gradient: AppColors.gradOrange,
                    title: 'Superstar', artist: 'Lorde', duration: '3:26'),
                _QueueItem(emoji: '🎸',
                    gradient: LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
                    title: 'R U Mine?', artist: 'Arctic Monkeys', duration: '3:21'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _CtrlBtn({required this.icon, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
      child: Icon(icon, size: 14, color: active ? AppColors.purpleLight : AppColors.text2),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final String emoji, title, artist, duration;
  final LinearGradient gradient;
  const _QueueItem({required this.emoji, required this.gradient,
      required this.title, required this.artist, required this.duration});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(children: [
        const Icon(Icons.drag_handle_rounded, size: 16, color: AppColors.text3),
        const SizedBox(width: 8),
        Container(width: 44, height: 44,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(11)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              overflow: TextOverflow.ellipsis),
          Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        Text(duration, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        const SizedBox(width: 8),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (_) => Container(
          width: 3, height: 3, margin: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: const BoxDecoration(color: AppColors.text3, shape: BoxShape.circle)))),
      ]),
    );
  }
}
