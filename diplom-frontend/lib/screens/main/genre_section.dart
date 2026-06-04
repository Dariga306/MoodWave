import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../genre_tracks_screen.dart';

class _GenreData {
  final String name;
  final String subtitle;
  final String emoji;
  final LinearGradient gradient;
  final Color accentColor;
  final String artUrl;
  final Alignment imageAlignment;

  const _GenreData({
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.accentColor,
    required this.artUrl,
    this.imageAlignment = Alignment.center,
  });
}

const _genres = [
  _GenreData(
    name: 'Pop',
    subtitle: 'Catchy & bright',
    emoji: '🎤',
    gradient: LinearGradient(
      colors: [Color(0xFFFF4D9D), Color(0xFFB026FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF4D9D),
    artUrl: 'assets/images/genres/01_pop.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Rock',
    subtitle: 'Raw & loud',
    emoji: '🎸',
    gradient: LinearGradient(
      colors: [Color(0xFFFF3B5C), Color(0xFF7B2FF7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF3B5C),
    artUrl: 'assets/images/genres/02_rock.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Hip-Hop',
    subtitle: 'Beats & bars',
    emoji: '🎙',
    gradient: LinearGradient(
      colors: [Color(0xFFFF8A3D), Color(0xFF9D3CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF8A3D),
    artUrl: 'assets/images/genres/03_hiphop.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Electronic',
    subtitle: 'Pulse & energy',
    emoji: '🎛',
    gradient: LinearGradient(
      colors: [Color(0xFF22D3EE), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF22D3EE),
    artUrl: 'assets/images/genres/04_electronic.jpg',
    imageAlignment: Alignment.center,
  ),
  _GenreData(
    name: 'Jazz',
    subtitle: 'Smooth & soulful',
    emoji: '🎷',
    gradient: LinearGradient(
      colors: [Color(0xFFFFB13D), Color(0xFFC2710C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFB13D),
    artUrl: 'assets/images/genres/05_jazz.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'K-Pop',
    subtitle: 'Bright & bold',
    emoji: '✨',
    gradient: LinearGradient(
      colors: [Color(0xFFFF5FAE), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF5FAE),
    artUrl: 'assets/images/genres/06_kpop.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'R&B',
    subtitle: 'Soul & rhythm',
    emoji: '🕊',
    gradient: LinearGradient(
      colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFA855F7),
    artUrl: 'assets/images/genres/07_rnb.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Latin',
    subtitle: 'Heat & rhythm',
    emoji: '💃',
    gradient: LinearGradient(
      colors: [Color(0xFFFF5E62), Color(0xFFFFA63D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF5E62),
    artUrl: 'assets/images/genres/08_latin.jpg',
    imageAlignment: Alignment.center,
  ),
  _GenreData(
    name: 'Indie',
    subtitle: 'Fresh & free',
    emoji: '🌿',
    gradient: LinearGradient(
      colors: [Color(0xFF2BD4A0), Color(0xFF5B7CFA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF2BD4A0),
    artUrl: 'assets/images/genres/09_indie.jpg',
    imageAlignment: Alignment.center,
  ),
  _GenreData(
    name: 'Afrobeat',
    subtitle: 'Drums & soul',
    emoji: '🥁',
    gradient: LinearGradient(
      colors: [Color(0xFFFFC23D), Color(0xFFFF5E3A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFC23D),
    artUrl: 'assets/images/genres/10_afrobeat.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Classical',
    subtitle: 'Timeless masterpieces',
    emoji: '🎻',
    gradient: LinearGradient(
      colors: [Color(0xFF4D8DF7), Color(0xFF1E3A8A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF4D8DF7),
    artUrl: 'assets/images/genres/11_classical.jpg',
    imageAlignment: Alignment.center,
  ),
  _GenreData(
    name: 'Country',
    subtitle: 'Roads & roots',
    emoji: '🤠',
    gradient: LinearGradient(
      colors: [Color(0xFFE8A23D), Color(0xFF7FA63D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFE8A23D),
    artUrl: 'assets/images/genres/12_country.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Metal',
    subtitle: 'Heavy & fierce',
    emoji: '🤘',
    gradient: LinearGradient(
      colors: [Color(0xFFFF3B30), Color(0xFF3A0A0A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF3B30),
    artUrl: 'assets/images/genres/13_metal.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Blues',
    subtitle: 'Deep & moody',
    emoji: '🎼',
    gradient: LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1E1B4B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF3B82F6),
    artUrl: 'assets/images/genres/14_blues.jpg',
    imageAlignment: Alignment.topCenter,
  ),
  _GenreData(
    name: 'Lo-Fi',
    subtitle: 'Calm & cozy',
    emoji: '🌙',
    gradient: LinearGradient(
      colors: [Color(0xFFB79CFF), Color(0xFF7C5CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFB79CFF),
    artUrl: 'assets/images/genres/15_lofi.jpg',
    imageAlignment: Alignment.center,
  ),
  _GenreData(
    name: 'Reggaeton',
    subtitle: 'Dembow & dance',
    emoji: '🔥',
    gradient: LinearGradient(
      colors: [Color(0xFFFF4FA3), Color(0xFFFF8A3D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF4FA3),
    artUrl: 'assets/images/genres/16_reggaeton.jpg',
    imageAlignment: Alignment.center,
  ),
];

const _svgPfx =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">';
const _svgSfx = '</svg>';

const _genreSvgData = <String, String>{
  'Pop':
      '$_svgPfx<rect x="9" y="2.5" width="6" height="11" rx="3"/><path d="M6 10.5a6 6 0 0 0 12 0"/><line x1="12" y1="16.5" x2="12" y2="21"/><line x1="8.5" y1="21" x2="15.5" y2="21"/>$_svgSfx',
  'Rock':
      '$_svgPfx<path d="M12 3.5c3.6 0 6.5 2.2 6.5 5.4 0 4-3.6 11.6-6.5 11.6S5.5 12.9 5.5 8.9C5.5 5.7 8.4 3.5 12 3.5Z"/>$_svgSfx',
  'Hip-Hop':
      '$_svgPfx<path d="M4 13v-1a8 8 0 0 1 16 0v1"/><rect x="3" y="13" width="4.5" height="6.5" rx="1.6"/><rect x="16.5" y="13" width="4.5" height="6.5" rx="1.6"/>$_svgSfx',
  'Electronic':
      '$_svgPfx<line x1="6" y1="4" x2="6" y2="20"/><line x1="12" y1="4" x2="12" y2="20"/><line x1="18" y1="4" x2="18" y2="20"/><circle cx="6" cy="9" r="2" fill="#FFFFFF"/><circle cx="12" cy="15" r="2" fill="#FFFFFF"/><circle cx="18" cy="8" r="2" fill="#FFFFFF"/>$_svgSfx',
  'Jazz':
      '$_svgPfx<circle cx="8" cy="17.5" r="2.6"/><path d="M10.6 17.5V5l7.4-1.7v4"/>$_svgSfx',
  'K-Pop':
      '$_svgPfx<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3Z"/><path d="M18.5 15.5l.6 1.9 1.9.6-1.9.6-.6 1.9-.6-1.9-1.9-.6 1.9-.6.6-1.9Z"/>$_svgSfx',
  'R&B':
      '$_svgPfx<circle cx="7" cy="18" r="2.4"/><circle cx="16.5" cy="16" r="2.4"/><path d="M9.4 18V6l9.5-2v12"/>$_svgSfx',
  'Latin':
      '$_svgPfx<line x1="5" y1="10" x2="5" y2="14"/><line x1="9" y1="6.5" x2="9" y2="17.5"/><line x1="13" y1="3.5" x2="13" y2="20.5"/><line x1="17" y1="7" x2="17" y2="17"/><line x1="21" y1="10" x2="21" y2="14"/>$_svgSfx',
  'Indie':
      '$_svgPfx<path d="M12 21v-8"/><path d="M12 13c0-3-2.2-5-5.2-5C6.8 11 9 13 12 13Z"/><path d="M12 11c0-3 2.2-5 5.2-5C17.2 9 15 11 12 11Z"/>$_svgSfx',
  'Afrobeat':
      '$_svgPfx<path d="M5 9c0-1.7 3.1-3 7-3s7 1.3 7 3-3.1 3-7 3-7-1.3-7-3Z"/><path d="M5 9v5c0 1.7 3.1 3 7 3s7-1.3 7-3V9"/><line x1="14.5" y1="10.5" x2="20" y2="5"/><line x1="9.5" y1="10.5" x2="4" y2="5"/>$_svgSfx',
  'Classical':
      '$_svgPfx<rect x="4" y="6" width="16" height="12" rx="1.5"/><line x1="9" y1="6" x2="9" y2="13"/><line x1="14" y1="6" x2="14" y2="13"/>$_svgSfx',
  'Country':
      '$_svgPfx<path d="M7 14c-.4-3 .2-8 1.4-8.4C9.4 5.3 9.8 7 12 7s2.6-1.7 3.6-1.4C16.8 6 17.4 11 17 14"/><path d="M3 14.5c0 1.4 4 2.4 9 2.4s9-1 9-2.4c0-.9-1.7-1.6-4.2-2"/>$_svgSfx',
  'Metal': '$_svgPfx<path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z"/>$_svgSfx',
  'Blues': '$_svgPfx<path d="M3 12c2-5 4-5 6 0s4 5 6 0 4-5 6 0"/>$_svgSfx',
  'Lo-Fi':
      '$_svgPfx<path d="M20 14.5A8 8 0 1 1 9.5 4 6.5 6.5 0 0 0 20 14.5Z"/><path d="M17.5 4l.6 1.7 1.7.6-1.7.6-.6 1.7-.6-1.7-1.7-.6 1.7-.6.6-1.7Z"/>$_svgSfx',
  'Reggaeton':
      '$_svgPfx<path d="M12 3c1 2.6-1 3.8-1 5.8 0 1.1.7 2 1.7 2 1.3 0 1.9-1.3 1.4-2.9 2 1.1 2.9 3.1 2.9 5.1a5 5 0 0 1-10 0c0-2.9 1.9-4.8 3-6.8.7-1.4 1.2-2.4 1-3.2Z"/>$_svgSfx',
};

class GenreSection extends StatelessWidget {
  const GenreSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.42,
        ),
        itemCount: _genres.length,
        itemBuilder: (ctx, i) => _GenreCard(data: _genres[i], index: i),
      ),
    );
  }
}

class _GenreCard extends StatefulWidget {
  final _GenreData data;
  final int index;

  const _GenreCard({required this.data, required this.index});

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hovered = false;
  bool _iconPressed = false;

  Future<void> _openGenre() async {
    setState(() => _iconPressed = true);
    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    setState(() => _iconPressed = false);
    final data = widget.data;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenreTracksScreen(
          genre: data.name,
          emoji: data.emoji,
          gradient: data.gradient,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final active = _hovered || _iconPressed;
    final pressed = _iconPressed;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _iconPressed = false;
          }),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _iconPressed = true),
            onTapUp: (_) => _openGenre(),
            onTapCancel: () => setState(() => _iconPressed = false),
            child: AnimatedScale(
              scale: _iconPressed ? 0.975 : (active ? 1.035 : 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: pressed
                          ? data.accentColor.withValues(alpha: 0.58)
                          : Colors.black
                              .withValues(alpha: active ? 0.36 : 0.24),
                      blurRadius: pressed ? 34 : (active ? 24 : 16),
                      spreadRadius: pressed ? 1 : 0,
                      offset: Offset(0, active ? 12 : 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: active ? 1.11 : 1.02,
                        duration: const Duration(milliseconds: 620),
                        curve: Curves.easeOutCubic,
                        child: Image.asset(
                          data.artUrl,
                          fit: BoxFit.cover,
                          alignment: data.imageAlignment,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(gradient: data.gradient),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              data.accentColor.withValues(alpha: 0.12),
                              data.gradient.colors.last.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              data.accentColor
                                  .withValues(alpha: pressed ? 0.30 : 0.0),
                              data.gradient.colors.last
                                  .withValues(alpha: pressed ? 0.18 : 0.0),
                            ],
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22000000),
                              Color(0x00000000),
                              Color(0x55000000),
                              Color(0xCC000000),
                            ],
                            stops: [0.0, 0.22, 0.50, 1.0],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: AnimatedRotation(
                          turns: active ? -6 / 360 : 0.0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: AnimatedScale(
                            scale: active ? 1.20 : 1.0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                            child: _genreSvgData.containsKey(data.name)
                                ? SvgPicture.string(
                                    _genreSvgData[data.name]!,
                                    width: 22,
                                    height: 22,
                                  )
                                : Text(
                                    data.emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: 12,
                        right: 12,
                        bottom: active ? 14 : 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 20,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                      color: Color(0x99000000), blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.80),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play button — bottom-right corner
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: AnimatedOpacity(
                          opacity: active ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedScale(
                            scale: active ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.92),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 8,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.black87, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
