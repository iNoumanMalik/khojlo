"""Module 6 — address lookup for maps (SRS FR-12, UC-9; SDD `MapService`).

Used by the map pin picker (fill the address from the pin, jump to a typed address) and
the Home location indicator ("Near F-7 Markaz, Islamabad"). Signed-in users only, and
lightly rate-limited: the free OpenStreetMap services ask for light use, and Google bills
every uncached call.
"""
import logging
import threading
import time
from collections import defaultdict, deque

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.core.config import settings
from app.models.user import User
from app.services.geocoding import Geocoder, GeocodingError, Place, configured_geocoder

router = APIRouter(prefix="/geo", tags=["maps"])
log = logging.getLogger("uvicorn.error")

NOT_CONFIGURED = 503
PROVIDER_FAILED = 502
TOO_MANY = 429
# Per user: generous for dragging a pin around, low enough to stop a runaway client.
RATE_LIMIT = 60
RATE_WINDOW_SECONDS = 600


class PlaceOut(BaseModel):
    address: str
    area: str | None = None
    city: str | None = None
    label: str
    latitude: float
    longitude: float

    @classmethod
    def of(cls, p: Place) -> "PlaceOut":
        return cls(address=p.address, area=p.area, city=p.city, label=p.label,
                   latitude=p.latitude, longitude=p.longitude)


def get_geocoder() -> Geocoder | None:
    """Overridable in tests; None when Google is chosen without a key."""
    return configured_geocoder(settings)


class _RateLimiter:
    def __init__(self, limit: int, window: float):
        self.limit, self.window = limit, window
        self._hits: dict[int, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, user_id: int) -> bool:
        now = time.monotonic()
        with self._lock:
            hits = self._hits[user_id]
            while hits and hits[0] <= now - self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                return False
            hits.append(now)
            return True


limiter = _RateLimiter(RATE_LIMIT, RATE_WINDOW_SECONDS)


def _ready(user: User, geocoder: Geocoder | None) -> Geocoder:
    if geocoder is None:
        raise HTTPException(status_code=NOT_CONFIGURED,
                            detail="Address lookup isn't set up on this server.")
    if not limiter.allow(user.id):
        raise HTTPException(status_code=TOO_MANY,
                            detail="Too many address lookups. Please wait a few minutes.")
    return geocoder


def _failed(exc: GeocodingError) -> HTTPException:
    log.warning("Geocoding failed: %s", exc)
    return HTTPException(status_code=PROVIDER_FAILED,
                         detail="Couldn't look up the address right now. Please try again.")


@router.get("/reverse", response_model=PlaceOut, summary="Address at a map point")
def reverse_geocode(
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    user: User = Depends(get_current_user),
    geocoder: Geocoder | None = Depends(get_geocoder),
) -> PlaceOut:
    g = _ready(user, geocoder)
    try:
        place = g.reverse(lat, lng)
    except GeocodingError as exc:
        raise _failed(exc) from None
    if place is None:
        raise HTTPException(status_code=404, detail="No address found at this spot.")
    return PlaceOut.of(place)


@router.get("/search", response_model=list[PlaceOut], summary="Find a typed address")
def search_places(
    q: str = Query(min_length=2, max_length=120),
    lat: float | None = Query(default=None, ge=-90, le=90, description="Rank places near here"),
    lng: float | None = Query(default=None, ge=-180, le=180),
    user: User = Depends(get_current_user),
    geocoder: Geocoder | None = Depends(get_geocoder),
) -> list[PlaceOut]:
    g = _ready(user, geocoder)
    near = (lat, lng) if lat is not None and lng is not None else None
    try:
        return [PlaceOut.of(p) for p in g.search(q.strip(), near)]
    except GeocodingError as exc:
        raise _failed(exc) from None
