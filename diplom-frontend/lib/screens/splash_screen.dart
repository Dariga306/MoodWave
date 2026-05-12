import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main/main_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));

    _textFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _textSlide = Tween<double>(begin: 20, end: 0).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));

    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _mainCtrl.forward();
    _glowCtrl.repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    await context.read<AuthProvider>().checkAuth();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final hasCity = user != null &&
        user['city'] != null &&
        (user['city'] as String).isNotEmpty;
    final dest = (auth.status == AuthStatus.authenticated && hasCity)
        ? const MainScreen()
        : const OnboardingScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => dest));
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // Фиолетовое свечение на фоне снизу
          Positioned(
            bottom: -100, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Container(
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      const Color(0xFF7c3aed).withOpacity(0.18 * _glow.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Логотип + текст по центру
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Логотип с пульсирующим свечением
                AnimatedBuilder(
                  animation: Listenable.merge([_mainCtrl, _glowCtrl]),
                  builder: (_, __) => FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        decoration: BoxDecoration(
  shape: BoxShape.circle,
  border: Border.all(
    color: const Color(0xFF7c3aed).withOpacity(0.6),
    width: 2,
  ),
  boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7c3aed)
                                  .withOpacity(0.6 * _glow.value),
                              blurRadius: 60 * _glow.value,
                              spreadRadius: 10 * _glow.value,
                            ),
                            BoxShadow(
                              color: const Color(0xFFa855f7)
                                  .withOpacity(0.25 * _glow.value),
                              blurRadius: 120 * _glow.value,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
  child: Image.asset(
    'assets/images/logo.png',
    width: 200,
    height: 200,
    fit: BoxFit.cover,
  ),
),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Текст — появляется после логотипа
                AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _textFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Column(
                        children: [
                          Text('MoodWave',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              )),
                          const SizedBox(height: 6),
                          Text('Music for every mood',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: Colors.white38,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Спиннер внизу
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: const Color(0xFFa855f7)
                        .withOpacity(0.4 + 0.4 * _glow.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}