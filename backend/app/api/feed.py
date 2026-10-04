from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.categories import categories_with_counts
from app.api.deps import get_optional_user
from app.core.database import get_db
from app.models.business import BusinessProfile
from app.models.user import User
from app.api.promotions import feed_banners
from app.schemas.feed import FeedResponse, FeedSection
from app.services import promotion_service as ps
from app.services.business_service import card_load_options, to_card
from app.services.hours import to_local
from app.services.review_service import ranking_score

router = APIRouter(prefix="/feed", tags=["feed"])


NEW_THIS_WEEK = timedelta(days=7)


def _greeting(user: User | None, businesses, now: datetime) -> tuple[str, str]:
    """The greeting ("Good evening, Ali") and a headline from real data: how many businesses joined
    Khojlo in the last 7 days. The hour is the businesses' local time, not UTC."""
    hour = to_local(now).hour
    part = ("morning" if 5 <= hour < 12 else "afternoon" if 12 <= hour < 17
            else "evening" if 17 <= hour < 21 else "night")
    first = (user.full_name.split() or ["explorer"])[0] if user else "explorer"
    greeting = f"Good {part}, {first}" if part != "night" else f"Hello, {first}"

    week_ago = now - NEW_THIS_WEEK
    new = sum(1 for b in businesses
              if b.created_at and (b.created_at if b.created_at.tzinfo
                                   else b.created_at.replace(tzinfo=timezone.utc)) >= week_ago)
    if new == 1:
        headline = "1 hidden gem\nopened this week"
    elif new > 1:
        headline = f"{new} hidden gems\nopened this week"
    else:
        total = len(businesses)
        headline = (f"{total} local {'gem' if total == 1 else 'gems'}\nwaiting to be found"
                    if total else "Discover what’s\nnew nearby")
    return greeting, headline


@router.get("", response_model=FeedResponse)
def get_feed(
    background_tasks: BackgroundTasks,
    lat: float | None = Query(default=None),
    lng: float | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> FeedResponse:
    now = datetime.now(timezone.utc)
    # Scheduled offers and campaigns that have started owe their "it's live" notification.
    # There's no scheduler, so Home (the most visited screen) sends them; the
    # `app.jobs.promotions` job does the same from cron.
    jobs = ps.due_notices(db, now)
    if jobs:
        db.commit()
        for job in jobs:
            background_tasks.add_task(job)

    origin = (lat, lng) if lat is not None and lng is not None else None

    published = (
        select(BusinessProfile)
        .options(*card_load_options())
        .where(BusinessProfile.is_published.is_(True))
    )
    businesses = db.execute(published).scalars().all()

    by_rating = sorted(businesses, key=lambda b: ranking_score(b.rating, b.review_count),
                       reverse=True)
    by_new = sorted(businesses, key=lambda b: b.created_at, reverse=True)
    by_saves = sorted(businesses, key=lambda b: b.save_count, reverse=True)

    # Home's chips: only categories with published businesses, so none leads nowhere.
    categories = [c for c in categories_with_counts(db) if c.business_count]

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

    greeting, headline = _greeting(user, businesses, now)
    return FeedResponse(
        greeting=greeting,
        headline=headline,
        categories=categories,
        sections=sections,
        campaigns=feed_banners(db, now),
    )


@router.get("/surprise", response_model=list[dict])
def surprise(db: Session = Depends(get_db)) -> list[dict]:
    """Shuffle stack for the "Surprise Me" screen: every listed business, in a new random
    order each time (suspended ones are unpublished, so they never appear)."""
    import random

    businesses = list(db.execute(
        select(BusinessProfile)
        .options(*card_load_options())
        .where(BusinessProfile.is_published.is_(True))
    ).scalars().all())
    random.shuffle(businesses)
    return [to_card(b).model_dump() for b in businesses]
