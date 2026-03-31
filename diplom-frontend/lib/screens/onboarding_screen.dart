import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  final _controller = PageController();

  final _pages = const [
    _OnboardPage(
      gradient: AppColors.gradPurple,
      emoji: '🎵',
      title: 'Music for every',
      titleHighlight: 'mood & moment',
      desc: 'Choose from curated mood tiles — Study, Sport, Sleep, Party — and see what others in your city are listening to right now.',
      pageIndex: 0,
    ),
    _OnboardPage(
      gradient: AppColors.gradCyan,
      emoji: '🌨',
      title: 'Music that matches',
      titleHighlight: 'the weather',
      desc: 'MoodWave reads the sky. Snow, rain, sunset — get a perfectly curated playlist that matches the atmosphere outside your window.',
      pageIndex: 1,
    ),
    _OnboardPage(
      gradient: AppColors.gradPink,
      emoji: '💫',
      title: 'Find your',
      titleHighlight: 'music soulmate',
      desc: 'Our AI matches you with people who share your exact music taste — same artists, same moods, same vibes. Like Tinder for music lovers.',
      pageIndex: 2,
    ),
  ];

  void _next() {
    if (_page < 2) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: _pages,
          ),
          // Skip button
          Positioned(
            top: 0, right: 28,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Text('Skip',
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text2)),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      children: List.generate(3, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _page == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i ? AppColors.purple : AppColors.surface3,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      )),
                    ),
                    const SizedBox(height: 32),
                    // Button
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: _page == 2
                              ? AppColors.gradPink
                              : const LinearGradient(
                                  colors: [Color(0xFF7c3aed), Color(0xFFa855f7)]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.purpleDark.withOpacity(0.35),
                              blurRadius: 24, offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Text(_page == 2 ? "Let's Go 🎶" : 'Next →',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final LinearGradient gradient;
  final String emoji;
  final String title;
  final String titleHighlight;
  final String desc;
  final int pageIndex;

  const _OnboardPage({
    required this.gradient,
    required this.emoji,
    required this.title,
    required this.titleHighlight,
    required this.desc,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image card
              Container(
                width: double.infinity, height: 260,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    // Background orb
                    Positioned(
                      top: 0, left: 0, right: 0, bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: RadialGradient(
                            center: const Alignment(0.6, -0.4),
                            colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Center(child: _buildPageContent()),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Title
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                      fontSize: 30, fontWeight: FontWeight.w800,
                      color: AppColors.text, height: 1.15),
                  children: [
                    TextSpan(text: '$title\n'),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.purpleLight, AppColors.pink],
                        ).createShader(bounds),
                        child: Text(titleHighlight,
                            style: GoogleFonts.outfit(
                                fontSize: 30, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(desc,
                  style: GoogleFonts.outfit(
                      fontSize: 16, height: 1.65, fontWeight: FontWeight.w400,
                      color: AppColors.text2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    if (pageIndex == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['😴 Sleep', '🏃 Sport', '📚 Study'].map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(m,
                  style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            )).toList(),
          ),
        ],
      );
    } else if (pageIndex == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text('−4°C',
                    style: GoogleFonts.outfit(
                        fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Snow · Astana',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                Text('28 people listening',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatar('A', AppColors.gradPurple),
              const SizedBox(width: 8),
              _avatar('D', AppColors.gradBlue),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text('92% match\nYou both listen to The Neighbourhood in rainy weather ☂️',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withOpacity(0.85), height: 1.5)),
          ),
        ],
      );
    }
  }

  Widget _avatar(String letter, LinearGradient grad) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        gradient: grad,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
        boxShadow: [BoxShadow(color: AppColors.purple.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Center(child: Text(letter,
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
    );
  }
}
