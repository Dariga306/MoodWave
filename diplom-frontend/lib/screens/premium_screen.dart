import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎵', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.purpleLight, AppColors.pink],
                ).createShader(b),
                child: Text(
                  'All Features Are Free!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.02 * 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MoodWave gives you everything — music matching, listening rooms, AI recommendations, and more — at no cost. Enjoy the full experience.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.text2,
                ),
              ),
              const SizedBox(height: 40),
              _FreePerk(icon: '🎯', label: 'AI Music Recommendations'),
              _FreePerk(icon: '💞', label: 'Unlimited Music Matching'),
              _FreePerk(icon: '🎙', label: 'Listening Party Rooms'),
              _FreePerk(icon: '📊', label: 'Listening Stats & Wrapped'),
              _FreePerk(icon: '🌤', label: 'Weather-Based Playlists'),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryBtn,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDark.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Text(
                    'Start Listening',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreePerk extends StatelessWidget {
  final String icon, label;
  const _FreePerk({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF22c55e), size: 20),
      ]),
    );
  }
}
