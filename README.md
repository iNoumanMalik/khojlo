# Khojlo

An AI‑powered platform to discover, promote, and connect local businesses and customers.
Khojlo surfaces the new, the unusual and the underrated — before everyone else finds them.
This repository is the **30% evaluation build** of the Final Year Project.

- **Frontend:** Flutter + Riverpod (`frontend/`)
- **Backend:** FastAPI + PostgreSQL (`backend/`)
- **Design source of truth:** `docs/Khojlo App.dc.html` (Claude Design bundle → 19 iOS screens)

## Scope (30% evaluation)

Per `docs/development_roadmap/implementation_plan.md`, three modules are **production‑ready**
(full frontend + backend + validation + state + DB), the rest are **high‑fidelity prototypes**
(UI‑complete, navigable, mock data).

| Module | Status |
| --- | --- |
| 1. User Authentication & Profile | ✅ Production (Flutter + FastAPI + Postgres) |
| 2. Business Registration & Management | ✅ Production |
| 3. Business Discovery Feed (no push) | ✅ Production |
| 4. Search / Filter / Compare | 🎨 Prototype |
| 5. Reviews & Ratings | 🎨 Prototype |
| 6. Maps & Location | 🎨 Prototype |
| 7. AI Chatbot (Kai) | 🎨 Prototype |
| 8. Admin & Moderation | 🎨 Prototype |
| 9. Chat & Messaging | 🎨 Prototype |
| 10. AI Personalization | 🎨 Folded into Home + prototypes |

## Design system

Extracted verbatim from the design bundle: colours (Ink `#2B2620`, Cream `#FBF6EE`, Gold
`#E3A73D`, Emerald `#1D6D5A`, Plum `#7A3350`, Coral `#F2C9C1`), fonts (Fraunces / Plus Jakarta
Sans / IBM Plex Mono), frosted‑glass surfaces, and a floating 5‑tab dock
(**Home · Explore · Map · Chat · Business**). Implemented once in `frontend/lib/core/`.

---

## Running the backend

Requires Python 3.14 and PostgreSQL (Docker **or** a local install).

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                 # adjust DATABASE_URL if needed

# Option A — Docker Postgres
docker compose up -d

# Option B — local Postgres: create role/db "khojlo" (see .env)

alembic upgrade head                 # create schema
python -m app.db.seed                # demo categories + businesses + users
uvicorn app.main:app --reload        # http://localhost:8000  (Swagger at /docs)
```

Seeded logins (password `password123`): `owner@khojlo.app`, `customer@khojlo.app`,
`admin@khojlo.app`.

Run the API tests (in‑memory SQLite, no Postgres needed):

```bash
cd backend && source .venv/bin/activate && pytest
```

## Running the frontend

Requires Flutter 3.41+.

```bash
cd frontend
flutter pub get
flutter run                          # or: flutter run -d chrome
flutter analyze                      # clean
flutter test
```

The app resolves the API base URL per platform (`localhost:8000` on web/desktop,
`10.0.2.2:8000` on the Android emulator). Override with
`--dart-define=KHOJLO_API=http://<host>:8000/api/v1`.

## End‑to‑end demo path

Register a **business owner** → complete the registration stepper → the business appears in the
Discovery feed → register a **customer** → save it → see it in Saved/Profile → open Business
Detail → tab through Explore / Map / Chat / Business and the prototype screens.
