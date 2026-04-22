# MoodWave

MoodWave — дипломный проект, музыкальное приложение с рекомендациями на основе настроения и погоды, матчингом по музыкальному вкусу, чатом и совместным прослушиванием.

**Авторы:** Джамаева Сабина, Нургалиева Дарига  
**Научный руководитель:** Омиргалиев Руслан  
**Astana IT University · 2026**

---

## Технологический стек

| | |
|---|---|
| Mobile / Web | Flutter 3, Dart |
| Backend | Python 3.12, FastAPI, PostgreSQL 16, Redis 7 |
| Аутентификация | Firebase Auth (Google, Email + верификация) |
| Музыка | Deezer API, lrclib.net (синхронизированные тексты) |
| Плеер | YouTube IFrame API (полные треки), just_audio (превью) |
| Real-time | WebSocket, Firebase Realtime Database |
| Админ-панель | React, Vite, TypeScript, Ant Design |
| Инфраструктура | Docker, Docker Compose |

---

## Функциональность

- Регистрация и вход (Email + верификация, Google OAuth)
- Email-уведомления: верификация, сброс пароля, новый вход
- Рекомендации треков по настроению и погоде (Live Weather → Play Vibes)
- Плеер с синхронизированными текстами (lrclib.net, Spotify-стиль, тап по строке → перемотка)
- Shuffle, Repeat (выкл / все / одна), автопереход между треками
- Страница артиста: популярные треки, дискография, похожие артисты, подписка
- "This Is {Artist}" — плейлист топ-треков (до 50 штук, с fallback через radio)
- Страница альбома: полный трек-лист, Play All, Shuffle
- Поиск треков и артистов (русский и английский, фаззи-матч)
- История прослушиваний с группировкой по датам (Recently Played + Listening History)
- Матчинг пользователей по музыкальному вкусу
- Чат с совпавшими пользователями
- Библиотека плейлистов
- Live Rooms — совместное прослушивание
- Radio For You — тематические радиостанции (Late Night, Morning Boost, Deep Focus)
- Choose Your Mood — плейлисты по настроению (Study, Sport, Drive, Sleep, Party, Sad)
- Hot Right Now — трендовые треки с бейджами NEW / HOT
- Топ-чарты по городам
- Админ-панель для управления пользователями и контентом

---

## Запуск проекта

### Необходимые файлы

Перед запуском положи в `moodwave-backend/`:
- `.env`
- `firebase-credentials.json`

---

### 1. Backend

```bash
cd moodwave-backend
docker compose up --build
```

Бэкенд готов когда в логах появится: `INFO: Application startup complete.`  
Swagger UI: http://localhost:8000/docs

**Первый запуск — применить миграции БД:**

```bash
docker exec moodwave-backend-api-1 alembic upgrade head
```

Без Docker:

```bash
cd moodwave-backend
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # Linux/macOS
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

### 2. Админ-панель

```bash
cd admin-panel
npm install
echo "VITE_API_URL=http://localhost:8000" > .env
npm run dev
```

Открыть http://localhost:5173

Выдать права администратора:

```sql
UPDATE users SET is_admin = true WHERE email = 'your@email.com';
```

---

### 3. Flutter (Web)

```bash
cd diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5005
```

Открыть http://localhost:5005

---

### Запуск всего сразу (3 терминала)

| Терминал | Команда |
|----------|---------|
| 1 | `cd moodwave-backend && docker compose up` |
| 2 | `cd admin-panel && npm run dev` |
| 3 | `cd diplom-frontend && flutter run -d chrome --web-port 5005` |

---

## Порты

| Сервис | URL |
|--------|-----|
| API | http://localhost:8000 |
| Swagger | http://localhost:8000/docs |
| Админ-панель | http://localhost:5173 |
| Flutter Web | http://localhost:5005 |
| PostgreSQL | localhost:5434 |
| Redis | localhost:6379 |

---

## Решение проблем

| Проблема | Решение |
|----------|---------|
| Docker не запускается | Запусти Docker Desktop |
| Порт занят | `netstat -ano` → найди PID → `taskkill /PID <pid> /F` |
| Ошибка Alembic | Подожди 15 сек после `docker compose up` и повтори |
| Flutter не достучится до бэкенда | Проверь http://localhost:8000/docs |
| Админ: "Not authorized" | `UPDATE users SET is_admin = true WHERE email = 'your@email.com';` |
| Письмо не приходит | Проверь `MAIL_USERNAME` и `MAIL_PASSWORD` в `.env` |
