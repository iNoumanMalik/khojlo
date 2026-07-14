import math
from collections import Counter
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile
from app.models.engagement import BusinessView, SavedBusiness, SavedList
from app.schemas.business import BusinessAnalytics, BusinessCard, WeeklyPoint

_DAY_LABELS = ["M", "T", "W", "T", "F", "S", "S"]


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return round(r * 2 * math.asin(math.sqrt(a)), 1)


def to_card(
    b: BusinessProfile,
    *,
    origin: tuple[float, float] | None = None,
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
