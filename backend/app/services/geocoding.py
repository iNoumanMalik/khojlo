"""Address lookup (geocoding) — the server side of the SDD's `MapService` abstraction.

`Geocoder` is the interface, with two providers:
- `OsmGeocoder` (default, free): Photon for typed searches and Nominatim for the address at
  a point, both built on OpenStreetMap data.
- `GoogleGeocoder`: Google's Geocoding API, when `GEOCODING_PROVIDER=google` and a key is set.

Calls go through the backend so keys and provider usage policies are handled in one place,
and results are cached because the same spots (a business being pinned, a user's area) are
looked up repeatedly.
"""
from __future__ import annotations

import logging
import re
import threading
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass

import requests

log = logging.getLogger("uvicorn.error")

GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
TIMEOUT_SECONDS = 6
MAX_RESULTS = 5
CACHE_SECONDS = 24 * 3600
CACHE_SIZE = 2000

# "8J7R+XC, F-7 Markaz, …": Google prefixes some addresses with a plus code.
_PLUS_CODE = re.compile(r"^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b,?\s*", re.I)
# Most specific first: the name people use for the neighbourhood.
_AREA_TYPES = ("neighborhood", "sublocality_level_2", "sublocality_level_1", "sublocality",
               "route")
_CITY_TYPES = ("locality", "administrative_area_level_3", "administrative_area_level_2")


@dataclass(frozen=True)
class Place:
    address: str
    area: str | None
    city: str | None
    latitude: float
    longitude: float
    # A search hit's own name ("F-7 Markaz Park"); None for plain addresses.
    name: str | None = None

    @property
    def label(self) -> str:
        """Short name for a place: "F-7 Markaz, Islamabad"."""
        return _join(self.name, self.area, self.city) or self.address


class GeocodingError(RuntimeError):
    """The provider refused or failed (bad key, quota, network)."""


class Geocoder(ABC):
    @abstractmethod
    def reverse(self, latitude: float, longitude: float) -> Place | None:
        """The address at a point, or None if there's nothing there (e.g. open sea)."""

    @abstractmethod
    def search(self, query: str, near: tuple[float, float] | None = None) -> list[Place]:
        """Places matching a typed address, best first; `near` (lat, lng) ranks closer
        places higher where the provider supports it."""


def _join(*parts: str | None) -> str:
    """Comma-joined, skipping blanks and repeats ("F-7, F-7, Islamabad" → "F-7, Islamabad")."""
    seen: dict[str, str] = {}
    for part in parts:
        if part and part.strip():
            seen.setdefault(part.strip().lower(), part.strip())
    return ", ".join(seen.values())


def _component(result: dict, types: tuple[str, ...]) -> str | None:
    by_type: dict[str, str] = {}
    for comp in result.get("address_components", []):
        for t in comp.get("types", []):
            by_type.setdefault(t, comp.get("long_name"))
    return next((by_type[t] for t in types if by_type.get(t)), None)


def parse_result(result: dict) -> Place:
    """Turn one Geocoding API result into a `Place`, tidying the address for local use."""
    country = _component(result, ("country",))
    address = _PLUS_CODE.sub("", result.get("formatted_address", "")).strip()
    if country and address.endswith(f", {country}"):
        address = address[: -len(country) - 2]
    location = result["geometry"]["location"]
    return Place(
        address=address,
        area=_component(result, _AREA_TYPES),
        city=_component(result, _CITY_TYPES),
        latitude=float(location["lat"]),
        longitude=float(location["lng"]),
    )


class _TtlCache:
    def __init__(self, seconds: int, size: int):
        self.seconds, self.size = seconds, size
        self._data: dict[tuple, tuple[float, object]] = {}
        self._lock = threading.Lock()

    def get(self, key: tuple):
        with self._lock:
            hit = self._data.get(key)
            if hit is None or hit[0] < time.monotonic():
                self._data.pop(key, None)
                return None
            return hit[1]

    def put(self, key: tuple, value) -> None:
        with self._lock:
            if len(self._data) >= self.size:
                self._data.pop(next(iter(self._data)))  # oldest insertion
            self._data[key] = (time.monotonic() + self.seconds, value)


class GoogleGeocoder(Geocoder):
    def __init__(self, api_key: str, *, region: str = "pk", language: str = "en",
                 session: requests.Session | None = None):
        self._key = api_key
        self._region = region
        self._language = language
        self._http = session or requests.Session()
        self._cache = _TtlCache(CACHE_SECONDS, CACHE_SIZE)

    def _results(self, **params) -> list[dict]:
        params |= {"key": self._key, "language": self._language, "region": self._region}
        try:
            data = self._http.get(GEOCODE_URL, params=params, timeout=TIMEOUT_SECONDS).json()
        except (requests.RequestException, ValueError) as exc:
            raise GeocodingError(f"network: {exc.__class__.__name__}") from None
        status = data.get("status")
        if status == "ZERO_RESULTS":
            return []
        if status != "OK":
            # REQUEST_DENIED (key/API not enabled), OVER_QUERY_LIMIT, INVALID_REQUEST…
            raise GeocodingError(f"{status}: {data.get('error_message', '')}".strip(": "))
        return data.get("results", [])

    def reverse(self, latitude: float, longitude: float) -> Place | None:
        # ~11 m grid: nearby lookups (a pin nudged slightly) share a cache entry.
        key = ("reverse", round(latitude, 4), round(longitude, 4))
        cached = self._cache.get(key)
        if cached is not None:
            return cached or None
        results = self._results(latlng=f"{latitude},{longitude}")
        place = parse_result(results[0]) if results else None
        self._cache.put(key, place or False)
        return place

    def search(self, query: str, near: tuple[float, float] | None = None) -> list[Place]:
        normalized = " ".join(query.lower().split())
        key = ("search", normalized)
        cached = self._cache.get(key)
        if cached is not None:
            return cached
        places = [parse_result(r) for r in self._results(address=query)[:MAX_RESULTS]]
        self._cache.put(key, places)
        return places


# Bounding boxes (west, south, east, north) that keep searches inside the app's country.
_REGION_BBOX = {"pk": (60.87, 23.63, 77.84, 37.10)}
# Nominatim's usage policy: at most one request per second from the whole server.
NOMINATIM_MIN_INTERVAL = 1.0


class OsmGeocoder(Geocoder):
    """OpenStreetMap lookups: Photon (search-as-you-type) and Nominatim (reverse).

    The public servers are free but ask for an identifying User-Agent, light use and
    attribution ("© OpenStreetMap contributors", shown on the map). Both URLs can point at
    self-hosted instances instead.
    """

    def __init__(self, *, user_agent: str, region: str = "pk", language: str = "en",
                 photon_url: str = "https://photon.komoot.io",
                 nominatim_url: str = "https://nominatim.openstreetmap.org",
                 session: requests.Session | None = None):
        self._region = region.lower()
        self._language = language
        self._photon = photon_url.rstrip("/")
        self._nominatim = nominatim_url.rstrip("/")
        self._http = session or requests.Session()
        self._headers = {"User-Agent": user_agent}
        self._cache = _TtlCache(CACHE_SECONDS, CACHE_SIZE)
        self._throttle = threading.Lock()
        self._last_nominatim = 0.0

    def _get(self, url: str, params: dict):
        try:
            response = self._http.get(url, params=params, headers=self._headers,
                                      timeout=TIMEOUT_SECONDS)
        except requests.RequestException as exc:
            raise GeocodingError(f"network: {exc.__class__.__name__}") from None
        status = getattr(response, "status_code", 200)
        if status != 200:
            # 403 (blocked User-Agent), 429 (too many requests), 5xx…
            raise GeocodingError(f"HTTP {status}")
        try:
            return response.json()
        except ValueError:
            raise GeocodingError("invalid JSON") from None

    def reverse(self, latitude: float, longitude: float) -> Place | None:
        # ~11 m grid: nearby lookups (a pin nudged slightly) share a cache entry.
        key = ("reverse", round(latitude, 4), round(longitude, 4))
        cached = self._cache.get(key)
        if cached is not None:
            return cached or None
        with self._throttle:
            wait = self._last_nominatim + NOMINATIM_MIN_INTERVAL - time.monotonic()
            if wait > 0:
                time.sleep(wait)
            try:
                data = self._get(f"{self._nominatim}/reverse", {
                    "format": "jsonv2", "lat": latitude, "lon": longitude, "zoom": 18,
                    "addressdetails": 1, "accept-language": self._language,
                })
            finally:
                self._last_nominatim = time.monotonic()
        place = parse_nominatim(data) if isinstance(data, dict) and "error" not in data else None
        self._cache.put(key, place or False)
        return place

    def search(self, query: str, near: tuple[float, float] | None = None) -> list[Place]:
        normalized = " ".join(query.lower().split())
        # ~10 km grid for the bias point, so nearby users share results.
        bias = (round(near[0], 1), round(near[1], 1)) if near else None
        key = ("search", normalized, bias)
        cached = self._cache.get(key)
        if cached is not None:
            return cached
        params: dict = {"q": query, "limit": MAX_RESULTS * 3, "lang": self._language}
        if bias:
            params |= {"lat": bias[0], "lon": bias[1]}
        if self._region in _REGION_BBOX:
            params["bbox"] = ",".join(str(v) for v in _REGION_BBOX[self._region])
        data = self._get(f"{self._photon}/api", params)
        places = []
        for feature in data.get("features", []) if isinstance(data, dict) else []:
            country = (feature.get("properties", {}).get("countrycode") or "").lower()
            if country and country != self._region:
                continue
            place = parse_photon(feature)
            # OSM often maps one place twice (a building and its shop): keep the first.
            if place and all(place.label != p.label for p in places):
                places.append(place)
        places = places[:MAX_RESULTS]
        self._cache.put(key, places)
        return places


def _short_state(state: str | None) -> str | None:
    """Points on Islamabad's highways only name the state: "Islamabad Capital Territory"."""
    return state.removesuffix(" Capital Territory") if state else None


def parse_nominatim(data: dict) -> Place | None:
    """Turn a Nominatim `/reverse` answer into a `Place`: "College Road, F-7/2, F-7, Islamabad"."""
    try:
        latitude, longitude = float(data["lat"]), float(data["lon"])
    except (KeyError, TypeError, ValueError):
        return None
    a = data.get("address") or {}
    road = a.get("road") or a.get("pedestrian") or a.get("footway")
    street = _join(" ".join(p for p in (a.get("house_number"), road) if p)) or None
    # The building or shop at the point, unless it's just the road itself.
    name = data.get("name") if data.get("name") and data.get("name") != road else None
    area = a.get("neighbourhood") or a.get("suburb") or a.get("quarter") or a.get("hamlet") or road
    city = (a.get("city") or a.get("town") or a.get("village") or a.get("county")
            or _short_state(a.get("state")))
    address = _join(name, street, a.get("neighbourhood"), a.get("suburb"), city)
    if not address:
        return None
    return Place(address=address, area=area, city=city, latitude=latitude, longitude=longitude)


def parse_photon(feature: dict) -> Place | None:
    """Turn one Photon search hit into a `Place`, keeping its name for the result list."""
    p = feature.get("properties") or {}
    try:
        longitude, latitude = (float(v) for v in feature["geometry"]["coordinates"][:2])
    except (KeyError, TypeError, ValueError):
        return None
    street = " ".join(v for v in (p.get("housenumber"), p.get("street")) if v) or None
    area = p.get("locality") or p.get("district")
    city = p.get("city") or p.get("county") or p.get("state")
    name = p.get("name")
    if name and name.lower() in {(area or "").lower(), (city or "").lower()}:
        name = None  # a search for "F-7" finds the sector itself: no separate name
    address = _join(name, street, p.get("locality"), p.get("district"), city)
    if not address:
        return None
    return Place(address=address, area=area, city=city, latitude=latitude,
                 longitude=longitude, name=name)


_geocoder: Geocoder | None = None
_geocoder_lock = threading.Lock()


def configured_geocoder(settings) -> Geocoder | None:
    """The shared geocoder for the configured provider (one cache per process), or None when
    Google is chosen but has no key."""
    global _geocoder
    with _geocoder_lock:
        if _geocoder is None:
            if settings.GEOCODING_PROVIDER == "google":
                if not settings.GOOGLE_MAPS_SERVER_KEY:
                    return None
                _geocoder = GoogleGeocoder(settings.GOOGLE_MAPS_SERVER_KEY,
                                           region=settings.GEOCODING_REGION,
                                           language=settings.GEOCODING_LANGUAGE)
            else:
                _geocoder = OsmGeocoder(user_agent=settings.GEOCODING_USER_AGENT,
                                        region=settings.GEOCODING_REGION,
                                        language=settings.GEOCODING_LANGUAGE,
                                        photon_url=settings.PHOTON_URL,
                                        nominatim_url=settings.NOMINATIM_URL)
        return _geocoder
