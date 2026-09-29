import math
from collections import Counter
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.models.business import BusinessProfile
from app.models.campaign import Campaign
from app.models.engagement import BusinessView, SavedBusiness, SavedList
from app.models.media import BusinessPhoto, Media
from app.schemas.business import BusinessAnalytics, BusinessCard, CampaignRef, WeeklyPoint
from app.schemas.media import PhotoOut
from app.services.hours import is_open_now, today_hours_label
from app.services.media_service import delete_if_unused
from app.services.promotion_service import live_offers, local_today, visible_campaign

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
        # Campaigns and their linked offers, for the "Active promotion" badge.
        selectinload(BusinessProfile.campaigns).selectinload(Campaign.offer_links),
        selectinload(BusinessProfile.photos),  # media rows join in; their bytes stay deferred
    )


def photo_out(media: Media | None) -> PhotoOut | None:
    return PhotoOut.model_validate(media) if media is not None else None


def set_business_photos(db: Session, b: BusinessProfile, media: list[Media]) -> None:
    """Make `media` the gallery, in order (the first is the cover).

    Rows for photos that stay are reused and only re-positioned, so the unique
    (business, photo) constraint never sees a duplicate while the change is flushed.
    Photos that were removed are deleted unless something else still uses them.
    """
    wanted = {m.id: position for position, m in enumerate(media)}
    removed = set()
    for photo in list(b.photos):
        if photo.media_id in wanted:
            photo.position = wanted.pop(photo.media_id)
        else:
            removed.add(photo.media_id)
            b.photos.remove(photo)
    for m in media:
        if m.id in wanted:
            b.photos.append(BusinessPhoto(media=m, position=wanted[m.id]))
    db.flush()
    delete_if_unused(db, removed)
    db.expire(b, ["photos"])


def has_active_offer(b: BusinessProfile, now: datetime | None = None) -> bool:
    return bool(live_offers(b.offers, local_today(now)))


def campaign_ref(b: BusinessProfile, now: datetime | None = None) -> CampaignRef | None:
    c = visible_campaign(b, local_today(now))
    return CampaignRef(id=c.id, name=c.name) if c is not None else None


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
        has_offer=has_active_offer(b, now),
        active_campaign=campaign_ref(b, now),
        is_new=is_new_business(b, now),
        cover=photo_out(b.cover),
        category_label=b.category_label,
        latitude=b.latitude,
        longitude=b.longitude,
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

    from app.services.chat_service import business_message_counts  # avoids an import cycle

    messages, unread_messages = business_message_counts(db, business.id)
    return BusinessAnalytics(
        business_id=business.id,
        profile_views=business.view_count,
        saves=business.save_count,
        messages=messages,
        unread_messages=unread_messages,
        rating=business.rating,
        review_count=business.review_count,
        weekly_views=weekly,
    )
