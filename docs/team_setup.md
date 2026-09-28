# Team Setup: What to Share With a Teammate

Cloning the repository gives a teammate all the code, but not the private settings the app needs. This page lists exactly what to hand over, privately, so everyone's copy works the same way.

**Keep this page up to date.** Whenever a module adds a new key or config file, add a row here in the same change.

*Last updated: 28 Sep 2026 (Module 9: chat and push notifications).*

## At a glance

| File | In git? | Share it? | What it's for |
|---|---|---|---|
| `backend/.env` | No (gitignored) | **Yes, privately:** the values in the table below | The backend's settings and secrets: database, email, keys. |
| `backend/.env.example` | Yes | No need | Template for `backend/.env`. Placeholders only, never real values. |
| `backend/secrets/firebase-service-account.json` | No (gitignored) | **Yes, privately** | Lets the backend **send** push notifications through Firebase. |
| `frontend/dart_defines.json` | No (gitignored) | **Yes, privately** (or they build it from the example) | The app's build-time settings: Firebase web settings, Web Push key, Maps keys. |
| `frontend/dart_defines.example.json` | Yes | No need | Template for `frontend/dart_defines.json`. |
| `frontend/android/app/google-services.json` | Yes | No need | The Android app's Firebase and Google Sign-In settings. Public by design. |

"Privately" means a direct message to that teammate, or a shared password manager. Never a public channel, an email to a group, a screenshot, a GitHub issue or an AI chat.

## `backend/.env`: which values to share

Tell them to copy the template first (`cp backend/.env.example backend/.env`), then fill these in:

| Setting | Share? | Notes |
|---|---|---|
| `DATABASE_URL` | **Yes**, if they use the shared Supabase database | The Supabase connection URL. Any `%` in the password must be written as `%25`. Leave the default to use a local database instead. |
| `SECRET_KEY` | Optional | Signs login tokens. Each person's backend can have its own; generate one with `python -c "import secrets; print(secrets.token_urlsafe(48))"`. |
| `GOOGLE_WEB_CLIENT_ID` | Yes | Needed for "Continue with Google". Not secret, but it has to be the right one. |
| `SMTP_*` | Yes, if they need real emails | The Gmail app password for verification and reset codes. Without it, no emails are sent. |
| `GOOGLE_MAPS_SERVER_KEY` | Yes, if they need address lookup | Without it, address lookup is hidden and typed addresses still work. |
| `GOOGLE_APPLICATION_CREDENTIALS` | No: the default path is already right | Points to the Firebase key file below. |
| Everything else | No | Safe defaults are already in the template. |

## `backend/secrets/firebase-service-account.json`

- Put it at exactly that path. `GOOGLE_APPLICATION_CREDENTIALS` in `.env` already points there.
- Without it, that teammate's backend sends no push notifications; chat and everything else still work.
- It's the most sensitive file here, because it can send notifications as the project. Instead of passing the same file around, a teammate with Firebase access can make their own: Firebase Console → Project settings → Service accounts → Generate new private key.

## `frontend/dart_defines.json`

- Copy yours, or let them build it from `frontend/dart_defines.example.json`.
- `FIREBASE_*` and `FIREBASE_WEB_VAPID_KEY`: push notifications on the **web**. The values come from Firebase Console → Project settings → Your apps → Khojlo Web. They aren't secret (every browser receives them), but they're kept out of git so keys are handled one way throughout the project.
- `MAPS_API_KEY_WEB` and `MAPS_API_KEY_ANDROID`: real Google Maps. Without them the app shows a drawn preview map.
- Leave `KHOJLO_API` empty unless they run the backend on another machine (see the README for phones).
- Run the app with it: `flutter run --dart-define-from-file=dart_defines.json` (add `-d chrome` for the web).

## Accounts to add them to

| Service | Where | Why |
|---|---|---|
| Firebase / Google Cloud (`khojlo-c5ba0`) | Firebase Console → Project settings → Users and permissions | Only if they work on push notifications, Google Sign-In or Maps keys. |
| Supabase | Supabase dashboard → Project → Settings → Team | Only if they manage the shared database (running migrations). The `DATABASE_URL` alone is enough to use it. |
| GitHub | Repository → Settings → Collaborators | To push branches. |

## New teammate checklist

1. Clone the repository. Follow `README.md` for Python, Flutter and the database.
2. Receive `backend/.env` values, `backend/secrets/firebase-service-account.json` and `frontend/dart_defines.json`, privately.
3. Backend: `cd backend && alembic upgrade head && python -m app.db.seed && uvicorn app.main:app --reload`, run from inside `backend/` so the key file's relative path works.
4. App: `cd frontend && flutter pub get && flutter run --dart-define-from-file=dart_defines.json`.
5. Sign in with a demo account (`customer@khojlo.app` / `owner@khojlo.app`, password `password123`).

## If something leaks

| What leaked | Do this |
|---|---|
| Supabase database password | Supabase → Project Settings → Database → **Reset database password**; update `DATABASE_URL` for everyone. |
| Firebase service account key | Firebase Console → Project settings → Service accounts → Manage service account permissions → delete that key, then generate a new one. |
| `SECRET_KEY` | Generate a new one. Everyone gets signed out once. |
| Gmail app password | Google Account → Security → App passwords → revoke it, then create a new one. |
| Google Maps server key | Google Cloud Console → Credentials → regenerate or delete the key. |
