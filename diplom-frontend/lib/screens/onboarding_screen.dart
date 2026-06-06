import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool postRegistration;
  const OnboardingScreen({super.key, this.postRegistration = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _total = 3;

  void _next() {
    if (_page < _total - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    if (widget.postRegistration) {
      await context.read<AuthProvider>().completeOnboarding();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            widget.postRegistration ? const MainScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: const [_MoodPage(), _WeatherPage(), _MatchPage()],
          ),
          // Skip
          Positioned(
            top: top + 14,
            right: 20,
            child: GestureDetector(
              onTap: _finish,
              child: Text('Skip',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white60)),
            ),
          ),
          // Dots + button
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_total, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active ? AppColors.purpleLight : Colors.white24,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _page == _total - 1
                            ? const Color(0xFFe91e8c)
                            : AppColors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _page == _total - 1 ? "Let's Go 🔥" : "Next →",
                        style: GoogleFonts.outfit(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared layout ────────────────────────────────────────────────────────────

class _PageLayout extends StatelessWidget {
  const _PageLayout({
    required this.card,
    required this.titleTop,
    required this.titleBottom,
    required this.titleGradient,
    required this.description,
  });

  final Widget card;
  final String titleTop;
  final String titleBottom;
  final Gradient titleGradient;
  final String description;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final compact = screenH < 760;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? screenH * 0.36 : screenH * 0.42,
          width: double.infinity,
          child: card,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleTop,
                    style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1)),
                ShaderMask(
                  shaderCallback: (b) => titleGradient.createShader(b),
                  child: Text(titleBottom,
                      style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2)),
                ),
                const SizedBox(height: 12),
                Text(description,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9090a8),
                        height: 1.6)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Page 1: Mood ─────────────────────────────────────────────────────────────

class _MoodPage extends StatelessWidget {
  const _MoodPage();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      card: const _MoodCard(),
      titleTop: 'Music for every',
      titleBottom: 'mood & moment',
      titleGradient:
          const LinearGradient(colors: [Color(0xFFe040fb), Color(0xFFa855f7)]),
      description:
          'Choose from curated mood tiles like Study, Sport, Sleep, and Party, then jump straight into live chart-driven discovery for your city.',
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 44, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8b5cf6), Color(0xFF5b21b6)],
        ),
      ),
      child: Stack(
        children: [
          // radial glow top-left
          Positioned(
            top: -30,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFc084fc).withOpacity(0.22),
              ),
            ),
          ),
          // radial glow bottom-right
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4c1d95).withOpacity(0.5),
              ),
            ),
          ),
          // content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // aura ring behind note
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFa855f7).withOpacity(0.18),
                      ),
                    ),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFa855f7).withOpacity(0.22),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFe9d5ff), Color(0xFF9333ea)],
                      ).createShader(b),
                      child: const Icon(Icons.music_note_rounded,
                          size: 86, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Tags
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _MoodTag(emoji: '😴', label: 'Sleep'),
                    SizedBox(width: 8),
                    _MoodTag(emoji: '⚡', label: 'Sport'),
                    SizedBox(width: 8),
                    _MoodTag(emoji: '📊', label: 'Study'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodTag extends StatelessWidget {
  const _MoodTag({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text('$emoji $label',
          style: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

// ─── Page 2: Weather ─────────────────────────────────────────────────────────

class _WeatherPage extends StatelessWidget {
  const _WeatherPage();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      card: const _WeatherCard(),
      titleTop: 'Music that matches',
      titleBottom: 'the weather',
      titleGradient:
          const LinearGradient(colors: [Color(0xFF38bdf8), Color(0xFF0ea5e9)]),
      description:
          'MoodWave reads the sky. Snow, rain, sunset, late-night calm — every forecast becomes a matching listening lane with local context.',
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final compact = h < 760;
    return Container(
      margin: EdgeInsets.fromLTRB(16, compact ? 34 : 44, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0369a1), Color(0xFF075985)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38bdf8).withOpacity(0.18),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 18 : 24,
              vertical: compact ? 18 : 28,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cloud with snowflakes
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.cloud,
                        size: compact ? 58 : 80, color: Colors.white),
                    Positioned(
                      bottom: compact ? -5 : -8,
                      child: Row(
                        children: const [
                          Text('❄️', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('❄️', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 8),
                          Text('❄️', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),
                // Info card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: compact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF082f49).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: [
                      Text('−4°C',
                          style: GoogleFonts.outfit(
                              fontSize: compact ? 30 : 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1)),
                      const SizedBox(height: 4),
                      Text('Snow · Astana',
                          style: GoogleFonts.outfit(
                              fontSize: compact ? 13 : 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text('28 people listening',
                          style: GoogleFonts.outfit(
                              fontSize: compact ? 11 : 13,
                              color: Colors.white38)),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 8),
                // Weather chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _WeatherChip(Icons.cloudy_snowing),
                    SizedBox(width: 10),
                    _WeatherChip(Icons.cloud),
                    SizedBox(width: 10),
                    _WeatherChip(Icons.nightlight_round),
                    SizedBox(width: 10),
                    _WeatherChip(Icons.wb_sunny_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.height < 760;
    return Container(
      width: compact ? 42 : 50,
      height: compact ? 42 : 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Icon(icon, size: compact ? 21 : 24, color: Colors.white70),
    );
  }
}

// ─── Page 3: Match ───────────────────────────────────────────────────────────

class _MatchPage extends StatelessWidget {
  const _MatchPage();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      card: const _MatchCard(),
      titleTop: 'Find your',
      titleBottom: 'music soulmate',
      titleGradient:
          const LinearGradient(colors: [Color(0xFFf43f5e), Color(0xFFe91e8c)]),
      description:
          'Meet people who overlap with your real taste profile: same artists, same moods, and shared listening energy you can actually start from.',
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 44, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFbe185d), Color(0xFF881337)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFf43f5e).withOpacity(0.2),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatars
                  SizedBox(
                    height: 90,
                    width: 158,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: _MatchAvatar(
                              letter: 'A',
                              color: const Color(0xFF7c3aed),
                              borderColor: const Color(0xFF881337)),
                        ),
                        Positioned(
                          right: 0,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _MatchAvatar(
                                  letter: 'D',
                                  color: const Color(0xFF1d4ed8),
                                  borderColor: const Color(0xFF881337)),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFfbbf24)),
                                  child: const Icon(Icons.star_rounded,
                                      size: 15, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Match card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Column(
                      children: [
                        Text('92% match',
                            style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(
                          'You both listen to The Neighbourhood\nin rainy weather ☔',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar(
      {required this.letter, required this.color, required this.borderColor});

  final String letter;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: borderColor, width: 4)),
      alignment: Alignment.center,
      child: Text(letter,
          style: GoogleFonts.outfit(
              fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
