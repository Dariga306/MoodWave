# MoodWave Frontend

Flutter-приложение MoodWave для web/mobile. Основной backend ожидается на `http://127.0.0.1:8000`, web-версия обычно запускается на `http://localhost:5001`.

## Основные экраны

- `Home`: Live Weather, Recently Played, You Might Like, AI Mixes, Mood, Radio, This Is, Top in your city.
- `Search`: поиск музыки, артистов и альбомов.
- `Social`: матчи, друзья, listening rooms.
- `Library`: liked songs, плейлисты, альбомы, подписки на артистов.
- `Profile`: профиль, аватар, баннер, followers/following.
- `Player`: полный плеер, mini-player, queue, lyrics, playlist actions.

## Запуск

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5001
```

Открыть:

```text
http://localhost:5001/
```

## Production web build

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
flutter build web --pwa-strategy=none
python -m http.server 5001 -d build\web --bind 127.0.0.1
```

Если браузер показывает старую сборку, нажми `Ctrl + F5`.

## Проверки

```powershell
flutter analyze
flutter build web --pwa-strategy=none
```

## Важные папки

```text
lib/
├── main.dart
├── providers/           # auth/player state
├── screens/             # экраны приложения
├── screens/main/        # Home/Search/Social/Library/Profile tabs
├── services/            # API, token storage, player helpers
├── theme/               # цвета и градиенты
├── utils/               # media url helpers
└── widgets/             # общие компоненты
```

## Backend endpoints, которые особенно важны для UI

- `/health`
- `/auth/me`
- `/tracks/me/recent`
- `/tracks/me/history`
- `/users/me/following/details`
- `/users/{user_id}/following/artists`
- `/artists/{deezer_id}/profile`
- `/radio/stations`
- `/weather/current`
- `/lyrics/search`
