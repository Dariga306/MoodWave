import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/artist_screen.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

// ── STATUS BAR ──
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41',
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
          Row(children: [
            Icon(Icons.signal_cellular_alt, size: 16, color: AppColors.text),
            const SizedBox(width: 4),
            Icon(Icons.wifi, size: 16, color: AppColors.text),
            const SizedBox(width: 4),
            Icon(Icons.battery_full, size: 16, color: AppColors.text),
          ]),
        ],
      ),
    );
  }
}

// ── GLASS CARD ──
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  const GlassCard({super.key, required this.child, this.padding, this.borderRadius});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── SECTION HEADER ──
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.purpleLight)),
            ),
        ],
      ),
    );
  }
}

// ── GENRE PILL ──
class GenrePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const GenrePill({super.key, required this.label, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? AppColors.gradPurple : null,
          color: active ? null : AppColors.glass,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? AppColors.purple : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.text)),
      ),
    );
  }
}

// ── GRADIENT TEXT ──
class GradientText extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle? style;
  const GradientText(this.text, {super.key, required this.gradient, this.style});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

// ── ICON BUTTON ──
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  const AppIconButton({super.key, required this.icon, this.onTap, this.iconColor});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? AppColors.text2),
      ),
    );
  }
}

// ── PRIMARY BUTTON ──
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double? borderRadius;
  const PrimaryButton({super.key, required this.text, this.onTap, this.gradient, this.borderRadius});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.primaryBtn,
          borderRadius: BorderRadius.circular(borderRadius ?? 18),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleDark.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

// ── ANIMATED BARS (for music visualization) ──
class AnimatedMusicBars extends StatefulWidget {
  final Color color1;
  final Color color2;
  final int barCount;
  final double barWidth;
  final double maxHeight;
  const AnimatedMusicBars({
    super.key,
    this.color1 = AppColors.purpleLight,
    this.color2 = AppColors.pink,
    this.barCount = 4,
    this.barWidth = 3,
    this.maxHeight = 24,
  });
  @override
  State<AnimatedMusicBars> createState() => _AnimatedMusicBarsState();
}

class _AnimatedMusicBarsState extends State<AnimatedMusicBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  static const List<double> _delays = [0.0, 0.15, 0.3, 0.1];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.barCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 80)),
      )..repeat(reverse: true),
    );
    _animations = List.generate(
      widget.barCount,
      (i) => Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.barCount, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Container(
            width: widget.barWidth,
            height: widget.maxHeight * _animations[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [widget.color1, widget.color2],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ── TRACK OPTIONS MENU ──────────────────────────────────────────────────────
/// Show a shared bottom-sheet track menu.
/// Navigation callbacks are provided by the caller to avoid circular imports.
Future<void> _showAddToPlaylistDialog(
    BuildContext context, Map<String, dynamic> track) async {
  List<Map<String, dynamic>> playlists = [];
  bool loading = true;
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1a1a2e),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        if (loading) {
          ApiService().getPlaylists().then((raw) {
            setS(() {
              playlists = raw.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              loading = false;
            });
          }).catchError((e) {
            setS(() { error = 'Could not load playlists'; loading = false; });
          });
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(100))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Add to Playlist',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white10, height: 1),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight),
                )
              else if (error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!,
                      style: GoogleFonts.outfit(color: AppColors.text3)),
                )
              else if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No playlists yet. Create one in Library.',
                      style: GoogleFonts.outfit(color: AppColors.text3)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      final name = pl['title'] as String? ?? 'Playlist';
                      final count = pl['track_count'] as int? ?? 0;
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                              child: Text('🎵', style: TextStyle(fontSize: 18))),
                        ),
                        title: Text(name,
                            style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        subtitle: Text('$count songs',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.text3)),
                        onTap: () async {
                          final id = pl['id'] as int?;
                          if (id == null) return;
                          Navigator.pop(ctx);
                          try {
                            await ApiService().addTrackToPlaylist(id, {
                              'spotify_track_id': track['spotify_id']?.toString() ??
                                  track['deezer_id']?.toString() ?? '',
                              'title': track['title']?.toString() ?? '',
                              'artist': track['artist']?.toString() ?? '',
                              'album': track['album']?.toString(),
                              'cover_url': track['cover_url']?.toString(),
                              'preview_url': track['preview_url']?.toString(),
                              'duration_ms': track['duration_ms'] as int?,
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Added to $name',
                                    style: GoogleFonts.outfit(color: Colors.white)),
                                backgroundColor: AppColors.purpleDark,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Track already in playlist or error',
                                    style: GoogleFonts.outfit(color: Colors.white)),
                                backgroundColor: const Color(0xFF3d0000),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

void showTrackMenu(
  BuildContext context,
  Map<String, dynamic> track, {
  required VoidCallback onPlayNow,
  VoidCallback? onGoToArtist,
  VoidCallback? onViewAlbum,
  VoidCallback? onAddToPlaylist,
  VoidCallback? onDontPlay,
}) {
  final title = track['title']?.toString() ?? 'Track';
  final artist = track['artist']?.toString() ?? '';
  final previewUrl = track['preview_url']?.toString();
  bool liked = false;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1a1a2e),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (artist.isNotEmpty)
                    Text(artist,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.text3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            _TrackMenuItem(
              icon: Icons.play_circle_outline_rounded,
              label: 'Play now',
              onTap: () {
                Navigator.pop(ctx);
                onPlayNow();
              },
            ),
            // Like / Save
            ListTile(
              leading: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: liked ? Colors.pinkAccent : Colors.white70,
                size: 22,
              ),
              title: Text(
                liked ? 'Saved to Liked Songs' : 'Save to Liked Songs',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: liked ? Colors.pinkAccent : Colors.white),
              ),
              onTap: () {
                final id = track['spotify_id']?.toString() ?? '';
                if (id.isEmpty) return;
                ApiService()
                    .likeTrack(id, title: title, artist: artist)
                    .then((_) => setS(() => liked = !liked))
                    .catchError((_) {});
              },
            ),
            _TrackMenuItem(
              icon: Icons.queue_music_rounded,
              label: 'Add to queue',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Added to queue',
                      style: GoogleFonts.outfit(color: Colors.white)),
                  backgroundColor: AppColors.purpleDark,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
            _TrackMenuItem(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistDialog(context, track);
              },
            ),
            if (artist.isNotEmpty)
              _TrackMenuItem(
                icon: Icons.person_rounded,
                label: 'Go to artist',
                onTap: () async {
                  Navigator.pop(ctx);
                  if (onGoToArtist != null) {
                    onGoToArtist();
                    return;
                  }
                  final artistId = track['artist_id']?.toString() ?? '';
                  if (artistId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ArtistScreen(
                          artistId: artistId, artistName: artist),
                    ));
                    return;
                  }
                  try {
                    final results = await ApiService()
                        .searchArtistsList(artist, limit: 1);
                    if (results.isNotEmpty) {
                      final id = results.first['id']?.toString() ?? '';
                      if (id.isNotEmpty && context.mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ArtistScreen(
                              artistId: id, artistName: artist),
                        ));
                        return;
                      }
                    }
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Artist not found',
                            style: GoogleFonts.outfit(color: Colors.white)),
                        backgroundColor: AppColors.purpleDark,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            if (onViewAlbum != null)
              _TrackMenuItem(
                icon: Icons.album_rounded,
                label: 'View album',
                onTap: () {
                  Navigator.pop(ctx);
                  onViewAlbum();
                },
              ),
            _TrackMenuItem(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: '$title — $artist'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            if (onDontPlay != null)
              _TrackMenuItem(
                icon: Icons.do_not_disturb_alt_outlined,
                label: "Don't play this",
                onTap: () {
                  Navigator.pop(ctx);
                  onDontPlay();
                },
                color: Colors.redAccent.withOpacity(0.85),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _TrackMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _TrackMenuItem(
      {required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: GoogleFonts.outfit(fontSize: 15, color: color ?? Colors.white)),
      onTap: onTap,
    );
  }
}
