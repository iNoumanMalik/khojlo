"""Address lookup (geocoding) — the server side of the SDD's `MapService` abstraction.

`Geocoder` is the interface; `GoogleGeocoder` calls Google's Geocoding API. Calls go
through the backend so the key never ships inside the app, and results are cached briefly
because the same spots (a business being pinned, a user's area) are looked up repeatedly.
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

    @property
    def label(self) -> str:
        """Short name for a place: "F-7 Markaz, Islamabad"."""
        parts = [p for p in (self.area, self.city) if p]
        return ", ".join(dict.fromkeys(parts)) or self.address


class GeocodingError(RuntimeError):
    """The provider refused or failed (bad key, quota, network)."""


class Geocoder(ABC):
    @abstractmethod
    def reverse(self, latitude: float, longitude: float) -> Place | None:
        """The address at a point, or None if there's nothing there (e.g. open sea)."""

    @abstractmethod
    def search(self, query: str) -> list[Place]:
        """Places matching a typed address, best first."""


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

    def search(self, query: str) -> list[Place]:
        normalized = " ".join(query.lower().split())
        key = ("search", normalized)
        cached = self._cache.get(key)
        if cached is not None:
            return cached
        places = [parse_result(r) for r in self._results(address=query)[:MAX_RESULTS]]
        self._cache.put(key, places)
        return places


_geocoder: Geocoder | None = None
_geocoder_lock = threading.Lock()


def configured_geocoder(api_key: str | None, region: str, language: str) -> Geocoder | None:
    """A shared `GoogleGeocoder` (one cache per process), or None when no key is set."""
    global _geocoder
    if not api_key:
        return None
    with _geocoder_lock:
        if _geocoder is None:
            _geocoder = GoogleGeocoder(api_key, region=region, language=language)
        return _geocoder
