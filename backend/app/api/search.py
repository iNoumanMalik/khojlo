"""Search & filtering API (SRS UC-4, UC-5, FR-3, FR-4), also used by the Module 6 map (FR-12)."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_now, get_optional_user
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User
from app.schemas.search import SearchHistoryItem, SearchResponse, Suggestion
from app.services.business_service import to_card
from app.services.search import PRICE_TIERS, SearchCriteria, SearchEngine, SortOption
from app.services.search.criteria import MapBounds
from app.services.search.history import (
    clear_history,
    popular_searches,
    recent_searches,
    record_search,
)
from app.services.search.suggestions import suggest

# Plain number: Starlette renamed the 422 constant, and both names aren't available
# across the FastAPI versions requirements.txt allows.
UNPROCESSABLE = 422

router = APIRouter(prefix="/search", tags=["search"])


def _invalid(detail: str) -> HTTPException:
    return HTTPException(status_code=UNPROCESSABLE, detail=detail)


@router.get("", response_model=SearchResponse, summary="Search and filter businesses")
def search_businesses(
    q: str | None = Query(default=None, max_length=100, description="Keywords"),
    category: list[str] = Query(default=[], description="Category slug; repeat for several"),
    price: list[str] = Query(default=[], description="Price tier: $, $$ or $$$; repeatable"),
    min_price: int | None = Query(default=None, ge=0, description="Budget lower bound (PKR)"),
    max_price: int | None = Query(default=None, ge=0, description="Budget upper bound (PKR)"),
    min_rating: float | None = Query(default=None, ge=0, le=5),
    open_now: bool = Query(default=False, description="Only places open right now"),
    has_offer: bool = Query(default=False, description="Only places with an active offer"),
    verified_only: bool = Query(default=False, description="Only admin-verified places"),
    lat: float | None = Query(default=None, ge=-90, le=90, description="Searcher latitude"),
    lng: float | None = Query(default=None, ge=-180, le=180, description="Searcher longitude"),
    radius_km: float | None = Query(
        default=None, ge=0.5, le=settings.SEARCH_MAX_RADIUS_KM, description="Needs lat/lng"
    ),
    north: float | None = Query(default=None, ge=-90, le=90, description="Map area: north edge"),
    south: float | None = Query(default=None, ge=-90, le=90, description="Map area: south edge"),
    east: float | None = Query(default=None, ge=-180, le=180, description="Map area: east edge"),
    west: float | None = Query(default=None, ge=-180, le=180, description="Map area: west edge"),
    sort: SortOption = Query(default=SortOption.relevance),
    limit: int = Query(default=20, ge=1, le=100, description="Up to 100, for map pins"),
    offset: int = Query(default=0, ge=0),
    record: bool = Query(
        default=False, description="Save to search history (send on submit, not per keystroke)"
    ),
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
    now: datetime = Depends(get_now),
) -> SearchResponse:
    """SDD `Customer.searchBusinesses(query, filters)`.

    Keywords match name, tagline, description, address, category and services, ignoring
    case and accents. Every filter combines with the others (UC-5). No match is a
    normal empty result (UC-4 exception). The default order is relevance (UC-4); ties go
    to new businesses, then nearer, then better-rated ones.
    """
    if (lat is None) != (lng is None):
        raise _invalid("Provide both lat and lng to search by location.")
    if radius_km is not None and lat is None:
        raise _invalid("A distance filter needs your location (lat and lng).")
    if sort is SortOption.distance and lat is None:
        raise _invalid("Sorting by distance needs your location (lat and lng).")
    if min_price is not None and max_price is not None and min_price > max_price:
        raise _invalid("The minimum price can't be higher than the maximum price.")
    bad_tiers = [p for p in price if p not in PRICE_TIERS]
    if bad_tiers:
        raise _invalid(f"Unknown price tier {bad_tiers[0]!r}. Use $, $$ or $$$.")
    edges = (north, south, east, west)
    bounds = None
    if any(e is not None for e in edges):
        if any(e is None for e in edges):
            raise _invalid("A map area needs all four edges: north, south, east and west.")
        if south >= north:
            raise _invalid("The map area's south edge must be below its north edge.")
        if west >= east:
            raise _invalid("Map areas that cross the 180° meridian aren't supported.")
        bounds = MapBounds(south=south, west=west, north=north, east=east)

    criteria = SearchCriteria(
        query=(q or "").strip(),
        categories=category,
        price_levels=list(dict.fromkeys(price)),
        min_price=min_price,
        max_price=max_price,
        min_rating=min_rating,
        open_now=open_now,
        has_offer=has_offer,
        verified_only=verified_only,
        lat=lat,
        lng=lng,
        radius_km=radius_km,
        bounds=bounds,
        sort=sort,
        limit=limit,
        offset=offset,
    )
    outcome = SearchEngine(db, now=now).search(criteria)

    if record:
        record_search(
            db, user_id=user.id if user else None, criteria=criteria, result_count=outcome.total
        )

    origin = criteria.origin
    return SearchResponse(
        items=[to_card(b, origin=origin, now=now) for b in outcome.items],
        total=outcome.total,
        limit=limit,
        offset=offset,
        sort=sort.value,
        summary=outcome.summary,
        relaxed=outcome.relaxed,
    )


@router.get("/suggestions", response_model=list[Suggestion], summary="Typeahead suggestions")
def search_suggestions(
    q: str = Query(min_length=1, max_length=100),
    limit: int = Query(default=8, ge=1, le=20),
    db: Session = Depends(get_db),
) -> list[Suggestion]:
    """Categories, businesses and services matching what's typed; prefix matches first."""
    return suggest(db, q, limit)


@router.get("/popular", response_model=list[str], summary="Popular searches")
def popular(
    limit: int = Query(default=8, ge=1, le=20),
    db: Session = Depends(get_db),
    now: datetime = Depends(get_now),
) -> list[str]:
    """The most frequent searches of the last 30 days, topped up with category names."""
    return popular_searches(db, limit=limit, now=now)


@router.get("/history", response_model=list[SearchHistoryItem], summary="My recent searches")
def my_history(
    limit: int = Query(default=10, ge=1, le=30),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[SearchHistoryItem]:
    return recent_searches(db, user.id, limit)


@router.delete(
    "/history", status_code=status.HTTP_204_NO_CONTENT, summary="Clear my search history"
)
def delete_history(
    user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Response:
    clear_history(db, user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
