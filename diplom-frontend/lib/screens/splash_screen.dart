import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/moodwave_brand.dart';
import 'login_screen.dart';
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

    _glow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _mainCtrl.forward();
    _glowCtrl.repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }
    await context.read<AuthProvider>().checkAuth();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final hasCity = user != null &&
        user['city'] != null &&
        (user['city'] as String).isNotEmpty;
    final dest = (auth.status == AuthStatus.authenticated && hasCity)
        ? const MainScreen()
        : const LoginScreen();
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
      backgroundColor: AppColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.authBackground),
        child: Stack(
          children: [
            Positioned(
              top: 120,
              left: -80,
              right: -80,
              child: AnimatedBuilder(
                animation: _glow,
                builder: (_, __) => Container(
                  height: 360,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.68,
                      colors: [
                        AppColors.pink.withValues(alpha: 0.14 * _glow.value),
                        AppColors.purple.withValues(alpha: 0.10 * _glow.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Transform.translate(
                offset: const Offset(0, -8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_mainCtrl, _glowCtrl]),
                      builder: (_, __) => FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: const MoodWaveLogoMark(
                              size: 128, radius: 38, glow: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    AnimatedBuilder(
                      animation: _mainCtrl,
                      builder: (_, __) => Opacity(
                        opacity: _textFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppColors.authCta.createShader(bounds),
                                child: Text('MoodWave',
                                    style: GoogleFonts.outfit(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    )),
                              ),
                              const SizedBox(height: 8),
                              Text('Discover music through your mood',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text2,
                                  )),
                              const SizedBox(height: 54),
                              const MoodWaveWaveBars(width: 82, height: 54),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
