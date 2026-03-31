import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _filter = 0;
  final _filters = ['All', 'Playlists', 'Albums', 'Artists', 'Downloaded'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Your Library', style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: AppColors.text, letterSpacing: -0.02 * 26)),
                    Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.glass,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border)),
                        child: const Icon(Icons.list_rounded, size: 18, color: AppColors.text2)),
                      const SizedBox(width: 8),
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradPurple,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.purple),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setState(() => _filter = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: _filter == i ? AppColors.gradPurple : null,
                            color: _filter == i ? null : AppColors.glass,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: _filter == i ? AppColors.purple : AppColors.border),
                          ),
                          child: Text(_filters[i], style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _filter == i ? Colors.white : AppColors.text2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _SepLabel('Pinned'),
                  _LibItem(emoji: '🎧', gradient: AppColors.gradMixed,
                      name: 'Liked Songs', meta: 'Playlist · 847 songs',
                      badge: _Badge('Downloaded', AppColors.green)),
                  _LibItem(emoji: '❄️',
                      gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed)]),
                      name: 'Winter Nights', meta: 'Playlist · 18 songs · With Daniyar',
                      badge: _Badge('Collab', AppColors.blue)),
                  _SepLabel('Recently Added'),
                  _LibItem(emoji: '🌊',
                      gradient: const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF06b6d4)]),
                      name: 'Snow Day', meta: 'Playlist · Weather Mix · 24 songs',
                      badge: _Badge('New', AppColors.purple)),
                  _LibItem(emoji: '🌧',
                      gradient: const LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
                      name: 'I Love You.', meta: 'Album · The Neighbourhood',
                      badge: _Badge('Downloaded', AppColors.green)),
                  _LibItem(emoji: '🎵',
                      gradient: const LinearGradient(colors: [Color(0xFF065f46), Color(0xFF10b981)]),
                      name: 'Chill Evening', meta: 'Playlist · AI Generated · 20 songs',
                      badge: _Badge('AI', AppColors.purple)),
                  _LibItem(emoji: '🎤',
                      gradient: const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                      name: 'The Neighbourhood', meta: 'Artist · 14.2M listeners'),
                  _LibItem(emoji: '☀️',
                      gradient: const LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)]),
                      name: 'Summer Hits 2024', meta: 'Playlist · 56 songs'),
                  _LibItem(emoji: '🎸',
                      gradient: const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                      name: 'I Like It When You Sleep', meta: 'Album · The 1975',
                      badge: _Badge('Downloaded', AppColors.green)),
                  _LibItem(emoji: '🎹',
                      gradient: const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]),
                      name: 'Study Session', meta: 'Playlist · Lo-fi · 40 songs'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SepLabel extends StatelessWidget {
  final String label;
  const _SepLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(label.toUpperCase(), style: GoogleFonts.outfit(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.text3, letterSpacing: 0.1)),
  );
}

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

class _LibItem extends StatelessWidget {
  final String emoji, name, meta;
  final LinearGradient gradient;
  final _Badge? badge;
  const _LibItem({required this.emoji, required this.gradient,
      required this.name, required this.meta, this.badge});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(children: [
        Container(width: 54, height: 54,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(meta, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badge!.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: badge!.color.withOpacity(0.2)),
            ),
            child: Text(badge!.label, style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700, color: badge!.color)),
          ),
      ]),
    );
  }
}
