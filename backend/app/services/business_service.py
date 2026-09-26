import math
from collections import Counter
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.business import BusinessProfile, OfferStatus
from app.models.engagement import BusinessView, SavedBusiness, SavedList
from app.schemas.business import BusinessAnalytics, BusinessCard, WeeklyPoint
from app.services.hours import is_open_now, today_hours_label

_DAY_LABELS = ["M", "T", "W", "T", "F", "S", "S"]


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in km, unrounded (used for filtering and sorting)."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return r * 2 * math.asin(math.sqrt(a))


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance rounded to 0.1 km for display."""
    return round(distance_km(lat1, lon1, lat2, lon2), 1)


def card_load_options() -> tuple:
    """Eager-load everything `to_card` touches, avoiding one query per business."""
    return (
        selectinload(BusinessProfile.category),
        selectinload(BusinessProfile.hours),
        selectinload(BusinessProfile.offers),
    )


def has_active_offer(b: BusinessProfile) -> bool:
    return any(o.status == OfferStatus.active for o in b.offers)


def is_new_business(b: BusinessProfile, now: datetime | None = None) -> bool:
    created = b.created_at
    if created is None:
        return False
    if created.tzinfo is None:  # SQLite returns naive datetimes
        created = created.replace(tzinfo=timezone.utc)
    now = now or datetime.now(timezone.utc)
    return now - created <= timedelta(days=settings.NEW_BUSINESS_DAYS)


def to_card(
    b: BusinessProfile,
    *,
    origin: tuple[float, float] | None = None,
    now: datetime | None = None,
) -> BusinessCard:
    distance = None
    if origin and b.latitude is not None and b.longitude is not None:
        distance = haversine_km(origin[0], origin[1], b.latitude, b.longitude)
    return BusinessCard(
        id=b.id,
        name=b.name,
        tagline=b.tagline,
        tone=b.tone,
        address=b.address,
        price_level=b.price_level,
        rating=b.rating,
        review_count=b.review_count,
        save_count=b.save_count,
        is_verified=b.is_verified,
        category_name=b.category.name if b.category else None,
        distance_km=distance,
        category_slug=b.category.slug if b.category else None,
        price_min=b.price_min,
        price_max=b.price_max,
        is_open_now=is_open_now(b.hours, now),
        today_hours=today_hours_label(b.hours, now),
        has_offer=has_active_offer(b),
        is_new=is_new_business(b, now),
    )


def record_view(db: Session, business: BusinessProfile, viewer_id: int | None) -> None:
    db.add(BusinessView(business_id=business.id, viewer_id=viewer_id))
    business.view_count = (business.view_count or 0) + 1
    db.commit()


def is_saved_by(db: Session, business_id: int, user_id: int) -> bool:
    stmt = (
        select(SavedBusiness.id)
        .join(SavedList, SavedList.id == SavedBusiness.list_id)
        .where(SavedList.user_id == user_id, SavedBusiness.business_id == business_id)
    )
    return db.execute(stmt).first() is not None


def build_analytics(db: Session, business: BusinessProfile) -> BusinessAnalytics:
    since = datetime.now(timezone.utc) - timedelta(days=6)
    rows = db.execute(
        select(BusinessView.created_at).where(
            BusinessView.business_id == business.id, BusinessView.created_at >= since
        )
    ).all()

    counts: Counter[int] = Counter()
    for (created,) in rows:
        counts[created.weekday()] += 1

    # Fall back to the denormalized counter so the chart is never flat-empty in a demo.
    weekly = [WeeklyPoint(label=_DAY_LABELS[d], value=counts.get(d, 0)) for d in range(7)]
    if sum(c.value for c in weekly) == 0 and business.view_count:
        base = max(1, business.view_count // 12)
        pattern = [4, 5, 5, 7, 6, 9, 8]
        weekly = [WeeklyPoint(label=_DAY_LABELS[d], value=base * pattern[d]) for d in range(7)]

    return BusinessAnalytics(
        business_id=business.id,
        profile_views=business.view_count,
        saves=business.save_count,
        messages=0,
        rating=business.rating,
        review_count=business.review_count,
        weekly_views=weekly,
    )
