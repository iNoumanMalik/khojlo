# Module 4 — Search, Filtering & Comparison: Plan and Implementation Record

**Owner:** Sayyam Tahir (SP23-BSE-014) · **Branch:** `dev` · **Status:** Implemented, not yet committed. Decisions D1–D4 confirmed on 26 Sep 2026.

**Sources:** `docs/requirements/SRS.pdf`, `SDD.pdf` and `Feasibility_Report.pdf` (the updated versions), plus `docs/design/` and the design bundle `docs/Khojlo App.dc.html`.

Goal: replace the Module 4 prototype (mock data only) with a production feature at the same bar as Modules 1–3. That means a real backend search engine, filters, comparison and search history, a Flutter UI wired to the API, validation, database changes, and tests.

---

## 1. What the documents require

| Source | Requirement | How it is covered |
|---|---|---|
| Feasibility report, Module 4 | Search by keywords, categories, location. Filter by price range, category, services. Compare on pricing, services, overall value. | `GET /search` with keyword, category and location strategies plus filters. `GET /compare`. |
| SRS UC-4 Search Businesses | Enter keyword, search, display. Alternative: new keyword. Exception: no results. Rule: rank by relevance. | Relevance ranking, live re-search as the keyword changes, a friendly empty state. |
| SRS UC-5 Filter and Compare Businesses | Apply filters, select businesses, compare. Alternative: clear filters. Exception: comparison unavailable. Rule: maximum comparison limit. | Filters combine; "Clear all" chips and a "Reset" button; compare 2–3 places (limit enforced in the app and by the API); an error state with retry. |
| SRS FR-3 | Search by keywords and categories. | `q` and `category` parameters. |
| SRS FR-4 | Filter by category, location and price. | `category`, `lat`/`lng`/`radius_km`, `price`, `min_price`/`max_price`. |
| SRS FR-5 BR-3, UC-6 | Only verified profiles displayed. | Decision D1. |
| SRS USE-1 | Search within 3 interactions from Home. | Tap the Home search pill (focuses the field), type, submit. |
| SRS USE-3 | Clear validation messages. | 422 errors with a readable `detail`, shown in the UI. |
| SRS USE-4 | Open details from a result in one tap. | Tapping a row opens `/business/:id`. |
| SRS PER-2 | Results within 3 s for 95% of searches. | SQL prefilter, eager loading, indexes, paging. A 500-business timing test. |
| SDD class diagram | `SearchEngine` with `setSearchStrategy()` and `search()`. `SearchStrategy` implemented by `KeywordSearch`, `CategorySearch`, `LocationSearch(lat, lng, radius)`. `Customer.searchBusinesses(query, filters)`, `compareBusinesses(list)`. | Same class names in `backend/app/services/search/`. See section 7. |
| SDD Algorithms 2, 3, 11 | Search with keyword and filters, then sort. Compare price, rating, services, offers, distance. Run a strategy and return results. | `SearchEngine.search()`, `compare_service.build_comparison()`, `SearchEngine.run()`. |
| SDD Screen 2 | Search field. Filters for price, rating, distance, category. Selectable result cards. Compare button. | Check circles on rows and a sticky "Compare N businesses" bar, as in the mockup. |
| SDD traceability | FR06 Search, FR07 Filter, FR08 Compare. | Covered by the backend tests (section 6). |
| Design bundle (`KhojloSearch`, `KhojloCompare`) | Removable filter chips, "N places match", glass filter sheet, "Show N results". Compare: "2 of 3 places" cards with ×, attribute rows, "View both on map". | Followed as the visual source of truth. |
| `modules_layout.md`, Module 4 | Recent, Popular, Categories, Filters, AI Suggestions. Map toggle, AI Summary, floating Compare button. Animated "A vs B vs C" compare cards. | Recent and Popular are real. The summary is rule-based until Module 7. The map toggle goes to Module 6. |

---

## 2. Decisions (confirmed 26 Sep 2026)

**D1. Verified-only results.** SRS FR-5 BR-3 and UC-6 say only verified profiles are shown, but admin verification (Module 8) doesn't exist yet and new businesses start unverified.
*Decision:* search shows all published businesses, with a "Verified only" filter and a Verified badge. Switch the default once Module 8 ships.

**D2. Price data.** The documents ask for a price-range filter and price comparison; the SDD mockup shows "Rs 800–2500". The model only had a `$`/`$$`/`$$$` tier.
*Decision:* optional `price_min` and `price_max` in PKR on each business, captured at registration and in the edit screen, shown as "Rs 800–2,500". The tier stays for the quick filter.

**D3. Location and hours data.** Distance and "Open now" need the device location, business coordinates and opening hours, and the app captured none of them.
*Decision:* device location via `geolocator`, a "Use my current location" button and an opening-hours step in registration. The full map picker stays in Module 6.

**D4. Compare layout.** The SDD and design bundle show a table; `modules_layout.md` asks for animated cards. "Wait time" and "Vibe" have no data.
*Decision:* animated VS cards on top, attribute rows below, the best value in each row highlighted, Wait time and Vibe dropped, no computed "value score". Two to three places.

---

## 3. What was built

### 3.1 Backend (FastAPI)

**Endpoints (all under `/api/v1`)**

| Method and path | Purpose |
|---|---|
| `GET /search` | Search and filter. Public; records history for the signed-in user when `record=true`. |
| `GET /search/suggestions?q=` | Typeahead: categories, businesses, services (word-prefix matches only). |
| `GET /search/popular` | Top searches of the last 30 days that found results, topped up with category names. |
| `GET /search/history`, `DELETE /search/history` | The signed-in user's recent searches; clear them. |
| `GET /compare?ids=1&ids=2[&ids=3][&lat=&lng=]` | Compare 2–3 businesses, with the winner of each row. |
| `PUT /businesses/{id}/hours` | Owner replaces the weekly opening hours (empty list clears them). |
| `GET /businesses/{id}?track=false` | Detail without counting a profile view (used by the owner's edit screens). |

`GET /search` parameters: `q`, `category` (repeatable), `price` (`$`, `$$`, `$$$`, repeatable), `min_price`, `max_price`, `min_rating`, `open_now`, `has_offer`, `verified_only`, `lat`, `lng`, `radius_km` (0.5–50), `sort` (`relevance`, `distance`, `rating`, `price_low`, `price_high`, `newest`, `popular`), `limit` (1–50), `offset`, `record`. Invalid combinations return 422 with a readable message, for example a distance filter without a location.

**Search engine** (`backend/app/services/search/`)
- `strategies.py` holds the SDD's `SearchStrategy` interface with `KeywordSearch`, `CategorySearch` and `LocationSearch`, plus price, rating, offer, verified and open-now filters. Each narrows candidates in SQL first, then confirms in Python what SQL can't do portably across SQLite and Postgres.
- Keyword matching ignores case and accents ("cafe" finds "Cafés"), drops filler words ("gym near me"), and keeps sector names like "F-7" whole.
- A multi-word search that matches nothing falls back to "any word" and says so (`relaxed: true`).
- `ranking.py` scores where each word matches: name first, then category, services, tagline, address, description. Ties go to new businesses, then nearer, then better rated, so popularity never beats a better match.
- The response includes a short rule-based summary ("3 places · mostly $ · 2 open now · avg ★ 4.6 · nearest 0.4 km").

**"Open now"** (`services/hours.py`) is evaluated in `BUSINESS_TIMEZONE` (Asia/Karachi). Closing earlier than opening means after midnight; equal times mean 24 hours; no hours at all means "unknown", which is different from "closed".

**Data changes** (migration `71c2ae544c86`, additive only)
- `businesses.price_min`, `businesses.price_max`, `services.price_amount` (PKR, optional).
- A new `search_queries` table for recent and popular searches.
- Indexes on `businesses.category_id`, `created_at` and `is_published`.

**Validation added to business registration and editing:** prices can't be negative and "from" can't exceed "to"; latitude and longitude come as a pair; hours use `HH:MM` and each weekday appears once; the price tier must be `$`, `$$` or `$$$`.

**Seed data** now spans several Islamabad areas plus Abbottabad, including the four tailors from the SDD "unstitched fabric" mockup. It has rupee prices, varied hours (including overnight and 24-hour), some unverified and some new businesses, active and ended offers, and search history.

### 3.2 Flutter app

- **Explore tab** (`features/search/`)
  - Idle view: an oversized search field with rotating hints, Recent searches (with Clear), Popular now, category chips, and a location prompt when needed.
  - Typing runs a debounced live search and shows typeahead suggestions. Submitting saves the search to history.
  - Results: removable filter chips, "N places match", a sort menu, the summary card, rows showing distance, rupee range, rating, open or closed, and New, Offer and Verified badges. Paging on scroll, skeleton loading, friendly empty and error states.
  - Filter sheet: price tiers, a rupee budget range slider, rating, a distance slider (asks for location when needed), Open now, Has an offer, Verified only, categories, and a live "Show N results" button.
- **Compare** (`/compare`): animated VS cards with remove buttons and an "Add a place" slot, then rows for price, rating, distance, open now, services, offers, category, saves and verified, with the best value highlighted. "View on map" waits for Module 6.
- **Selection** is shared app-wide: pick places from results or with the new "Compare" action on a business page (limit of three).
- **Home:** the search pill opens Explore with the keyboard up; category chips open Explore with that category applied.
- **Business detail:** shows the rupee range and open status, plus the Compare action.
- **Owner side:** registration gained a location pin, a price range, prices per service and an Hours step. The dashboard's "Edit business profile" and "Operating hours" rows, previously inert, now open edit screens, so existing businesses can add prices, hours and a pin.
- **Location** (`core/location/location_service.dart`): checks silently at startup and prompts only when the user asks. Requests are capped at 15 seconds (60 for a permission prompt), because the web plugin passes its own timeout in the wrong unit and a stalled request would otherwise never end.

### 3.3 Changes from the original plan

1. **Default order.** It is always "Best match". Without keywords the ties already put new businesses first, then nearer, then better rated. The plan had proposed "newest" in that case.
2. **Typeahead** offers word-prefix matches only, so "ra" suggests "Ramen", not "Tiramisu".
3. **Owner edit screens** were added. Without them, businesses registered before this module could never gain prices, hours or a pin.
4. **`track=false`** on the detail endpoint keeps the owner's edit screens from inflating profile views.
5. **Location timeouts** were added after the browser test showed a stalled request leaving the UI on "locating".

---

## 4. Testing

| Suite | Result |
|---|---|
| Backend `pytest` (SQLite in memory) | 82 passed, including the original 13 |
| Flutter `flutter test` | 21 passed |
| `flutter analyze` | No issues |
| Migration on a throwaway local Postgres 16 | Upgrade, downgrade and re-upgrade work; `alembic check` finds no drift between models and migrations |
| Web build in Chrome at phone size, against the seeded local database | Customer: login, idle view, typeahead, results with distances, selection, compare, filter sheet with Open now, Home category chip, business page Compare action. Owner: save hours, edit profile, registration with pin, price range, priced service and hours, publish, then find the new business in search. No console errors. |

The backend tests cover keyword matching (fields, accents, stopwords, all-words and any-word fallback), relevance order, every filter alone and combined, open-now including after-midnight hours, radius and distance sort, validation messages, paging, card fields, the summary, history privacy and clearing, popular searches, suggestions, comparison rows and ties, invalid comparison requests, the new registration validation, hours replacement permissions, and a 500-business response-time check.

---

## 5. Rollout notes

- **Shared Supabase database.** The team's `DATABASE_URL` points at a shared Supabase instance. Run `alembic upgrade head` there once the team is ready; it only adds columns, a table and indexes. Teammates on `main` should pull this branch before generating any new migration, or Alembic will see the revision history diverge.
- **The seed is safe by default.** `python -m app.db.seed` adds missing demo accounts, categories and businesses, and refreshes the demo owner's catalogue businesses (address, pin, price range, hours, services) to the Module 4 catalogue. Views, saves and ratings are kept, and it never deletes a user or anyone else's business. `--reset` restores the old behaviour of wiping every user and business first; use that only on a local or disposable database. Before seeding, the script checks that the database is on the latest migration.
- **Startup schema check.** Code that expects the Module 4 columns fails on every business request against a database still on the Module 3 schema, and the app can only show "Couldn't load your feed". The API now logs a warning at startup naming the missing revision and the command to run (`SCHEMA_CHECK_ON_STARTUP`, on by default).
- **New backend dependency:** `tzdata` (in `requirements.txt`); Windows has no timezone database of its own.
- **New Flutter dependency:** `geolocator`. Run `flutter pub get`. Android and iOS location permission entries were added.
- **Environment:** `BUSINESS_TIMEZONE`, `NEW_BUSINESS_DAYS` and `SEARCH_MAX_RADIUS_KM` are in `.env.example`, with safe defaults.

---

## 6. Out of scope, handed to other modules

- **Module 6 (Maps):** map toggle on results, "View on map" in compare, and a map pin picker.
- **Modules 7 and 10 (Kai, personalization):** an AI-written summary and AI suggestions. Module 4 fills those slots with rule-based versions and stores the search history Module 10 needs.
- **Module 5 (Reviews):** accurate ratings. Search reads the denormalized `rating` column, which Module 5 must keep updated.
- **Module 8 (Admin):** the verification workflow that makes the "only verified" rule enforceable (D1).
- **Later scaling (SCA-3):** Postgres full-text search or `pg_trgm` with GIN indexes. The strategy interface allows swapping `KeywordSearch` without touching the API.

---

## 7. Note on the SDD Strategy pattern

The class diagram's `SearchEngine` holds one strategy at a time. A real request combines keyword, category and location, so the engine runs several strategies per request. The class and method names (`SearchEngine`, `SearchStrategy`, `KeywordSearch`, `CategorySearch`, `LocationSearch`, `setSearchStrategy`, `search`) match the SDD, so the traceability holds.

---

## 8. Issues found in the updated documents

1. **Comparison still has no functional requirement.** The updated SRS adds UC-5 "Filter and Compare Businesses", but section 4 still lists no comparison FR, while SDD traceability has FR08 Compare. Consider adding "FR-16 Compare Businesses" under section 4.2.
2. **Conflicting feed rules (Module 3).** SRS UC-3 says "Verified prioritized", but FR-11 BR-6 says "New businesses prioritized".
3. **Numbering differs.** SDD traceability uses FR01–FR20 with different meanings from the SRS's FR-1 to FR-15. For example, SRS FR-3 is "Search" and SDD FR03 is "Business Registration".
4. **Broken tables of contents.** The SRS contents show "Error! Bookmark not defined." for UC-1 to UC-12, and the feasibility report does the same for Modules 1–7. Updating the fields in Word before exporting fixes it.
5. **Feasibility report contents out of order.** The contents list Module 5 as Maps and Module 6 as Reviews, while the body has Module 5 Reviews and Module 6 Maps. Modules 8–10 are missing from the contents.
6. **Project name typo.** The cover pages of all three documents say "KOJLO" instead of "Khojlo".
7. **Compare layout conflict:** a table in the SDD and design bundle versus cards in `modules_layout.md`. Resolved by D4.
8. **Bottom navigation differs.** `modules_layout.md` lists Home, Search, AI, Chat, Profile; the app follows the design bundle with Home, Explore, Map, Chat, Business. No change planned.
