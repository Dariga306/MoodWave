import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
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
  final Alignment imageAlignment;

  const MoodData({
    required this.key,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.artUrl,
    required this.gradient,
    required this.glowColor,
    this.imageAlignment = Alignment.center,
  });
}

const List<MoodData> allMoods = [
  MoodData(
    key: 'study',
    name: 'Study',
    emoji: '📚',
    subtitle: 'Focus & flow',
    artUrl: 'assets/images/moods/01_study.jpg',
    glowColor: Color(0xFF3b82f6),
    gradient: LinearGradient(
      colors: [Color(0xFF1e3a8a), Color(0xFF2563eb), Color(0xFF60a5fa)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'workout',
    name: 'Workout',
    emoji: '💪',
    subtitle: 'Power up',
    artUrl: 'assets/images/moods/02_workout.jpg',
    glowColor: Color(0xFFf97316),
    gradient: LinearGradient(
      colors: [Color(0xFF7c2d12), Color(0xFFc2410c), Color(0xFFf97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'chill',
    name: 'Chill',
    emoji: '😌',
    subtitle: 'Easy vibes',
    artUrl: 'assets/images/moods/03_chill.jpg',
    glowColor: Color(0xFF10b981),
    gradient: LinearGradient(
      colors: [Color(0xFF064e3b), Color(0xFF059669), Color(0xFF34d399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'party',
    name: 'Party',
    emoji: '🎉',
    subtitle: 'Let\'s go',
    artUrl: 'assets/images/moods/04_party.jpg',
    glowColor: Color(0xFFec4899),
    gradient: LinearGradient(
      colors: [Color(0xFF831843), Color(0xFFdb2777), Color(0xFFf472b6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment(0.0, 0.72),
  ),
  MoodData(
    key: 'drive',
    name: 'Drive',
    emoji: '🚗',
    subtitle: 'Open road',
    artUrl: 'assets/images/moods/05_drive.jpg',
    glowColor: Color(0xFFa855f7),
    gradient: LinearGradient(
      colors: [Color(0xFF3b0764), Color(0xFF7c3aed), Color(0xFFa78bfa)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.topCenter,
  ),
  MoodData(
    key: 'sleep',
    name: 'Sleep',
    emoji: '😴',
    subtitle: 'Deep calm',
    artUrl: 'assets/images/moods/06_sleep.jpg',
    glowColor: Color(0xFF6366f1),
    gradient: LinearGradient(
      colors: [Color(0xFF0f172a), Color(0xFF1e1b4b), Color(0xFF312e81)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.topCenter,
  ),
  MoodData(
    key: 'morning',
    name: 'Morning',
    emoji: '☀️',
    subtitle: 'Fresh start',
    artUrl: 'assets/images/moods/07_morning.jpg',
    glowColor: Color(0xFFfbbf24),
    gradient: LinearGradient(
      colors: [Color(0xFF78350f), Color(0xFFd97706), Color(0xFFfbbf24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.topCenter,
  ),
  MoodData(
    key: 'late_night',
    name: 'Late Night',
    emoji: '🌙',
    subtitle: 'Midnight soul',
    artUrl: 'assets/images/moods/08_latenight.jpg',
    glowColor: Color(0xFF818cf8),
    gradient: LinearGradient(
      colors: [Color(0xFF030712), Color(0xFF1e1b4b), Color(0xFF4338ca)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.topCenter,
  ),
  MoodData(
    key: 'sad',
    name: 'Sad',
    emoji: '🌧️',
    subtitle: 'Feel it all',
    artUrl: 'assets/images/moods/09_sad.jpg',
    glowColor: Color(0xFF38bdf8),
    gradient: LinearGradient(
      colors: [Color(0xFF0c4a6e), Color(0xFF0369a1), Color(0xFF38bdf8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'romance',
    name: 'Romance',
    emoji: '❤️',
    subtitle: 'Love songs',
    artUrl: 'assets/images/moods/10_romance.jpg',
    glowColor: Color(0xFFfb7185),
    gradient: LinearGradient(
      colors: [Color(0xFF881337), Color(0xFFe11d48), Color(0xFFfb7185)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'hype',
    name: 'Hype',
    emoji: '🔥',
    subtitle: 'Maximum energy',
    artUrl: 'assets/images/moods/11_hype.jpg',
    glowColor: Color(0xFFfacc15),
    gradient: LinearGradient(
      colors: [Color(0xFF451a03), Color(0xFFb45309), Color(0xFFfacc15)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'meditate',
    name: 'Meditate',
    emoji: '🧘',
    subtitle: 'Inner peace',
    artUrl: 'assets/images/moods/12_meditate.jpg',
    glowColor: Color(0xFF2dd4bf),
    gradient: LinearGradient(
      colors: [Color(0xFF042f2e), Color(0xFF0f766e), Color(0xFF2dd4bf)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.topCenter,
  ),
  MoodData(
    key: 'rainy',
    name: 'Rainy Day',
    emoji: '🌊',
    subtitle: 'Cozy indoors',
    artUrl: 'assets/images/moods/13_rainyday.jpg',
    glowColor: Color(0xFF7dd3fc),
    gradient: LinearGradient(
      colors: [Color(0xFF0c4a6e), Color(0xFF075985), Color(0xFF7dd3fc)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
  MoodData(
    key: 'beach',
    name: 'Beach',
    emoji: '🏖️',
    subtitle: 'Summer waves',
    artUrl: 'assets/images/moods/14_beach.jpg',
    glowColor: Color(0xFF34d399),
    gradient: LinearGradient(
      colors: [Color(0xFF022c22), Color(0xFF065f46), Color(0xFF34d399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    imageAlignment: Alignment.center,
  ),
];

// ─── Определяем рекомендованный муд по времени/погоде ─────────────────────

String getRecommendedMoodKey(Map<String, dynamic>? weather) {
  final hour = DateTime.now().hour;
  final desc = (weather?['description'] ?? weather?['condition'] ?? '')
      .toString()
      .toLowerCase();

  // Weather-priority rules
  if (desc.contains('storm') || desc.contains('thunder')) return 'sad';
  if (desc.contains('snow') || desc.contains('blizzard')) {
    return (hour >= 20 || hour < 7) ? 'sleep' : 'chill';
  }
  if (desc.contains('rain') ||
      desc.contains('drizzle') ||
      desc.contains('shower')) {
    return (hour >= 22 || hour < 6) ? 'late_night' : 'rainy';
  }

  // Clear / sunny — follow time
  if (desc.contains('clear') || desc.contains('sunny')) {
    if (hour >= 5 && hour < 9) return 'morning';
    if (hour >= 9 && hour < 16) return 'beach';
    if (hour >= 16 && hour < 20) return 'drive';
    if (hour >= 20 && hour < 23) return 'romance';
    return 'late_night';
  }

  // Any other weather — pure time-based
  if (hour >= 0 && hour < 5) return 'late_night';
  if (hour >= 5 && hour < 9) return 'morning';
  if (hour >= 9 && hour < 12) return 'study';
  if (hour >= 12 && hour < 15) return 'chill';
  if (hour >= 15 && hour < 18) return 'drive';
  if (hour >= 18 && hour < 21) return 'party';
  if (hour >= 21 && hour < 24) return 'romance';
  return 'chill';
}

String getRecommendedMoodReason(Map<String, dynamic>? weather) {
  final hour = DateTime.now().hour;
  final desc = (weather?['description'] ?? weather?['condition'] ?? '')
      .toString()
      .toLowerCase();

  if (desc.contains('storm') || desc.contains('thunder')) {
    return 'Stormy weather pick';
  }
  if (desc.contains('snow') || desc.contains('blizzard')) {
    return 'Snowy weather pick';
  }
  if (desc.contains('rain') ||
      desc.contains('drizzle') ||
      desc.contains('shower')) {
    return 'Rainy weather pick';
  }
  if (desc.contains('clear') || desc.contains('sunny')) {
    if (hour >= 5 && hour < 9) return 'Sunny morning pick';
    if (hour >= 9 && hour < 16) return 'Daylight mood pick';
    if (hour >= 16 && hour < 20) return 'Golden hour pick';
    return 'Evening mood pick';
  }
  if (hour >= 0 && hour < 5) return 'Late night pick';
  if (hour >= 5 && hour < 9) return 'Morning pick';
  if (hour >= 9 && hour < 12) return 'Focus time pick';
  if (hour >= 12 && hour < 15) return 'Midday reset pick';
  if (hour >= 15 && hour < 18) return 'Afternoon energy pick';
  if (hour >= 18 && hour < 21) return 'Evening energy pick';
  return 'Night mood pick';
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
    final recommendedReason = getRecommendedMoodReason(widget.weather);
    final recommended = allMoods.firstWhere((m) => m.key == recommendedKey,
        orElse: () => allMoods[2]);
    final others = allMoods.where((m) => m.key != recommendedKey).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
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
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${allMoods.length} moods curated for the moment',
                          style: GoogleFonts.dmSans(
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
                        recommendedReason,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 0.3,
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
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text3,
                      letterSpacing: 0.3,
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
  bool _hovered = false;
  bool _pressed = false;

  Future<void> _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    final active = _hovered || _pressed;
    final pressed = _pressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : (active ? 1.025 : 1.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: mood.glowColor.withOpacity(active ? 0.62 : 0.0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: pressed
                      ? mood.glowColor.withOpacity(0.58)
                      : Colors.black.withOpacity(active ? 0.36 : 0.26),
                  blurRadius: pressed ? 38 : (active ? 28 : 18),
                  spreadRadius: pressed ? 3 : 0,
                  offset: Offset(0, active ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: active ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutCubic,
                    child: Image.asset(
                      mood.artUrl,
                      fit: BoxFit.cover,
                      alignment: mood.imageAlignment,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(gradient: mood.gradient),
                      ),
                    ),
                  ),

                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          mood.glowColor.withOpacity(0.12),
                          mood.gradient.colors.last.withOpacity(0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x0A000000),
                          Color(0x22000000),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          mood.glowColor.withOpacity(pressed ? 0.28 : 0.0),
                          mood.gradient.colors.last
                              .withOpacity(pressed ? 0.14 : 0.0),
                        ],
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
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 34,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.55),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mood.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.80),
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
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  Future<void> _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    setState(() => _pressed = false);
    widget.onTap();
  }

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
    final active = _hovered || _pressed;
    final pressed = _pressed;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => _handleTap(),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.965 : (active ? 1.035 : 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: mood.glowColor.withOpacity(active ? 0.58 : 0.0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pressed
                          ? mood.glowColor.withOpacity(0.36)
                          : Colors.black.withOpacity(active ? 0.34 : 0.22),
                      blurRadius: pressed ? 28 : (active ? 20 : 14),
                      spreadRadius: pressed ? 1 : 0,
                      offset: Offset(0, active ? 10 : 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: active ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 620),
                        curve: Curves.easeOutCubic,
                        child: Image.asset(
                          mood.artUrl,
                          fit: BoxFit.cover,
                          alignment: mood.imageAlignment,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(gradient: mood.gradient),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              mood.glowColor.withOpacity(0.12),
                              mood.gradient.colors.last.withOpacity(0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              mood.glowColor.withOpacity(pressed ? 0.32 : 0.0),
                              mood.gradient.colors.last
                                  .withOpacity(pressed ? 0.16 : 0.0),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.18),
                              Colors.transparent,
                              Colors.black.withOpacity(0.20),
                              Colors.black.withOpacity(0.72),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.25, 0.50, 1.0],
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        bottom: 11,
                        left: 13,
                        right: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mood.name,
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 19,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 14)
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mood.subtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Play button — bottom-right
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
                                color: Colors.white.withOpacity(0.92),
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
