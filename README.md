# MoodWave

Дипломный проект — музыкальное приложение с рекомендациями по настроению и погоде, матчингом по музыкальному вкусу, чатом и совместным прослушиванием.

**Авторы:** Sabina Jamayeva, Dariga Nurgaliyeva  
**Научный руководитель:** Omirgaliyev Ruslan  
**Astana IT University · 2026**

---

## Стек технологий

| | |
|---|---|
| Mobile/Web | Flutter 3, Dart |
| Backend | Python 3.12, FastAPI, PostgreSQL 16, Redis 7 |
| Аутентификация | Firebase Auth (Google, Email) |
| Музыка | Spotify Web Playback SDK, iTunes API, lrclib.net |
| Real-time | WebSocket, Firebase |
| Admin | React, Vite, TypeScript, Ant Design |
| Инфраструктура | Docker, Docker Compose |

---

## Запуск проекта

### Необходимые файлы

Перед запуском положи в папку `moodwave-backend/`:
- `.env`
- `firebase-credentials.json`

---

### 1. Backend

```bash
cd moodwave-backend
docker compose up --build
```

Готов когда в логах появится: `INFO: Application startup complete.`  
Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)

**Первый запуск — применить миграции:**

```bash
docker exec moodwave-backend-api-1 alembic upgrade head
```

---

### 2. Admin панель

```bash
cd admin-panel
npm install
echo "VITE_API_URL=http://localhost:8000" > .env
npm run dev
```

Открой [http://localhost:5173](http://localhost:5173)

---

### 3. Flutter приложение (Web)

```bash
cd diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5004
```

Открой [http://localhost:5004](http://localhost:5004)

---

### Запуск всего вместе

| Терминал | Команда |
|----------|---------|
| 1 | `cd moodwave-backend && docker compose up` |
| 2 | `cd admin-panel && npm run dev` |
| 3 | `cd diplom-frontend && flutter run -d chrome --web-port 5004` |

---

## Порты

| Сервис | Адрес |
|--------|-------|
| API | http://localhost:8000 |
| Swagger | http://localhost:8000/docs |
| Admin | http://localhost:5173 |
| Flutter Web | http://localhost:5004 |
| PostgreSQL | localhost:5434 |
| Redis | localhost:6379 |

---

## Функциональность

- Регистрация и вход (Email, Google OAuth)
- Подбор музыки по настроению и погоде
- Матчинг пользователей по музыкальному вкусу
- Чат с совпавшими пользователями
- Плеер с текстами песен (синхронизация с lrclib.net)
- Подключение Spotify Premium для полного воспроизведения
- Библиотека плейлистов
- Поиск треков и артистов (русский и английский язык)

---

## Решение проблем

| Проблема | Решение |
|----------|---------|
| Docker не запускается | Запустить Docker Desktop |
| Порт занят | `taskkill /F /IM flutter_tools.snapshot.exe` |
| Alembic ошибка | Подождать 15 сек после `docker compose up` и повторить |
| Flutter не видит бэкенд | Проверить [http://localhost:8000/docs](http://localhost:8000/docs) |
| Admin: "Not authorized" | Выдать права через psql: `UPDATE users SET is_admin = true WHERE email = 'your@email.com';` |
