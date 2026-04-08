# MoodWave

Дипломный проект — музыкальное приложение с рекомендациями по настроению и погоде, матчингом по музыкальному вкусу, чатом и совместным прослушиванием.

**Авторы:** Sabina Jamayeva, Dariga Nurgaliyeva  
**Научный руководитель:** Omirgaliyev Ruslan  
**Astana IT University · 2026**

---

## Стек технологий

| | |
|---|---|
| Mobile / Web | Flutter 3, Dart |
| Backend | Python 3.12, FastAPI, PostgreSQL 16, Redis 7 |
| Аутентификация | Firebase Auth (Google, Email + верификация) |
| Музыка | Deezer API, iTunes Preview, lrclib.net (тексты) |
| Плеер | YouTube IFrame API (полные треки), just_audio (превью) |
| Real-time | WebSocket, Firebase Realtime Database |
| Admin | React, Vite, TypeScript, Ant Design |
| Инфраструктура | Docker, Docker Compose |

---

## Функциональность

- Регистрация и вход (Email + верификация, Google OAuth)
- Письма на почту: верификация, сброс пароля, уведомление о новом входе
- Подбор музыки по настроению и погоде
- Плеер с текстами песен (синхронизация с lrclib.net, Spotify-стиль)
- Shuffle, Repeat (off / all / one), автопереход треков
- Страница артиста: популярные треки, дискография, похожие артисты, Follow
- Страница альбома: все треки, Play all
- Поиск треков и артистов (русский и английский язык)
- История прослушивания в поиске (Recently Played)
- Матчинг пользователей по музыкальному вкусу
- Чат с совпавшими пользователями
- Библиотека плейлистов
- Admin-панель (управление пользователями и контентом)

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
Swagger UI: http://localhost:8000/docs

**Первый запуск — применить миграции:**

```bash
docker exec moodwave-backend-api-1 alembic upgrade head
```

Или без Docker:

```bash
cd moodwave-backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

### 2. Admin панель

```bash
cd admin-panel
npm install
echo "VITE_API_URL=http://localhost:8000" > .env
npm run dev
```

Открой http://localhost:5173

Чтобы дать права администратора:

```sql
UPDATE users SET is_admin = true WHERE email = 'your@email.com';
```

---

### 3. Flutter приложение (Web)

```bash
cd diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5005
```

Открой http://localhost:5005

---

### Запуск всего вместе

| Терминал | Команда |
|----------|---------|
| 1 | `cd moodwave-backend && docker compose up` |
| 2 | `cd admin-panel && npm run dev` |
| 3 | `cd diplom-frontend && flutter run -d chrome --web-port 5005` |

---

## Порты

| Сервис | Адрес |
|--------|-------|
| API | http://localhost:8000 |
| Swagger | http://localhost:8000/docs |
| Admin | http://localhost:5173 |
| Flutter Web | http://localhost:5005 |
| PostgreSQL | localhost:5434 |
| Redis | localhost:6379 |

---

## Решение проблем

| Проблема | Решение |
|----------|---------|
| Docker не запускается | Запустить Docker Desktop |
| Порт занят | `netstat -ano` найти PID, `taskkill /PID <pid> /F` |
| Alembic ошибка | Подождать 15 сек после `docker compose up` и повторить |
| Flutter не видит бэкенд | Проверить http://localhost:8000/docs |
| Admin: "Not authorized" | `UPDATE users SET is_admin = true WHERE email = 'your@email.com';` |
| Email не приходит | Проверить `MAIL_USERNAME` и `MAIL_PASSWORD` в `.env` |
