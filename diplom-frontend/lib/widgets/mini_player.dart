import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../utils/app_navigator.dart';

class MiniPlayerOverlayController {
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
  static final ValueNotifier<double> bottomOffset = ValueNotifier<double>(0);
  static final ValueNotifier<bool> topMode = ValueNotifier<bool>(false);
  static int _hideCount = 0;
  static int _suppressCount = 0;
  static int _topCount = 0;

  // Direct reference to the overlay state so _syncHidden can force a rebuild
  // immediately, bypassing any ValueListenableBuilder scheduling delay.
  static _GlobalMiniPlayerOverlayState? _overlayState;

  static void _syncHidden() {
    hidden.value = _hideCount > 0 || _suppressCount > 0;
    _overlayState?._forceRebuild();
  }

  static void hide() {
    _hideCount++;
    _syncHidden();
  }

  static void show() {
    if (_hideCount > 0) _hideCount--;
    _syncHidden();
  }

  static void suppress() {
    _suppressCount++;
    _syncHidden();
  }

  static void unsuppress() {
    if (_suppressCount > 0) _suppressCount--;
    _syncHidden();
  }

  static void forceVisible() {
    _hideCount = 0;
    _syncHidden();
  }

  static void setBottomOffset(double value) {
    bottomOffset.value = value;
    _overlayState?._forceRebuild();
  }

  static void pushTopMode() {
    _topCount++;
    topMode.value = _topCount > 0;
    _overlayState?._forceRebuild();
  }

  static void popTopMode() {
    if (_topCount > 0) _topCount--;
    topMode.value = _topCount > 0;
    _overlayState?._forceRebuild();
  }
}

class GlobalMiniPlayerOverlay extends StatefulWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  State<GlobalMiniPlayerOverlay> createState() =>
      _GlobalMiniPlayerOverlayState();
}

class _GlobalMiniPlayerOverlayState extends State<GlobalMiniPlayerOverlay> {
  @override
  void initState() {
    super.initState();
    MiniPlayerOverlayController._overlayState = this;
  }

  @override
  void dispose() {
    if (MiniPlayerOverlayController._overlayState == this) {
      MiniPlayerOverlayController._overlayState = null;
    }
    super.dispose();
  }

  void _forceRebuild() {
    if (!mounted) return;
    // Defer setState to avoid "setState called during build" when suppress()
    // is invoked from a screen's initState (which runs inside the build phase).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MiniPlayerOverlayController.hidden.value) return const SizedBox.shrink();
    final padding = MediaQuery.of(context).padding;
    final bOffset = MiniPlayerOverlayController.bottomOffset.value;
    final tMode = MiniPlayerOverlayController.topMode.value;
    final effectiveBottomOffset = tMode ? 0.0 : (bOffset <= 0 ? 74.0 : bOffset);
    return Positioned(
      left: 0,
      right: 0,
      top: tMode ? padding.top + 8 : null,
      bottom: tMode ? null : padding.bottom + effectiveBottomOffset,
      child: const Material(
        color: Colors.transparent,
        child: MiniPlayer(),
      ),
    );
  }
}

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _dragOffsetY = 0;
  double _dragOffsetX = 0;
  bool _dismissing = false;

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy.abs() > d.delta.dx.abs()) {
      if (d.delta.dy > 0) setState(() => _dragOffsetY += d.delta.dy);
    } else {
      setState(() => _dragOffsetX += d.delta.dx);
    }
  }

  void _onDragEnd(DragEndDetails d, PlayerProvider provider) {
    final velY = d.primaryVelocity ?? 0;
    final velX = d.velocity.pixelsPerSecond.dx;

    if (_dragOffsetY.abs() > _dragOffsetX.abs()) {
      // Vertical drag — dismiss
      if (velY > 250 || _dragOffsetY > 60) {
        setState(() => _dismissing = true);
        Future.delayed(const Duration(milliseconds: 180), () {
          provider.stop();
          if (mounted) {
            setState(() {
              _dragOffsetY = 0;
              _dismissing = false;
            });
          }
        });
      } else {
        setState(() => _dragOffsetY = 0);
      }
    } else {
      // Horizontal drag — skip track
      if (velX < -400 || _dragOffsetX < -60) {
        provider.nextTrack();
      } else if (velX > 400 || _dragOffsetX > 60) {
        provider.prevTrack();
      }
      setState(() => _dragOffsetX = 0);
    }
    setState(() {
      _dragOffsetY = 0;
      _dragOffsetX = 0;
    });
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
              : Offset(_dragOffsetX / 300, _dragOffsetY / 200),
          duration:
              _dismissing ? const Duration(milliseconds: 200) : Duration.zero,
          child: GestureDetector(
            onTap: () {
              rootNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              );
            },
            onPanUpdate: _onDragUpdate,
            onPanEnd: (d) => _onDragEnd(d, provider),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              height: 66,
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
                    // Progress bar at bottom
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: FractionallySizedBox(
                        widthFactor: provider.progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.purple, AppColors.purpleLight],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Track row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
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
                            onTap: () => provider.togglePlayPause(),
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
                            onTap: () => provider.stop(),
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
