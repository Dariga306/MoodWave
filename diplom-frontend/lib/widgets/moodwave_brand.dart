import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MoodWaveLogoMark extends StatelessWidget {
  final double size;
  final double radius;
  final double glow;

  const MoodWaveLogoMark({
    super.key,
    this.size = 96,
    this.radius = 28,
    this.glow = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.20 * glow),
            blurRadius: 26 * glow,
            spreadRadius: 3 * glow,
          ),
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.16 * glow),
            blurRadius: 44 * glow,
            spreadRadius: 6 * glow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class MoodWaveWaveBars extends StatelessWidget {
  final double width;
  final double height;
  final bool animated;

  const MoodWaveWaveBars({
    super.key,
    this.width = 74,
    this.height = 48,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!animated) {
      return SizedBox(
        width: width,
        height: height,
        child: const CustomPaint(painter: _MoodWaveBarsPainter()),
      );
    }
    return _AnimatedMoodWaveBars(width: width, height: height);
  }
}

class _AnimatedMoodWaveBars extends StatefulWidget {
  final double width;
  final double height;

  const _AnimatedMoodWaveBars({
    required this.width,
    required this.height,
  });

  @override
  State<_AnimatedMoodWaveBars> createState() => _AnimatedMoodWaveBarsState();
}

class _AnimatedMoodWaveBarsState extends State<_AnimatedMoodWaveBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    final speeds = [620, 820, 540, 760, 680, 900, 590, 790];
    final ranges = [
      (0.32, 0.82),
      (0.18, 0.72),
      (0.42, 0.96),
      (0.24, 1.0),
      (0.14, 0.68),
      (0.36, 0.88),
      (0.20, 0.78),
      (0.30, 0.64),
    ];
    _controllers = List.generate(
      speeds.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: speeds[index]),
      )..repeat(reverse: true),
    );
    _animations = List.generate(
      speeds.length,
      (index) => Tween<double>(
        begin: ranges[index].$1,
        end: ranges[index].$2,
      ).animate(
        CurvedAnimation(
          parent: _controllers[index],
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge(_controllers),
        builder: (_, __) => CustomPaint(
          painter: _MoodWaveBarsPainter(
            values: _animations.map((animation) => animation.value).toList(),
          ),
        ),
      ),
    );
  }
}

class _MoodWaveBarsPainter extends CustomPainter {
  final List<double>? values;

  const _MoodWaveBarsPainter({this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barWidth = size.width * 0.055;
    final gap = size.width * 0.115;
    final centerX = size.width / 2;
    final baseValues = values ??
        const [
          0.28,
          0.48,
          0.68,
          0.86,
          0.58,
          0.42,
          0.62,
          0.32,
        ];

    for (var i = 0; i < baseValues.length; i++) {
      final t = baseValues.length == 1 ? 0.0 : i / (baseValues.length - 1);
      final color = Color.lerp(
        const Color(0xFF8C3DFF),
        const Color(0xFFE249A4),
        t,
      )!;
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;
      final x = centerX + (i - (baseValues.length - 1) / 2) * gap;
      final half = (size.height * baseValues[i]) / 2;
      canvas.drawLine(
          Offset(x, centerY - half), Offset(x, centerY + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodWaveBarsPainter oldDelegate) =>
      oldDelegate.values != values;
}
