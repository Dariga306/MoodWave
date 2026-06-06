# MoodWave deployment guide

This project is split into two deployable parts:

- `moodwave-backend` - FastAPI API, PostgreSQL, Redis, uploads, notifications.
- `diplom-frontend` - Flutter Web app.

Recommended setup for the diploma demo:

- Backend: Railway
- Frontend: Firebase Hosting
- Database/cache: Railway PostgreSQL + Railway Redis

## 1. Before deploying

Make sure these files are not committed:

- `moodwave-backend/.env`
- `moodwave-backend/firebase-credentials.json`

The repository already ignores them. Use `moodwave-backend/.env.production.example` as the list of production variables.

## 2. Deploy the backend to Railway

1. Push the project to GitHub.
2. Open Railway and create a new project from the GitHub repository.
3. Select the `moodwave-backend` folder as the service root if Railway asks for the root directory.
4. Add a PostgreSQL service.
5. Add a Redis service.
6. Open the backend service variables and add production values from:

```text
moodwave-backend/.env.production.example
```

Important variables:

```env
APP_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
SECRET_KEY=generate-a-long-random-secret
FRONTEND_URL=https://your-frontend-domain.web.app
CORS_ORIGINS=https://your-frontend-domain.web.app
OPENWEATHER_API_KEY=...
YOUTUBE_API_KEY=...
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
FIREBASE_CREDENTIALS_JSON={...full Firebase service account JSON...}
FIREBASE_STORAGE_BUCKET=...
```

If avatars, banners, chat images, and uploaded media must survive redeploys, attach a Railway volume and mount it to:

```text
/app/uploads
```

Without persistent storage, uploaded files can disappear after a rebuild/restart.

Railway will run migrations automatically before starting the server:

```bash
alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

After deploy, check:

```text
https://your-backend.up.railway.app/health
https://your-backend.up.railway.app/docs
```

## 3. Build the Flutter frontend

Open PowerShell:

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
.\scripts\build-web-prod.ps1 -ApiBaseUrl "https://your-backend.up.railway.app"
```

The important part is `API_BASE_URL`. In production it must be the public HTTPS backend URL, not `localhost`.

## 4. Deploy the frontend to Firebase Hosting

Install Firebase CLI once:

```powershell
npm install -g firebase-tools
firebase login
```

From the frontend folder:

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
firebase deploy --only hosting
```

The frontend already has `firebase.json` configured for Flutter Web:

- public folder: `build/web`
- SPA rewrite: `/index.html`

After Firebase gives you a URL, for example:

```text
https://your-project.web.app
```

put that URL into Railway backend variables:

```env
FRONTEND_URL=https://your-project.web.app
CORS_ORIGINS=https://your-project.web.app
```

Then redeploy/restart the backend service.

## 5. If domains or API URLs change

If the Railway backend URL changes, rebuild and redeploy the frontend:

```powershell
cd C:\Users\Asus\diplom\diplom-frontend
.\scripts\build-web-prod.ps1 -ApiBaseUrl "https://new-backend-url.up.railway.app"
firebase deploy --only hosting
```

If the Firebase frontend URL changes, update Railway:

```env
FRONTEND_URL=https://new-frontend-url.web.app
CORS_ORIGINS=https://new-frontend-url.web.app
```

## 6. Firebase and OAuth settings

If Firebase Authentication is used, add the frontend domain in Firebase Console:

```text
Authentication -> Settings -> Authorized domains
```

Add:

```text
your-project.web.app
your-project.firebaseapp.com
```

If Google or Spotify OAuth callbacks are used, add the production callback URLs in the matching developer consoles.

## 7. Phone checklist for the diploma committee

Open the Firebase Hosting URL on a phone and check:

- login/register works;
- profile avatar and banner load after refresh;
- weather playlists play;
- the weather header shows real active listeners only when someone is listening;
- shuffle buttons work from weather and playlist screens;
- chat messages, pinned messages, unpin, and local removal of someone else's pin work;
- notifications appear for follows, saved playlists, likes/reactions, messages, and other enabled events;
- no request in browser DevTools points to `localhost` or `127.0.0.1`.

For the demo, create a QR code from the Firebase Hosting URL so the committee can open the app quickly from their phones.
