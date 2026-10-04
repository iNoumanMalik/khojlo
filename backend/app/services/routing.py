"""Routes for the in-app route preview (UC-9 alternative flow "get directions").

`Router` is the interface; `OrsRouter` calls openrouteservice (OpenStreetMap data, free
plan with a key). Calls go through the backend so the key never ships inside the app, and
routes are cached because people reopen the same route (a user checking a business twice).
The app still hands off to Google Maps for turn-by-turn navigation.
"""
from __future__ import annotations

import threading
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum

import requests

from app.services.geocoding import _TtlCache

ORS_TIMEOUT_SECONDS = 10
CACHE_SECONDS = 6 * 3600
CACHE_SIZE = 1000
# openrouteservice: "could not find a routable point" / "route not found".
_NO_ROUTE_CODES = {2009, 2010}


class TravelMode(str, Enum):
    car = "car"
    walk = "walk"


_ORS_PROFILE = {TravelMode.car: "driving-car", TravelMode.walk: "foot-walking"}


@dataclass(frozen=True)
class Route:
    distance_m: float
    duration_s: float
    # (latitude, longitude) along the route, start to end.
    points: list[tuple[float, float]]


class RoutingError(RuntimeError):
    """The provider refused or failed (bad key, quota, network)."""


class Router(ABC):
    @abstractmethod
    def route(self, origin: tuple[float, float], destination: tuple[float, float],
              mode: TravelMode) -> Route | None:
        """The route between two (lat, lng) points, or None when there's no road between them."""


def parse_ors_route(data: dict) -> Route | None:
    """Turn an openrouteservice GeoJSON answer into a `Route`."""
    try:
        feature = data["features"][0]
        summary = feature["properties"]["summary"]
        coordinates = feature["geometry"]["coordinates"]
    except (KeyError, IndexError, TypeError):
        return None
    points = [(float(lat), float(lng)) for lng, lat, *_ in coordinates]
    if len(points) < 2:
        return None
    # A start and end on the same spot has no distance or duration in the summary.
    return Route(distance_m=float(summary.get("distance", 0)),
                 duration_s=float(summary.get("duration", 0)), points=points)


class OrsRouter(Router):
    def __init__(self, api_key: str, *, base_url: str = "https://api.openrouteservice.org",
                 session: requests.Session | None = None):
        self._key = api_key
        self._base = base_url.rstrip("/")
        self._http = session or requests.Session()
        self._cache = _TtlCache(CACHE_SECONDS, CACHE_SIZE)

    def route(self, origin, destination, mode):
        # ~110 m grid for the start (the user moves a little between checks); the
        # destination is a pinned business, so it's kept exact.
        key = (mode, round(origin[0], 3), round(origin[1], 3), destination)
        cached = self._cache.get(key)
        if cached is not None:
            return cached or None
        body = {"coordinates": [[origin[1], origin[0]], [destination[1], destination[0]]]}
        try:
            response = self._http.post(
                f"{self._base}/v2/directions/{_ORS_PROFILE[mode]}/geojson", json=body,
                headers={"Authorization": self._key}, timeout=ORS_TIMEOUT_SECONDS)
            data = response.json()
        except (requests.RequestException, ValueError) as exc:
            raise RoutingError(f"network: {exc.__class__.__name__}") from None
        if response.status_code != 200:
            error = data.get("error") if isinstance(data, dict) else None
            code = error.get("code") if isinstance(error, dict) else None
            if code in _NO_ROUTE_CODES:
                self._cache.put(key, False)
                return None
            # 401/403 (key), 429 (quota), 2004 (too far for the profile), 5xx…
            message = error.get("message") if isinstance(error, dict) else error
            raise RoutingError(f"HTTP {response.status_code}: {code or ''} {message or ''}".strip())
        route = parse_ors_route(data)
        self._cache.put(key, route or False)
        return route


_router: Router | None = None
_router_lock = threading.Lock()


def configured_router(settings) -> Router | None:
    """The shared router (one cache per process), or None when no key is set."""
    global _router
    if not settings.OPENROUTESERVICE_API_KEY:
        return None
    with _router_lock:
        if _router is None:
            _router = OrsRouter(settings.OPENROUTESERVICE_API_KEY,
                                base_url=settings.OPENROUTESERVICE_URL)
        return _router
