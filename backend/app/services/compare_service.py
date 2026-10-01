"""Business comparison — SDD `Customer.compareBusinesses()`, Algorithm 3.

Compares 2–3 businesses on price, rating, distance, opening status, services and offers,
and reports which business wins each row so the app can highlight it.
"""
from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.business import BusinessProfile
from app.services.promotion_service import live_offers, local_today
from app.schemas.business import ServiceOut
from app.schemas.search import CompareHighlights, CompareItem, CompareResponse
from app.services.business_service import card_load_options, to_card

MIN_COMPARE = 2
MAX_COMPARE = 3

_TIER_RANK = {"$": 1, "$$": 2, "$$$": 3}


class BusinessesNotFound(LookupError):
    def __init__(self, missing: Sequence[int]):
        super().__init__(missing)
        self.missing = list(missing)


def _winners(values: dict[int, float | None], *, lowest: bool = False) -> list[int]:
    """Ids holding the best known value. Empty when every business ties."""
    known = {k: v for k, v in values.items() if v is not None}
    if not known:
        return []
    target = min(known.values()) if lowest else max(known.values())
    winners = [k for k, v in known.items() if v == target]
    return [] if len(winners) == len(values) else winners


def compute_highlights(items: Sequence[CompareItem]) -> CompareHighlights:
    if all(i.price_min is not None for i in items):
        # Everyone published a PKR range: the cheapest starting price wins.
        price = _winners({i.id: i.price_min for i in items}, lowest=True)
    else:
        price = _winners({i.id: _TIER_RANK.get(i.price_level, 2) for i in items}, lowest=True)

    return CompareHighlights(
        price=price,
        rating=_winners({i.id: (i.rating if i.rating > 0 else None) for i in items}),
        distance=_winners({i.id: i.distance_km for i in items}, lowest=True),
        open_now=_winners(
            {i.id: (None if i.is_open_now is None else float(i.is_open_now)) for i in items}
        ),
        services=_winners({i.id: len(i.services) for i in items}),
        offers=_winners({i.id: len(i.active_offers) for i in items}),
        saves=_winners({i.id: i.save_count for i in items}),
    )


def build_comparison(
    db: Session,
    ids: Sequence[int],
    *,
    origin: tuple[float, float] | None = None,
    now: datetime | None = None,
) -> CompareResponse:
    rows = db.execute(
        select(BusinessProfile)
        .options(*card_load_options(), selectinload(BusinessProfile.services))
        .where(BusinessProfile.id.in_(ids), BusinessProfile.is_published.is_(True))
    ).scalars().all()
    by_id = {b.id: b for b in rows}
    missing = [i for i in ids if i not in by_id]
    if missing:
        raise BusinessesNotFound(missing)

    items = []
    for business_id in ids:  # keep the order the user picked
        b = by_id[business_id]
        items.append(
            CompareItem(
                **to_card(b, origin=origin, now=now).model_dump(),
                services=[ServiceOut.model_validate(s) for s in b.services],
                active_offers=[o.title for o in live_offers(b.offers, local_today(now))],
            )
        )
    return CompareResponse(items=items, highlights=compute_highlights(items))
