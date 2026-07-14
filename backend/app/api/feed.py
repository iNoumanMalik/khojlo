from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_optional_user
from app.core.database import get_db
from app.models.business import BusinessProfile, Category
from app.models.user import User
from app.schemas.business import CategoryOut
from app.schemas.feed import FeedResponse, FeedSection
from app.services.business_service import to_card

router = APIRouter(prefix="/feed", tags=["feed"])


def _greeting() -> tuple[str, str]:
    hour = datetime.now(timezone.utc).hour
    if hour < 12:
        return "Good morning, explorer", "12 hidden gems\nopened this week"
    if hour < 18:
        return "Good afternoon, explorer", "12 hidden gems\nopened this week"
    return "Good night, explorer", "12 hidden gems\nopened this week"


@router.get("", response_model=FeedResponse)
def get_feed(
    lat: float | None = Query(default=None),
    lng: float | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> FeedResponse:
    origin = (lat, lng) if lat is not None and lng is not None else None

    published = (
        select(BusinessProfile).where(BusinessProfile.is_published.is_(True))
    )
    businesses = db.execute(published).scalars().all()

    by_rating = sorted(businesses, key=lambda b: b.rating, reverse=True)
    by_new = sorted(businesses, key=lambda b: b.created_at, reverse=True)
    by_saves = sorted(businesses, key=lambda b: b.save_count, reverse=True)

    categories = db.execute(select(Category).order_by(Category.id)).scalars().all()

    # personalize the "because you liked" row from the user's interest slugs
    liked_title = "Worth exploring"
    liked_pool = by_saves
    if user and user.interests:
        interest = user.interests[0]
        match = [b for b in businesses if b.category and b.category.slug == interest]
        if match:
            liked_pool = match
            liked_title = f"Because you like {match[0].category.name.lower()}"

    sections: list[FeedSection] = []
    if by_new:
        sections.append(
            FeedSection(
                key="featured",
                title="Featured find",
                layout="hero",
                businesses=[to_card(by_new[0], origin=origin)],
            )
        )
    sections.append(
        FeedSection(
            key="because_you_like",
            title=liked_title,
            layout="horizontal",
            businesses=[to_card(b, origin=origin) for b in liked_pool[:6]],
        )
    )
    sections.append(
        FeedSection(
            key="trending",
            title="Trending today",
            layout="list",
            businesses=[to_card(b, origin=origin) for b in by_rating[:8]],
        )
    )
    if origin:
        nearby = sorted(
            (b for b in businesses if b.latitude is not None),
            key=lambda b: to_card(b, origin=origin).distance_km or 1e9,
        )
        sections.append(
            FeedSection(
                key="nearby",
                title="Nearby",
                layout="horizontal",
                businesses=[to_card(b, origin=origin) for b in nearby[:6]],
            )
        )

    greeting, headline = _greeting()
    return FeedResponse(
        greeting=greeting,
        headline=headline,
        categories=[CategoryOut.model_validate(c) for c in categories],
        sections=sections,
    )


@router.get("/surprise", response_model=list[dict])
def surprise(db: Session = Depends(get_db)) -> list[dict]:
    """Shuffle stack for the "Surprise Me" screen."""
    import random

    businesses = db.execute(
        select(BusinessProfile).where(BusinessProfile.is_published.is_(True))
    ).scalars().all()
    random.shuffle(businesses)
    return [to_card(b).model_dump() for b in businesses[:12]]
