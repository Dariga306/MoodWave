# MoodWave

Мобильное приложение — музыка, рекомендации по настроению и погоде, матчинг, чат, совместное прослушивание.

**Авторы:** Sabina Jamayeva, Dariga Nurgaliyeva
**Научрук:** Omirgaliyev Ruslan
**Astana IT University · 2026**

---

## Перед запуском

Получи у автора два файла и положи их в `moodwave-backend/`:

- `.env`
- `firebase-credentials.json`

---

## Backend (запускать первым)

```bash
cd moodwave-backend
docker compose up --build
```

Готов когда появится: `INFO: Application startup complete.`
Проверка: [http://localhost:8000/docs](http://localhost:8000/docs)

**Первый запуск — миграции** (в отдельном терминале):

```bash
docker exec moodwave-backend-api-1 alembic upgrade head
```

**Создать администратора** (один раз):

1. Зарегистрируйся через [http://localhost:8000/docs](http://localhost:8000/docs) → `POST /auth/register`
2. Выдай права:

```bash
docker exec -it moodwave-backend-db-1 psql -U moodwave -d moodwave \
  -c "UPDATE users SET is_admin = true WHERE email = 'твой@email.com';"
```

---

## Admin панель

```bash
cd admin-panel
npm install
echo "VITE_API_URL=http://localhost:8000" > .env
npm run dev
```

Открой [http://localhost:5173](http://localhost:5173) — войди с аккаунтом администратора.

---

## Flutter приложение

```bash
cd diplom-frontend
flutter pub get
flutter run
```

> На реальном Android устройстве замени `localhost` на IP компьютера в `lib/services/api_service.dart`.

---

## Запуск всего вместе

| Терминал | Команда |
|----------|---------|
| 1 | `cd moodwave-backend && docker compose up` |
| 2 | `cd admin-panel && npm run dev` |
| 3 | `cd diplom-frontend && flutter run` |

Порядок важен — сначала бэкенд.

---

## Остановить

```bash
cd moodwave-backend && docker compose down
# Flutter и Admin — Ctrl+C
```

---

## Postman

Импортируй `moodwave-backend/postman/MoodWave.postman_collection.json` → **File → Import**.
После запроса **Login** токен сохраняется автоматически.

---

## Порты

| Сервис | Адрес |
|--------|-------|
| API | http://localhost:8000 |
| Swagger | http://localhost:8000/docs |
| Admin | http://localhost:5173 |
| PostgreSQL | localhost:5434 |
| Redis | localhost:6379 |

---

## Проблемы

| Проблема | Решение |
|----------|---------|
| Docker не запускается | Запусти Docker Desktop |
| Порт занят | Перезагрузи компьютер |
| `alembic` ошибка | Подожди 15 сек после `docker compose up` и повтори |
| Flutter не видит бэкенд | Проверь что [http://localhost:8000/docs](http://localhost:8000/docs) открывается |
| Admin: "Not authorized" | Выдай права `is_admin = true` (см. выше) |

---

## Стек

| | |
|-|--|
| Mobile | Flutter 3, Dart |
| Backend | Python 3.12, FastAPI, PostgreSQL 16, Redis 7 |
| Real-time | Firebase Realtime DB, FCM, WebSocket |
| Admin | React, Vite, TypeScript, Ant Design |
| Deploy | Railway.app, Docker |
