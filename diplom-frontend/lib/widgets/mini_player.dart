import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _dismissing = false;

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy > 0) {
      setState(() => _dragOffset += d.delta.dy);
    }
  }

  void _onDragEnd(DragEndDetails d, PlayerProvider provider) {
    final velocity = d.primaryVelocity ?? 0;
    if (velocity > 250 || _dragOffset > 60) {
      setState(() => _dismissing = true);
      Future.delayed(const Duration(milliseconds: 180), () {
        provider.clear();
        if (mounted) setState(() { _dragOffset = 0; _dismissing = false; });
      });
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final track = provider.track;
        if (track == null) return const SizedBox.shrink();

        final title =
            (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
        final artist =
            (track['artist'] ?? track['artistName'] ?? '').toString();
        final coverUrl =
            (track['cover_url'] ?? track['artworkUrl100'])?.toString();

        return AnimatedSlide(
          offset: _dismissing
              ? const Offset(0, 1)
              : Offset(0, _dragOffset / 200),
          duration: _dismissing
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
            ),
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: (d) => _onDragEnd(d, provider),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1040),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purpleDark.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        height: 2,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: coverUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 18)),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Text('🎵',
                                        style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => provider.toggleFromOutside(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryBtn,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                provider.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => provider.clear(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  size: 18, color: AppColors.text3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
