# MoodWave

MoodWave is a diploma project — a music application with mood and weather-based recommendations, music taste matching, chat, and shared listening.

**Authors:** Sabina Jamayeva, Dariga Nurgaliyeva  
**Supervisor:** Omirgaliyev Ruslan  
**Astana IT University · 2026**

---

## Technology Stack

| | |
|---|---|
| Mobile / Web | Flutter 3, Dart |
| Backend | Python 3.12, FastAPI, PostgreSQL 16, Redis 7 |
| Authentication | Firebase Auth (Google, Email + verification) |
| Music | Deezer API, iTunes Preview, lrclib.net (lyrics) |
| Player | YouTube IFrame API (full tracks), just_audio (previews) |
| Real-time | WebSocket, Firebase Realtime Database |
| Admin | React, Vite, TypeScript, Ant Design |
| Infrastructure | Docker, Docker Compose |

---

## Features

- Registration and login (Email + verification, Google OAuth)
- Email notifications: verification, password reset, new login alert
- Music recommendations based on mood and weather
- Music player with lyrics (lrclib.net sync, Spotify-style)
- Shuffle, Repeat (off / all / one), automatic track advance
- Artist page: popular tracks, discography, similar artists, follow
- Album page: full track list, play all
- Search tracks and artists (Russian and English)
- Listening history in search (Recently Played)
- User matching by music taste
- Chat with matched users
- Playlist library
- Admin panel for user and content management

---

## Running the Project

### Required files

Put the following files into `moodwave-backend/` before running:
- `.env`
- `firebase-credentials.json`

---

### 1. Backend

```bash
cd moodwave-backend
docker compose up --build
```

The backend is ready when logs show: `INFO: Application startup complete.`  
Swagger UI: http://localhost:8000/docs

**First run — apply database migrations:**

```bash
docker exec moodwave-backend-api-1 alembic upgrade head
```

Or run without Docker:

```bash
cd moodwave-backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

### 2. Admin panel

```bash
cd admin-panel
npm install
echo "VITE_API_URL=http://localhost:8000" > .env
npm run dev
```

Open http://localhost:5173

To grant admin rights:

```sql
UPDATE users SET is_admin = true WHERE email = 'your@email.com';
```

---

### 3. Flutter app (Web)

```bash
cd diplom-frontend
flutter pub get
flutter run -d chrome --web-port 5005
```

Open http://localhost:5005

---

### Run everything together

| Terminal | Command |
|----------|---------|
| 1 | `cd moodwave-backend && docker compose up` |
| 2 | `cd admin-panel && npm run dev` |
| 3 | `cd diplom-frontend && flutter run -d chrome --web-port 5005` |

---

## Ports

| Service | URL |
|--------|-----|
| API | http://localhost:8000 |
| Swagger | http://localhost:8000/docs |
| Admin | http://localhost:5173 |
| Flutter Web | http://localhost:5005 |
| PostgreSQL | localhost:5434 |
| Redis | localhost:6379 |

---

## Troubleshooting

| Issue | Solution |
|----------|---------|
| Docker does not start | Start Docker Desktop |
| Port is busy | Use `netstat -ano` to find PID, then `taskkill /PID <pid> /F` |
| Alembic error | Wait 15 seconds after `docker compose up` and retry |
| Flutter cannot reach backend | Check http://localhost:8000/docs |
| Admin: "Not authorized" | `UPDATE users SET is_admin = true WHERE email = 'your@email.com';` |
| Email not delivered | Check `MAIL_USERNAME` and `MAIL_PASSWORD` in `.env` |
