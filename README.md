# Khojlo

An AI‑powered platform to discover, promote, and connect local businesses and customers.
Khojlo surfaces the new, the unusual and the underrated — before everyone else finds them.
This repository is working towards the **60% evaluation** of the Final Year Project.

- **Frontend:** Flutter + Riverpod (`frontend/`)
- **Backend:** FastAPI + PostgreSQL (`backend/`)
- **Design source of truth:** `docs/design/Khojlo App.dc.html` (Claude Design bundle → 19 iOS screens)
- **Documentation:** `docs/README.md` (requirements, design, roadmap and module records)

## Scope

Per `docs/development_roadmap/implementation_plan.md`, Modules 1–4 were built **production‑ready**
(full frontend + backend + validation + state + DB) for the 30% evaluation, and Modules 5 and 6
followed for the 60% evaluation. The rest are **high‑fidelity prototypes** (UI‑complete, navigable,
mock data) until their phase.

| Module | Status |
| --- | --- |
| 1. User Authentication & Profile | ✅ Production (Flutter + FastAPI + Postgres) |
| 2. Business Registration & Management | ✅ Production |
| 3. Business Discovery Feed | ✅ Production · 🔨 push notifications (60%) |
| 4. Search / Filter / Compare | ✅ Production |
| 5. Reviews & Ratings | ✅ Production |
| 6. Maps & Location | ✅ Production |
| 7. AI Chatbot (Kai) | 🎨 Prototype (100%) |
| 8. Admin & Moderation | 🎨 Prototype · planned for 60% |
| 9. Chat & Messaging | 🎨 Prototype · 🔨 in progress (60%) |
| 10. AI Personalization | 🎨 Folded into Home + prototypes (100%) |

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
`admin@khojlo.app`, plus demo reviewers such as `ayesha.khan@khojlo.app` (Module 5).

> `python -m app.db.seed` is safe on the shared team database: it adds missing demo accounts
> and businesses and refreshes the demo owner's catalogue businesses, but never deletes a
> user or anyone else's business. `python -m app.db.seed --reset` wipes every user and
> business first — use it only on a local or disposable database.
>
> If the app says "Couldn't load your feed" while the backend is running, the database is
> probably missing a migration: the API logs a warning at startup, and `alembic upgrade head`
> fixes it.

Module 5 demo: as the customer, open any business, scroll to **Reviews** and tap **Write a
review** (confetti on submit). Open **See all** to sort, filter by stars and mark reviews helpful,
then check **Profile → My reviews**. As the owner, use **Business → Reviews & replies** to answer
reviews. Ratings everywhere come from real reviews.

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

**On a physical Android phone** `10.0.2.2` doesn't exist, so point the app at the PC:

- *Over adb (USB or wireless debugging), recommended.* Tunnel the phone's port 8000 to the PC.
  No firewall change is needed, and the server stays private. Re-run `adb reverse` whenever the
  phone reconnects.

  ```bash
  adb reverse tcp:8000 tcp:8000
  flutter run --dart-define=KHOJLO_API=http://127.0.0.1:8000/api/v1
  ```

- *Over Wi-Fi without adb.* Run the backend with `uvicorn app.main:app --reload --host 0.0.0.0`,
  allow inbound TCP 8000 in Windows Firewall on a **Private** network, and run with
  `--dart-define=KHOJLO_API=http://<PC's Wi-Fi IP>:8000/api/v1`. The IP can change when the
  router reassigns it.

You can put `KHOJLO_API` in `dart_defines.json` instead of passing it on each run.

**Maps (Module 6).** Google Maps keys are read from the gitignored `frontend/dart_defines.json`
(copy `dart_defines.example.json`) via `flutter run --dart-define-from-file=dart_defines.json`.
Address lookup uses `GOOGLE_MAPS_SERVER_KEY` in `backend/.env`. Without keys the app shows a
built-in preview map. Setup steps are in `docs/development_roadmap/module6_maps_location_plan.md`.

## End‑to‑end demo path

Register a **business owner** → complete the registration stepper → the business appears in the
Discovery feed → register a **customer** → save it → see it in Saved/Profile → open Business
Detail → tab through Explore / Map / Chat / Business and the prototype screens.
