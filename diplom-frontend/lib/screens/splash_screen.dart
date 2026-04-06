import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart' show rootScaffoldMessengerKey;
import '../providers/auth_provider.dart';
import '../services/spotify_player_service.dart';
import '../theme/app_colors.dart';
import 'main/main_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOutBack)));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    final spotifyJustConnected = SpotifyPlayerService.wasJustConnected();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    await context.read<AuthProvider>().checkAuth();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final status = auth.status;
    final user = auth.user;
    final hasCity = user != null &&
        user['city'] != null &&
        (user['city'] as String).isNotEmpty;
    final dest = (status == AuthStatus.authenticated && hasCity)
        ? const MainScreen()
        : const OnboardingScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dest));

    if (spotifyJustConnected) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Spotify подключён! Полное воспроизведение доступно.',
                style: GoogleFonts.outfit(color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF1DB954),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08080f), Color(0xFF150825), Color(0xFF0d1328)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradMixed,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                          color: AppColors.purpleDark.withOpacity(0.5),
                          blurRadius: 40, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('MoodWave', style: GoogleFonts.outfit(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Music for every mood',
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.purpleLight.withOpacity(0.5)),
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
