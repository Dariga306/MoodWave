import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import 'mood_tracks_screen.dart';

// ─── Данные настроений ────────────────────────────────────────────────────────

class MoodData {
  final String key;
  final String name;
  final String emoji;
  final String subtitle;
  final String artUrl;
  final LinearGradient gradient;
  final Color glowColor;

  const MoodData({
    required this.key,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.artUrl,
    required this.gradient,
    required this.glowColor,
  });
}

const List<MoodData> allMoods = [
  MoodData(
    key: 'study',
    name: 'Study',
    emoji: '📚',
    subtitle: 'Focus & flow',
    artUrl:
        'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=1400&q=80',
    glowColor: Color(0xFF3b82f6),
    gradient: LinearGradient(
      colors: [Color(0xFF1e3a8a), Color(0xFF2563eb), Color(0xFF60a5fa)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'workout',
    name: 'Workout',
    emoji: '💪',
    subtitle: 'Power up',
    artUrl:
        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1400&q=80',
    glowColor: Color(0xFFf97316),
    gradient: LinearGradient(
      colors: [Color(0xFF7c2d12), Color(0xFFc2410c), Color(0xFFf97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'chill',
    name: 'Chill',
    emoji: '😌',
    subtitle: 'Easy vibes',
    artUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1400&q=80',
    glowColor: Color(0xFF10b981),
    gradient: LinearGradient(
      colors: [Color(0xFF064e3b), Color(0xFF059669), Color(0xFF34d399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'party',
    name: 'Party',
    emoji: '🎉',
    subtitle: 'Let\'s go',
    artUrl:
        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1400&q=80',
    glowColor: Color(0xFFec4899),
    gradient: LinearGradient(
      colors: [Color(0xFF831843), Color(0xFFdb2777), Color(0xFFf472b6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'drive',
    name: 'Drive',
    emoji: '🚗',
    subtitle: 'Open road',
    artUrl:
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1400&q=80',
    glowColor: Color(0xFFa855f7),
    gradient: LinearGradient(
      colors: [Color(0xFF3b0764), Color(0xFF7c3aed), Color(0xFFa78bfa)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'sleep',
    name: 'Sleep',
    emoji: '😴',
    subtitle: 'Deep calm',
    artUrl:
        'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=1400&q=80',
    glowColor: Color(0xFF6366f1),
    gradient: LinearGradient(
      colors: [Color(0xFF0f172a), Color(0xFF1e1b4b), Color(0xFF312e81)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'morning',
    name: 'Morning',
    emoji: '☀️',
    subtitle: 'Fresh start',
    artUrl:
        'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1400&q=80',
    glowColor: Color(0xFFfbbf24),
    gradient: LinearGradient(
      colors: [Color(0xFF78350f), Color(0xFFd97706), Color(0xFFfbbf24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'late_night',
    name: 'Late Night',
    emoji: '🌙',
    subtitle: 'Midnight soul',
    artUrl:
        'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=1400&q=80',
    glowColor: Color(0xFF818cf8),
    gradient: LinearGradient(
      colors: [Color(0xFF030712), Color(0xFF1e1b4b), Color(0xFF4338ca)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'sad',
    name: 'Sad',
    emoji: '🌧️',
    subtitle: 'Feel it all',
    artUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1400&q=80',
    glowColor: Color(0xFF38bdf8),
    gradient: LinearGradient(
      colors: [Color(0xFF0c4a6e), Color(0xFF0369a1), Color(0xFF38bdf8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'romance',
    name: 'Romance',
    emoji: '❤️',
    subtitle: 'Love songs',
    artUrl:
        'https://images.unsplash.com/photo-1518568814500-bf0f8d125f46?w=1400&q=80',
    glowColor: Color(0xFFfb7185),
    gradient: LinearGradient(
      colors: [Color(0xFF881337), Color(0xFFe11d48), Color(0xFFfb7185)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'hype',
    name: 'Hype',
    emoji: '🔥',
    subtitle: 'Maximum energy',
    artUrl:
        'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=1400&q=80',
    glowColor: Color(0xFFfacc15),
    gradient: LinearGradient(
      colors: [Color(0xFF451a03), Color(0xFFb45309), Color(0xFFfacc15)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'meditate',
    name: 'Meditate',
    emoji: '🧘',
    subtitle: 'Inner peace',
    artUrl:
        'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=1400&q=80',
    glowColor: Color(0xFF2dd4bf),
    gradient: LinearGradient(
      colors: [Color(0xFF042f2e), Color(0xFF0f766e), Color(0xFF2dd4bf)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'rainy',
    name: 'Rainy Day',
    emoji: '🌊',
    subtitle: 'Cozy indoors',
    artUrl:
        'https://images.unsplash.com/photo-1519692933481-e162a57d6721?auto=format&fit=crop&w=1400&q=80',
    glowColor: Color(0xFF7dd3fc),
    gradient: LinearGradient(
      colors: [Color(0xFF0c4a6e), Color(0xFF075985), Color(0xFF7dd3fc)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  MoodData(
    key: 'beach',
    name: 'Beach',
    emoji: '🏖️',
    subtitle: 'Summer waves',
    artUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
    glowColor: Color(0xFF34d399),
    gradient: LinearGradient(
      colors: [Color(0xFF022c22), Color(0xFF065f46), Color(0xFF34d399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

// ─── Определяем рекомендованный муд по времени/погоде ─────────────────────

String getRecommendedMoodKey(Map<String, dynamic>? weather) {
  final hour = DateTime.now().hour;
  final desc = (weather?['description'] ?? weather?['condition'] ?? '')
      .toString()
      .toLowerCase();

  if (desc.contains('rain') || desc.contains('drizzle')) return 'rainy';
  if (desc.contains('snow')) return 'sleep';
  if (desc.contains('clear') || desc.contains('sunny')) {
    if (hour >= 6 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 18) return 'beach';
    return 'party';
  }
  if (hour >= 23 || hour < 5) return 'late_night';
  if (hour >= 5 && hour < 9) return 'morning';
  if (hour >= 9 && hour < 14) return 'study';
  if (hour >= 14 && hour < 18) return 'chill';
  if (hour >= 18 && hour < 21) return 'drive';
  return 'party';
}

// ─── Главный экран муда ───────────────────────────────────────────────────────

class MoodScreen extends StatefulWidget {
  final Map<String, dynamic>? weather;
  const MoodScreen({super.key, this.weather});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openMood(MoodData mood) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => MoodTracksScreen(mood: mood),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendedKey = getRecommendedMoodKey(widget.weather);
    final recommended = allMoods.firstWhere((m) => m.key == recommendedKey,
        orElse: () => allMoods[2]);
    final others = allMoods.where((m) => m.key != recommendedKey).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: AppColors.bg,
            pinned: true,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF150825), AppColors.bg],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryBtn.createShader(bounds),
                          child: Text(
                            'Choose Your Mood',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${allMoods.length} moods curated for the moment',
                          style: GoogleFonts.sora(
                              fontSize: 13, color: AppColors.text3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Рекомендованный муд (большая карточка) ───────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: recommended.glowColor,
                            boxShadow: [
                              BoxShadow(
                                  color: recommended.glowColor.withOpacity(0.8),
                                  blurRadius: 6)
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Perfect for right now',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _RecommendedCard(
                    mood: recommended,
                    onTap: () => _openMood(recommended),
                    weather: widget.weather,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All moods',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text3,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ─── Сетка всех настроений ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _MoodCard(
                  mood: others[i],
                  onTap: () => _openMood(others[i]),
                  animDelay: Duration(milliseconds: 40 * i),
                ),
                childCount: others.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Большая рекомендованная карточка ────────────────────────────────────────

class _RecommendedCard extends StatefulWidget {
  final MoodData mood;
  final VoidCallback onTap;
  final Map<String, dynamic>? weather;

  const _RecommendedCard({
    required this.mood,
    required this.onTap,
    this.weather,
  });

  @override
  State<_RecommendedCard> createState() => _RecommendedCardState();
}

class _RecommendedCardState extends State<_RecommendedCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: mood.glowColor.withOpacity(_pressed ? 0.2 : 0.35),
                blurRadius: 28,
                spreadRadius: _pressed ? 0 : 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: mood.artUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(gradient: mood.gradient),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.08),
                        mood.gradient.colors[0].withOpacity(0.52),
                        mood.gradient.colors.last.withOpacity(0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // Декоративный круг
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),

                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mood.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 31,
                            height: 0.98,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mood.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Карточка настроения (сетка) ──────────────────────────────────────────────

class _MoodCard extends StatefulWidget {
  final MoodData mood;
  final VoidCallback onTap;
  final Duration animDelay;

  const _MoodCard({
    required this.mood,
    required this.onTap,
    required this.animDelay,
  });

  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    Future.delayed(widget.animDelay, () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: mood.glowColor.withOpacity(_pressed ? 0.1 : 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: mood.artUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: BoxDecoration(gradient: mood.gradient),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(gradient: mood.gradient),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.22),
                            Colors.black.withOpacity(0.76),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            mood.gradient.colors.first.withOpacity(0.30),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 11,
                      left: 13,
                      right: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mood.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mood.subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
