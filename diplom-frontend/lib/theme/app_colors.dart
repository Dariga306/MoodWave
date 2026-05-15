import 'package:flutter/material.dart';

/// AppColors — обновлён под новый фиолетово-неоновый логотип MoodWave.
/// Логотип: глубокий неоновый фиолет (#7B2FFF → #A855F7) на чёрном фоне.
class AppColors {
  // ── Основная палитра ──────────────────────────────────────────────────────
  static const Color purple = Color(0xFFa855f7);
  static const Color purpleDark = Color(0xFF7c3aed);
  static const Color purpleLight = Color(0xFFc084fc);

  /// Неоновый фиолетовый — главный акцентный цвет под логотип
  static const Color neonPurple = Color(0xFF9333EA);
  static const Color neonPurpleBright = Color(0xFFB45FFB);
  static const Color neonPurpleGlow = Color(0xFF7B2FFF);

  static const Color blue = Color(0xFF3b82f6);
  static const Color blueLight = Color(0xFF60a5fa);
  static const Color pink = Color(0xFFec4899);
  static const Color pinkLight = Color(0xFFf472b6);
  static const Color cyan = Color(0xFF06b6d4);
  static const Color green = Color(0xFF22c55e);
  static const Color teal = Color(0xFF10b981);
  static const Color orange = Color(0xFFf97316);
  static const Color amber = Color(0xFFf59e0b);
  static const Color red = Color(0xFFef4444);

  // ── Фоны ─────────────────────────────────────────────────────────────────
  /// Основной фон — почти чёрный с глубоким фиолетовым оттенком
  static const Color bg = Color(0xFF080010);
  static const Color bgDeep = Color(0xFF060010);
  static const Color bg2 = Color(0xFF0e0020);
  static const Color bg3 = Color(0xFF14002e);

  /// Поверхности (карточки, поля)
  static const Color surface = Color(0xFF130025);
  static const Color surface2 = Color(0xFF1a0035);
  static const Color surface3 = Color(0xFF200045);

  // ── Стекло ────────────────────────────────────────────────────────────────
  static const Color glass = Color(0x0FFFFFFF);
  static const Color glass2 = Color(0x1AFFFFFF);
  static const Color glass3 = Color(0x0AFFFFFF);

  // ── Границы ───────────────────────────────────────────────────────────────
  static const Color border = Color(0x2A7B2FFF); // фиолетовая с прозрачностью
  static const Color border2 = Color(0x4A9333EA); // ярче для активных элементов

  // ── Текст ─────────────────────────────────────────────────────────────────
  static const Color text = Color(0xFFf0f0ff);
  static const Color text2 = Color(0xFFa090c8);
  static const Color text3 = Color(0xFF604880);

  // ── Градиенты ─────────────────────────────────────────────────────────────

  /// Главный неоновый фиолетовый — под логотип
  static const LinearGradient gradNeonPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B21B6), Color(0xFF9333EA), Color(0xFFB45FFB)],
  );

  /// Логотипный градиент (для кнопок Sign In и акцентов)
  static const LinearGradient primaryBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D28D9), Color(0xFF9333EA), Color(0xFFB45FFB)],
  );

  static const LinearGradient authCta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8C3DFF), Color(0xFFE249A4)],
  );

  static const LinearGradient authBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF13051F), Color(0xFF0B1028), Color(0xFF070814)],
    stops: [0.0, 0.48, 1.0],
  );

  static const LinearGradient gradPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3b0764), Color(0xFF7c3aed)],
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

  static const LinearGradient gradRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7f1d1d), Color(0xFFef4444)],
  );

  static const LinearGradient gradGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14532d), Color(0xFF22c55e)],
  );

  static const LinearGradient gradMixed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3b0764), Color(0xFF7c3aed), Color(0xFFec4899)],
  );

  /// Заголовочный градиент (текст)
  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB45FFB), Color(0xFF9333EA), Color(0xFF818cf8)],
  );

  // ── Настроения ────────────────────────────────────────────────────────────
  static const LinearGradient moodStudy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
  );
  static const LinearGradient moodSport = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7c2d12), Color(0xFFf97316)],
  );
  static const LinearGradient moodSleep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0f172a), Color(0xFF3730a3)],
  );
  static const LinearGradient moodChill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF065f46), Color(0xFF0891b2)],
  );
  static const LinearGradient moodParty = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9d174d), Color(0xFFec4899)],
  );
  static const LinearGradient moodRomantic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF831843), Color(0xFFf472b6)],
  );
  static const LinearGradient moodAngry = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF450a0a), Color(0xFFdc2626)],
  );
  static const LinearGradient moodHappy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF713f12), Color(0xFFeab308)],
  );
  static const LinearGradient moodMelancholy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1e1b4b), Color(0xFF6d28d9)],
  );
  static const LinearGradient moodDrive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3b0764), Color(0xFF7c3aed)],
  );
  static const LinearGradient moodMorning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7c2d12), Color(0xFFfbbf24)],
  );
  static const LinearGradient moodLateNight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0f172a), Color(0xFF1e1b4b)],
  );
}
