import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class QueueScreen extends StatelessWidget {
  final String? currentTitle;
  final String? currentArtist;
  final String? currentCover;
  final List<Map<String, dynamic>> queue;
  final int currentIndex;

  const QueueScreen({
    super.key,
    this.currentTitle,
    this.currentArtist,
    this.currentCover,
    this.queue = const [],
    this.currentIndex = 0,
  });

  String _fmt(dynamic durationMs) {
    final ms =
        durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (ms <= 0) return '';
    return '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = currentTitle ?? 'Unknown';
    final artist = currentArtist ?? '';
    final upNext = queue.asMap().entries
        .where((e) => e.key > currentIndex)
        .map((e) => e.value)
        .toList();

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Up Next',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.02 * 22,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purpleLight,
                        ),
                      ),
                    ),
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
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: currentCover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.network(
                            currentCover!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Text('🎵', style: TextStyle(fontSize: 22))),
                          ),
                        )
                      : const Center(child: Text('🎵', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOW PLAYING',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purpleLight,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist.isNotEmpty)
                        Text(
                          artist,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.text2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          // Shuffle/Repeat row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              _CtrlBtn(icon: Icons.shuffle_rounded, active: false),
              const SizedBox(width: 6),
              _CtrlBtn(icon: Icons.repeat_rounded, active: false),
              const SizedBox(width: 4),
              Text('Shuffle · Repeat',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              const Spacer(),
              if (upNext.isNotEmpty)
                Text('${upNext.length} songs left',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          if (upNext.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'UP NEXT',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          Expanded(
            child: upNext.isEmpty
                ? Center(
                    child: Text(
                      'Queue is empty',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: AppColors.text3,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: upNext.length,
                    itemBuilder: (context, index) {
                      final track = upNext[index];
                      final trackTitle =
                          track['title']?.toString() ?? track['trackName']?.toString() ?? 'Unknown';
                      final trackArtist =
                          track['artist']?.toString() ?? track['artistName']?.toString() ?? '';
                      final duration = _fmt(track['duration_ms']);
                      final coverUrl = track['cover_url']?.toString() ?? track['artworkUrl100']?.toString();

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(track: track),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0x08FFFFFF)),
                            ),
                          ),
                          child: Row(children: [
                            const Icon(Icons.drag_handle_rounded,
                                size: 16, color: AppColors.text3),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: coverUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.network(
                                        coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Text('🎵', style: TextStyle(fontSize: 18)),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('🎵', style: TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trackTitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (trackArtist.isNotEmpty)
                                    Text(
                                      trackArtist,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.text2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (duration.isNotEmpty)
                              Text(
                                duration,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.text3,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (_) => Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                                  decoration: const BoxDecoration(
                                    color: AppColors.text3,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          size: 14, color: active ? AppColors.purpleLight : AppColors.text2),
    );
  }
}
