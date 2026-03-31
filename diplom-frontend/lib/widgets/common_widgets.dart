import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
