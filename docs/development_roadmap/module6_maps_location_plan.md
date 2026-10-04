# Module 6: Maps and Location Integration — Plan

Status: **implemented** (September 2026). The plan below is kept as written; what was actually built, and how to set up the Google keys, are in [Implementation record](#implementation-record) and [Setup steps](#setup-steps) at the end.

## Sources

- `docs/requirements/SRS.pdf`: OE-8, CO-5, UC-9 (View Maps), FR-12 (Map Integration, BR-7)
- `docs/requirements/SDD.pdf`:
  - §4.1 class diagram (`MapService` interface, `GoogleMapsService`)
  - §5.1 data storage (Google Maps stores no application data)
  - Algorithm 12 `GoogleMapsService.displayLocation()`
  - §8 screens: Home "Location Indicator"; Business Profile "location on Google Maps" and "Directions Button: opens Google Maps navigation"
- `docs/requirements/Feasibility_Report.pdf`: Module 6 description; Concept-2 "Geolocation and Map Integration"; Google Maps API and SDK in the tools list
- `docs/design/modules_layout.md` (Module 6 "Maps"; Module 4 "Map Toggle"; business page "Map" section) and `ui_design_direction.md` ("Maps Experience")
- Existing code:
  - Module 4: device location, distances, radius filter, "Use my current location" pin in registration
  - the prototype `features/prototype/map_screen.dart`
  - `google_maps_flutter` 2.17 is already a dependency but not configured

## What the documents ask for

| Source | Requirement |
|---|---|
| FR-12 | Display business locations on maps. **BR-7:** valid GPS coordinates are required |
| UC-9 | Customer opens the map; Google Maps loads; the location is displayed. Alternative flow: **get directions**. Exception: **location unavailable** |
| OE-8, CO-5 | Use the Google Maps SDK and APIs for location tracking, navigation and map visualization |
| SDD class diagram | A `MapService` interface abstracts the provider; `GoogleMapsService.displayLocation()` implements it |
| SDD Screen 1 | Home shows a **location indicator**: the user's current location, used for nearby recommendations |
| SDD Screen 3 | The business profile shows its **location on Google Maps**; the **Directions** button opens Google Maps navigation |
| Feasibility, Concept-2 | Display business locations, support **location-based filtering** and navigation, embed **interactive maps** |
| Design, Module 6 | Not a full-screen map. Layout: search → map → floating business cards → nearby carousel → filter button. Cards update as the map is dragged. Business previews appear above pins, with smooth switching between list and map |

## Proposed implementation

### Backend

1. **Map-area search.** An `AreaSearch` strategy (the SDD's Strategy pattern) limits `/search` to the visible map area (`north`, `south`, `east`, `west`).
   - It combines with every Module 4 filter, keywords and sort orders.
   - Only businesses with coordinates are returned, with a cap on pins per request.
2. **BR-7.** Coordinates must be valid: in range, both or neither (already enforced), and not the (0, 0) placeholder that broken GPS readings produce.
3. **Geocoding (optional, see question 1).**
   - `GET /geo/reverse?lat&lng` returns an address and a short area name, e.g. "F-7 Markaz, Islamabad".
   - `GET /geo/search?q` returns places for a typed address.
   - Both go through the backend with a server-only key and cache the results, so the key never ships in the app.

### Flutter

1. **`MapService` interface + `GoogleMapsService`**, as in the SDD. It covers displaying a location, opening directions, and a clean fallback when no API key is configured, so the app never crashes without one.
2. **Map tab** (replaces the prototype):
   - a Google map styled in Khojlo's colours
   - the user's live location dot and a "locate me" button
   - custom pins (gold, with the selected one in emerald)
   - a glass search bar, and a filter button that reuses the Module 4 filter sheet
   - a floating preview card above the tapped pin
   - a nearby carousel kept in sync with the pins
   - results that refresh when the map stops moving

   The map is **not full-screen**: the overlays follow the design, and the map sits inside the app's layout.
3. **Explore list ↔ map toggle.** The Map tab and Explore share the same search and filters, so switching between list and map keeps your query.
4. **Business page:**
   - The "Where" section becomes a small live map with the business pin; tapping it opens the Map tab centred on the business.
   - **Directions** opens Google Maps navigation (the app on phones, the website on web).
   - A business without a location shows "Location unavailable" (the UC-9 exception).
5. **Registration and Edit business:** a map pin picker (drag the map under a fixed pin) next to "Use my current location". With geocoding, the address fills in from the pin.
6. **Home location indicator** (SDD Screen 1): "📍 Near F-7 Markaz, Islamabad". This needs geocoding; without it, a plain "Using your location" label is shown instead.

### API keys stay out of git

The repository is on GitHub, so keys are never committed. See [Setup steps](#setup-steps) for where each key goes.

## Documentation issues found

1. **Module numbering.** The Feasibility Report's table of contents lists Maps as Module 5, but its body text and the team work division list it as Module 6. We now use **Module 6**, as in the body text, and `implementation_plan.md` is updated to match.
2. **SDD traceability matrix.** It numbers requirements differently from the SRS: SDD "FR10 View Business Location" is SRS **FR-12**, and FR09, FR11 and FR12 likewise map to SRS FR-5, FR-6 and FR-7.
3. **Design vs. SRS.** The design notes say "do not display a full-screen Google Maps style interface", while the SRS requires Google Maps. We use Google Maps as the base layer inside the design's layout (styled colours, glass overlays, floating cards), which satisfies both.
4. **"Location tracking" (OE-8).** We interpret this as showing the user's live location while the map is open. There is no background tracking, for privacy and battery reasons.

## Implementation record

### Backend

| Piece | Where | Notes |
|---|---|---|
| Map-area search | `app/services/search/strategies.py` (`AreaSearch`), `criteria.py` (`MapBounds`), `app/api/search.py` | `GET /search` takes `north`, `south`, `east`, `west`. All four are required together, and south must be below north. Areas crossing the 180° meridian are rejected. The strategy combines with every Module 4 filter and sort order, and excludes businesses without coordinates. `limit` goes up to 100 for map pins. |
| Pin coordinates on cards | `app/schemas/business.py`, `app/services/business_service.py` | `latitude` and `longitude` moved from the detail schema up to `BusinessCard`, so search results can be drawn as pins. The change is additive. |
| BR-7 | `app/schemas/business.py`, `app/api/businesses.py` | (0, 0) is rejected on create and update, alongside the existing range and both-or-neither checks. |
| Geocoding | `app/services/geocoding.py` (`Geocoder`, `GoogleGeocoder`), `app/api/geo.py` | `GET /geo/reverse?lat&lng` and `GET /geo/search?q`. Signed-in users only, and rate-limited to 60 lookups per 10 minutes per user. Results are cached for 24 hours, with reverse lookups on an ~11 m grid. The provider is OpenStreetMap by default (see below); with `GEOCODING_PROVIDER=google` and no `GOOGLE_MAPS_SERVER_KEY` the endpoints return 503, and the app hides lookup features. Provider errors are logged but never shown to users. |
| Tests | `tests/test_maps.py` | Map area, filters, validation, BR-7, the geocoding API with a fake provider, and the Google client with a fake HTTP session. |

### Flutter

| Piece | Where | Notes |
|---|---|---|
| `MapService` (SDD §4.1) | `lib/core/maps/map_service.dart` | `GoogleMapsService` draws Google maps. `SketchMapService` is a drawn stand-in used when no key is configured and in tests. Both provide `buildMap`, `displayLocation` (SDD Algorithm 12) and `openDirections` (UC-9 alternative flow, a Google Maps navigation link). |
| Google map | `google_map_view.dart`, `map_style.dart`, `pin_icons.dart`, `maps_loader_web.dart` | Khojlo colours, with other points of interest hidden. Custom pins: gold, emerald when selected, plum while pinning, and a blue "you" dot. On web the Maps JavaScript API is loaded with the key at runtime; if it fails to load or Google rejects the key, the sketch map is shown instead. |
| Map tab | `lib/features/maps/presentation/map_screen.dart`, `map_providers.dart` | Layout: search, then the map card, a floating preview for the tapped pin (with Directions), a nearby carousel synced with the pins, and a filter button. Results reload when the map stops moving, using the same keyword and filters as Explore. A chip shows "Showing 100 of N · zoom in" when results are capped. A locate-me button covers the "location unavailable" exception (UC-9). |
| List ↔ map | `view_toggle.dart` | A List \| Map switch on both Explore and Map. Both views share one search. |
| Business page | `business_detail_screen.dart` | A small live map in "Where". Tapping it (or "Map") opens the Map tab centred on the business. Directions works, and a business without a pin shows "Location unavailable". |
| Pin picker | `location_picker_screen.dart`, `LocationPinField` | The owner drags the map under a fixed pin, can search a typed address, or use their location. The address at the pin fills an empty Address field, or is offered with "Use it". Used in registration and Edit business. |
| Location indicator (SDD Screen 1) | `home_screen.dart`, `geo_repository.dart` | "Near F-7 Markaz, Islamabad" in the Home header. The Home feed now sends the location, so the backend adds its **Nearby** row. |
| Tests | `test/maps_test.dart` | Geometry and BR-7, map-area results, the Map tab, the business page and the pin picker. All run on the sketch map. |

### Decisions made while building

* **iOS** has no Google Maps key wiring yet, so it shows the sketch map. Adding it needs a Maps SDK for iOS key and a line in `AppDelegate.swift`.
* **No "Search this area" button.** Results refresh on their own when the map stops moving, as the design asks ("cards update as the map is dragged").
* **A search with nothing in view looks further.** A new keyword or filter first searches the visible area, so the map stays put when something nearby matches. If nothing in view matches, it searches everywhere (nearest to the view first), moves the map to the closest matches and says "No matches in that area · showing the nearest". Panning and zooming still search only the visible area.
* **Keys** live in the existing gitignored `frontend/dart_defines.json`, not in `local.properties`, so web and Android read the same file.

## Map provider: MapLibre + OpenStreetMap (October 2026)

Google Maps couldn't be set up for this iteration (it needs a billing account), so the default map is now open source. The SRS/SDD name Google Maps; `MapService` was built so the provider could change without touching screens, and Google stays available for a later iteration.

| Piece | Where | Notes |
|---|---|---|
| Provider choice | `maps_config.dart`, `mapServiceProvider` in `map_service.dart` | `MAP_PROVIDER` in `dart_defines.json`: `maplibre` (default) or `google`. MapLibre runs on Android, iOS and web; desktop gets the sketch map. |
| MapLibre map | `maplibre_map_view.dart` (`MapLibreService`) | `maplibre_gl` renders vector tiles, so zooming is smooth and the style is ours. Pins are a GeoJSON source drawn by one symbol layer, using the same painter as before (`pin_icons.dart`). Rotation and tilt are off, because map-area search uses north-up bounds. If the style hasn't loaded after 20 s (offline, no WebGL), the sketch map is shown instead. |
| Style | `assets/maps/khojlo_style.json`, built by `tool/build_map_style.py` | OpenFreeMap's "Positron" style (no points of interest, so Khojlo's pins stand out) recoloured with the old Google style's palette. Labels are Latin-only, and transit and road shields are hidden. Re-run the script after changing a colour. |
| Tiles | OpenFreeMap (`tiles.openfreemap.org`) | Free, no key and no registration. Attribution ("OpenFreeMap © OpenMapTiles Data from OpenStreetMap") is shown by MapLibre and must stay visible. Before a public launch, consider self-hosting a Pakistan extract (Protomaps/PMTiles) so we don't depend on a donation-funded service. |
| Directions | `MapService.openDirections` | Unchanged: a Google Maps navigation link, which needs no API key. |

| Address lookup | `OsmGeocoder` in `app/services/geocoding.py` | Default provider (`GEOCODING_PROVIDER=osm`), no key. **Photon** answers typed searches: results are limited to Pakistan (`GEOCODING_REGION`) and ranked near the map centre the app sends as `lat`/`lng`. **Nominatim** names the spot under a pin and the Home location ("F-7/2, Islamabad"); its usage policy allows one request per second per server, so calls are paced and cached on an ~11 m grid. Both send `GEOCODING_USER_AGENT`, and `PHOTON_URL`/`NOMINATIM_URL` can point at self-hosted instances. `GoogleGeocoder` remains for `GEOCODING_PROVIDER=google`. |

## Route preview (October 2026)

Directions (business page, the Map tab's preview card, and chat) now opens a route screen instead of going straight to Google Maps.

| Piece | Where | Notes |
|---|---|---|
| Routing | `app/services/routing.py` (`Router`, `OrsRouter`), `GET /geo/route` in `app/api/geo.py` | openrouteservice (`driving-car`, `foot-walking`), behind the server so the key stays private. Signed-in users, 30 routes per 10 minutes each; routes cached for 6 hours with the start on a ~110 m grid. 503 without `OPENROUTESERVICE_API_KEY`, 404 when no road connects the points, 502 on provider errors (details only in the log). |
| Route screen | `lib/features/maps/presentation/route_screen.dart` | Our map with the route as an emerald line, the user's dot and the business pin, a Car / Walk switch, "~11 min · 4.3 km", and **Start in Google Maps** (same travel mode) for turn-by-turn navigation. Without a key or a location it still opens: it shows the straight-line distance, or asks for the location. |
| Route line | `MapService.buildMap(route: …)` | Drawn by all three maps: a MapLibre line layer under the pins, a Google polyline, and a painted line on the sketch map. |

Times have no live traffic (free routing), so they're shown as approximate ("~11 min").

### Getting the openrouteservice key

1. Sign up at <https://account.heigit.org> and confirm your email.
2. In the dashboard, request a token on the free **Standard** plan (2,000 directions requests a day, 40 a minute).
3. Copy the key into `backend/.env` as `OPENROUTESERVICE_API_KEY=…`, then restart the backend. Don't commit it or paste it in chat.

## Setup steps

These steps are only needed for `MAP_PROVIDER=google` and `GEOCODING_PROVIDER=google`; the default MapLibre map and OpenStreetMap address lookup need no setup.

1. In Google Cloud (the project already used for Google Sign-In), attach a **billing account**. Maps Platform requires one even within the free monthly usage.
2. Enable **Maps JavaScript API** (web), **Maps SDK for Android**, and **Geocoding API** (backend).
3. Create three restricted API keys:
   * **Web:** application restriction *HTTP referrers*, `http://localhost:*` plus your deployed domain; API restriction *Maps JavaScript API*.
   * **Android:** application restriction *Android apps*, package `com.khojlo.khojlo` with your debug SHA-1 (`cd frontend/android && ./gradlew signingReport`); API restriction *Maps SDK for Android*.
   * **Server:** API restriction *Geocoding API* only. No application restriction is needed, because it's only used by the backend.
4. Put the keys in local, gitignored files. Don't paste them in chat or commit them.
   * `frontend/dart_defines.json` (copy `dart_defines.example.json`): `MAPS_API_KEY_WEB` and `MAPS_API_KEY_ANDROID`.
   * `backend/.env`: `GOOGLE_MAPS_SERVER_KEY`.
5. Run the app with `flutter run --dart-define-from-file=dart_defines.json`. The Android build reads its key from the same file.

Without keys everything still works: the app shows the MapLibre map and looks up addresses with OpenStreetMap. Only the Google modes fall back (sketch map, lookup hidden).
