# MoodWave — Flutter App

Полный фронтенд проект на Flutter, конвертированный из HTML дизайна.

## Структура проекта

```
lib/
├── main.dart                        # Entry point
├── theme/
│   └── app_colors.dart             # Все цвета, градиенты
├── widgets/
│   ├── common_widgets.dart         # Общие виджеты
│   └── bottom_nav_bar.dart         # Нижняя навигация
└── screens/
    ├── splash_screen.dart          # Screen 01 — Сплэш
    ├── onboarding_screen.dart      # Screen 02-04 — Онбординг (3 страницы)
    ├── login_screen.dart           # Screen 05 — Логин
    ├── player_screen.dart          # Screen 07 — Плеер
    ├── chat_screen.dart            # Screen 10 — Чат
    ├── playlist_screen.dart        # Screen 13 — Плейлист
    ├── weather_screen.dart         # Screen 14 — Погода
    └── main/
        ├── main_screen.dart        # Главный экран с нижним меню
        ├── home_tab.dart           # Screen 06 — Главная
        ├── search_tab.dart         # Screen 08 — Поиск
        ├── match_tab.dart          # Screen 09 — Match
        ├── friends_tab.dart        # Screen 12 — Друзья
        └── profile_tab.dart        # Screen 11 — Профиль
```

## Установка и запуск

### 1. Установить зависимости
```bash
flutter pub get
```

### 2. Запустить приложение
```bash
flutter run
```

### 3. Сборка APK
```bash
flutter build apk --release
```

## Зависимости

- **flutter** — SDK
- **google_fonts** ^6.1.0 — Шрифт Outfit

## Навигация

Поток:
```
SplashScreen
  → OnboardingScreen (3 страницы с PageView)
    → LoginScreen
      → MainScreen (IndexedStack + BottomNavBar)
          ├── HomeTab (+ переход на PlayerScreen)
          ├── SearchTab
          ├── MatchTab (+ переход на ChatScreen)
          ├── FriendsTab
          └── ProfileTab

Дополнительные экраны:
  → PlayerScreen (из HomeTab / WeatherScreen)
  → ChatScreen (из MatchTab)
  → PlaylistScreen (отдельный экран)
  → WeatherScreen (отдельный экран)
```

## Дизайн

- 🎨 **Dark theme** — фон #08080f
- ✨ **Glassmorphism** — BackdropFilter + прозрачные бордеры
- 🌈 **Neon gradients** — фиолетовый, розовый, синий
- 📱 **Шрифт** — Outfit (Google Fonts)
- 💫 **Анимации** — floating cover, music bars, pulse orbs
