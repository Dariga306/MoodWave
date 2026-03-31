import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color purple = Color(0xFFa855f7);
  static const Color purpleDark = Color(0xFF7c3aed);
  static const Color purpleLight = Color(0xFFc084fc);
  static const Color blue = Color(0xFF3b82f6);
  static const Color blueLight = Color(0xFF60a5fa);
  static const Color pink = Color(0xFFec4899);
  static const Color pinkLight = Color(0xFFf472b6);
  static const Color cyan = Color(0xFF06b6d4);
  static const Color green = Color(0xFF22c55e);
  // Backgrounds
  static const Color bg = Color(0xFF08080f);
  static const Color bg2 = Color(0xFF0e0e1a);
  static const Color bg3 = Color(0xFF141428);
  static const Color surface = Color(0xFF1a1a2e);
  static const Color surface2 = Color(0xFF1e1e35);
  static const Color surface3 = Color(0xFF252545);

  // Glass
  static const Color glass = Color(0x0FFFFFFF);
  static const Color glass2 = Color(0x1AFFFFFF);
  static const Color glass3 = Color(0x0AFFFFFF);

  // Borders
  static const Color border = Color(0x1AFFFFFF);
  static const Color border2 = Color(0x29FFFFFF);

  // Text
  static const Color text = Color(0xFFf0f0ff);
  static const Color text2 = Color(0xFFa0a0c0);
  static const Color text3 = Color(0xFF606080);

  // Gradients
  static const LinearGradient gradPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)],
  );
  static const LinearGradient gradPink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9d174d), Color(0xFFec4899)],
  );
  static const LinearGradient gradBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
  );
  static const LinearGradient gradTeal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF065f46), Color(0xFF10b981)],
  );
  static const LinearGradient gradOrange = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF92400e), Color(0xFFf59e0b)],
  );
  static const LinearGradient gradCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF164e63), Color(0xFF06b6d4)],
  );
  static const LinearGradient gradMixed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4c1d95), Color(0xFF7c3aed), Color(0xFFec4899)],
  );
  static const LinearGradient primaryBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7c3aed), Color(0xFFa855f7), Color(0xFFec4899)],
  );
  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFc084fc), Color(0xFFf472b6), Color(0xFF818cf8)],
  );
}
