"""Module 4 — business comparison API (SRS UC-5; SDD FR08, Algorithm 3)."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_now
from app.core.database import get_db
from app.schemas.search import CompareResponse
from app.services.compare_service import (
    MAX_COMPARE,
    MIN_COMPARE,
    BusinessesNotFound,
    build_comparison,
)

# Plain number: Starlette renamed the 422 constant, and both names aren't available
# across the FastAPI versions requirements.txt allows.
UNPROCESSABLE = 422

router = APIRouter(prefix="/compare", tags=["compare"])


@router.get("", response_model=CompareResponse, summary="Compare 2–3 businesses")
def compare_businesses(
    ids: list[int] = Query(description="Business ids to compare, e.g. ?ids=1&ids=4"),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    db: Session = Depends(get_db),
    now: datetime = Depends(get_now),
) -> CompareResponse:
    """SDD `Customer.compareBusinesses(businessList)`.

    Returns the businesses in the order given, plus the winner of each comparison row
    (cheapest, best rated, nearest, open now, most services, offers, most saved).
    Pass lat/lng to include distances.
    """
    if not MIN_COMPARE <= len(ids) <= MAX_COMPARE:
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail=f"Pick {MIN_COMPARE} to {MAX_COMPARE} places to compare.",
        )
    if len(set(ids)) != len(ids):
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail="Each place can only be compared once.",
        )
    if (lat is None) != (lng is None):
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail="Provide both lat and lng to include distances.",
        )

    origin = (lat, lng) if lat is not None and lng is not None else None
    try:
        return build_comparison(db, ids, origin=origin, now=now)
    except BusinessesNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Business not found: {', '.join(map(str, exc.missing))}",
        ) from exc
