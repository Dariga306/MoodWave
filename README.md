# MoodWave

MoodWave — дипломный музыкальный сервис: рекомендации по погоде и настроению, полноценный плеер, синхронизированные lyrics, библиотека, подписки на артистов, социальные функции, радио, чарты и админ-панель.

**Авторы:** Джамаева Сабина, Нургалиева Дарига  
**Научный руководитель:** Омиргалиев Руслан  
**Astana IT University, 2026**

## Что умеет приложение

- Home с блоками `Live Weather`, `Recently Played`, `You Might Like`, `AI Mixes`, `Choose Your Mood`, `Radio`, `This Is`, `Top in your city`, `Fresh Wave`, `Because you listened to` и `Friends are listening`.
- Плеер с полными треками через YouTube IFrame, мини-плеером, очередью, shuffle/repeat и переходами между треками.
- Lyrics через lrclib.net: синхронизированный текст, активная строка и переход к моменту песни по нажатию.
- Поиск треков, артистов и альбомов на русском и английском.
- Страницы артистов: топ-треки, альбомы, похожие артисты, follow/unfollow.
- `This Is ...` подборки по артистам.
- Библиотека: liked songs, плейлисты, сохранённые альбомы и подписки на артистов.
- Профиль: аватар, баннер, followers/following, отдельные страницы подписчиков и подписок.
- Погода и `Play Vibes`: подборка музыки под текущую погоду и город.
- Mood Explore: Happy, Sad, Chill, Romantic, Workout, Focus, Party, Rainy, Angry, Dreamy.
- Radio Explore: For You Radio, Mood Radio, Artist Radio, City Radio, Night Drive, Fresh Radio.
- City charts: треки, артисты, альбомы и плейлисты по городу.
- Социальные функции: музыкальный матчинг, друзья, чаты, listening rooms.
- Админ-панель для управления пользователями и мониторинга.

## Технологии

| Часть | Стек |
|---|---|
| Frontend | Flutter, Dart, Provider, Dio |
| Backend | Python 3.12, FastAPI, SQLAlchemy, Alembic |
| Database | PostgreSQL 16 |
| Cache / realtime jobs | Redis, APScheduler |
| Auth | Firebase Auth, JWT |
| Music data | Deezer API, YouTube, lrclib.net |
| Admin panel | React, Vite, TypeScript, Ant Design |
| Infra | Docker, Docker Compose |

## Структура проекта

```text
diplom/
├── diplom-frontend/      # Flutter app: web/mobile UI
├── moodwave-backend/     # FastAPI backend
├── admin-panel/          # React admin dashboard
└── README.md
```

## Требования

- Flutter SDK 3.x
- Python 3.12
- Node.js 18+
- PostgreSQL 16
- Redis 7
- Docker Desktop, если запускаешь backend через Docker

В `moodwave-backend/` должны быть:

- `.env`
- `firebase-credentials.json`

Пример переменных лежит в `moodwave-backend/.env.example`.

## Быстрый запуск

### 1. Backend

Если база и Redis уже настроены локально:

```powershell
cd C:\Users\Asus\diplom\moodwave-backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Backend должен открыть:

```text
http://127.0.0.1:8000
http://127.0.0.1:8000/docs
http://127.0.0.1:8000/health
```

Если порт `8000` занят:

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### 2. Flutter Web для разработки

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5001
```

Открыть:

```text
http://localhost:5001/
```

### 3. Flutter Web как production-сборка

Этот вариант удобен, когда нужно проверить именно собранный проект:

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
flutter build web --pwa-strategy=none
python -m http.server 5001 -d build\web --bind 127.0.0.1
```

Открыть:

```text
http://localhost:5001/
```

Если браузер показывает старую версию, нажми `Ctrl + F5`.

### 4. Admin panel

```powershell
cd C:\Users\Asus\diplom\admin-panel
npm install
Set-Content .env "VITE_API_URL=http://127.0.0.1:8000"
npm run dev
```

Открыть:

```text
http://localhost:5173/
```

## Запуск backend через Docker

```powershell
cd C:\Users\Asus\diplom\moodwave-backend
docker compose up --build
```

Миграции:

```powershell
docker exec moodwave-backend-api-1 alembic upgrade head
```

Docker-порты:

| Сервис | Порт |
|---|---|
| API | `8000` |
| PostgreSQL | `5434` |
| Redis | `6379` |

## Основные URL

| Назначение | URL |
|---|---|
| Flutter Web | `http://localhost:5001/` |
| Backend API | `http://127.0.0.1:8000/` |
| Swagger | `http://127.0.0.1:8000/docs` |
| Health check | `http://127.0.0.1:8000/health` |
| Admin panel | `http://localhost:5173/` |

## Полезные проверки

Backend:

```powershell
curl http://127.0.0.1:8000/health
```

Flutter:

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
flutter analyze
flutter build web --pwa-strategy=none
```

Backend Python:

```powershell
cd C:\Users\Asus\diplom\moodwave-backend
python -m py_compile app\main.py
```

## Частые проблемы

| Проблема | Что сделать |
|---|---|
| `WinError 10013` или порт `8000` занят | Найти PID через `netstat -ano \| findstr :8000` и остановить `taskkill /PID <PID> /F` |
| Frontend показывает старый Home | Нажать `Ctrl + F5`; при production-сборке использовать `--pwa-strategy=none` |
| Flutter не видит backend | Проверить `http://127.0.0.1:8000/health` |
| Подписки на артистов не отображаются | Проверить авторизацию и endpoint `/users/me/following/details` |
| Письма не приходят | Проверить `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` в `.env` |
| Firebase ошибка | Проверить `firebase-credentials.json` и `FIREBASE_DATABASE_URL` |
| Docker не запускается | Запустить Docker Desktop |

## Статус

Актуальный рабочий режим проекта:

- Backend: `127.0.0.1:8000`
- Flutter Web: `localhost:5001`
- Admin panel: `localhost:5173`
- Основной экран Home, Library, Following, Profile, Player и Search поддерживаются текущей backend-логикой.
