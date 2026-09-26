# Khojlo

An AI‑powered platform to discover, promote, and connect local businesses and customers.
Khojlo surfaces the new, the unusual and the underrated — before everyone else finds them.
This repository is the **30% evaluation build** of the Final Year Project.

- **Frontend:** Flutter + Riverpod (`frontend/`)
- **Backend:** FastAPI + PostgreSQL (`backend/`)
- **Design source of truth:** `docs/Khojlo App.dc.html` (Claude Design bundle → 19 iOS screens)

## Scope (30% evaluation)

Per `docs/development_roadmap/implementation_plan.md`, Modules 1–3 were built **production‑ready**
(full frontend + backend + validation + state + DB) for the 30% evaluation, and Module 4 has since
joined them (see `docs/development_roadmap/module4_search_filter_compare_plan.md`). The rest are
**high‑fidelity prototypes** (UI‑complete, navigable, mock data).

| Module | Status |
| --- | --- |
| 1. User Authentication & Profile | ✅ Production (Flutter + FastAPI + Postgres) |
| 2. Business Registration & Management | ✅ Production |
| 3. Business Discovery Feed (no push) | ✅ Production |
| 4. Search / Filter / Compare | ✅ Production |
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

alembic upgrade head                 # create / update schema (run after every pull)
python -m app.db.seed                # add / refresh demo data (safe, deletes nothing)
uvicorn app.main:app --reload        # http://localhost:8000  (Swagger at /docs)
```

Seeded logins (password `password123`): `owner@khojlo.app`, `customer@khojlo.app`,
`admin@khojlo.app`.

> `python -m app.db.seed` is safe on the shared team database: it adds missing demo accounts
> and businesses and refreshes the demo owner's catalogue businesses, but never deletes a
> user or anyone else's business. `python -m app.db.seed --reset` wipes every user and
> business first — use it only on a local or disposable database.
>
> If the app says "Couldn't load your feed" while the backend is running, the database is
> probably missing a migration: the API logs a warning at startup, and `alembic upgrade head`
> fixes it.

Module 4 demo: sign in as the customer, open **Explore**, search `unstitched fabric` (the SDD
mockup's Abbottabad tailors), filter, tick two results and tap **Compare**. Allow location to see
distances. Owners can set a price range, opening hours and a map pin from the dashboard.

Photos, categories and profiles: as the owner, open **Business → Photos** to add a cover and a
gallery (the cover appears on every card; without photos the listing's colour is used). Try
**Edit business profile → Other** with your own description, or search a local term such as
`darzi`. Anyone can open **Profile → Edit profile** to set a photo, phone number and interests.
Photos are stored in PostgreSQL (SDD §5.1), resized on upload, and cropped automatically to fit
each card.

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
