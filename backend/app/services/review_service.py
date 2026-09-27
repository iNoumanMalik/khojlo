"""Module 5 — rating recalculation, ranking score and review presentation."""
from __future__ import annotations

from sqlalchemy import Select, and_, case, exists, func, select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile
from app.models.review import Review, ReviewPhoto
from app.models.user import User
from app.schemas.review import (
    OwnerReply,
    ReviewAuthor,
    ReviewedBusiness,
    ReviewOut,
    ReviewSort,
    ReviewSummary,
)
from app.services.business_service import photo_out

# Count-weighted ("Bayesian") rating used only for ranking: a business's average is pulled
# towards PRIOR_MEAN as if it had PRIOR_WEIGHT extra reviews, so one 5★ review doesn't
# outrank 4.8★ from 200. Screens always show the plain average.
PRIOR_MEAN = 3.5
PRIOR_WEIGHT = 3


def active_reviews() -> Select:
    """Reviews that count: not deleted and not hidden by a moderator."""
    return select(Review).where(Review.deleted_at.is_(None), Review.is_approved.is_(True))


def _active(business_id: int):
    return and_(
        Review.business_id == business_id,
        Review.deleted_at.is_(None),
        Review.is_approved.is_(True),
    )


def refresh_rating(db: Session, business: BusinessProfile) -> None:
    """SDD Algorithm 7: recalculate the average rating and update the business."""
    db.flush()
    average, count = db.execute(
        select(func.avg(Review.rating), func.count(Review.id)).where(_active(business.id))
    ).one()
    business.review_count = count or 0
    business.rating = round(float(average), 2) if count else 0.0


def ranking_score(rating: float | None, count: int | None) -> float:
    """Sort key for "best rated": count-weighted, and unrated businesses last."""
    n = count or 0
    if n <= 0:
        return -1.0
    return (PRIOR_WEIGHT * PRIOR_MEAN + (rating or 0) * n) / (PRIOR_WEIGHT + n)


def summary(db: Session, business_id: int, *, for_owner: bool = False) -> ReviewSummary:
    rows = db.execute(
        select(Review.rating, func.count(Review.id)).where(_active(business_id))
        .group_by(Review.rating)
    ).all()
    distribution = {stars: 0 for stars in range(1, 6)}
    for stars, n in rows:
        distribution[stars] = n
    count = sum(distribution.values())
    average = sum(s * n for s, n in distribution.items()) / count if count else 0.0
    with_photos = db.scalar(
        select(func.count(Review.id)).where(
            _active(business_id), exists().where(ReviewPhoto.review_id == Review.id)
        )
    )
    unreplied = None
    if for_owner:
        unreplied = db.scalar(
            select(func.count(Review.id)).where(_active(business_id), Review.owner_reply.is_(None))
        )
    return ReviewSummary(
        average=round(average, 2),
        count=count,
        distribution=distribution,
        with_photos=with_photos or 0,
        unreplied=unreplied,
    )


def order_by(sort: ReviewSort) -> list:
    has_photos = exists().where(ReviewPhoto.review_id == Review.id)
    has_content = case((Review.comment != "", 1), (has_photos, 1), else_=0)
    newest = [Review.created_at.desc(), Review.id.desc()]
    return {
        ReviewSort.relevant: [
            User.is_verified.desc(), has_content.desc(), Review.helpful_count.desc(), *newest
        ],
        ReviewSort.recent: newest,
        ReviewSort.highest: [Review.rating.desc(), *newest],
        ReviewSort.lowest: [Review.rating.asc(), *newest],
        ReviewSort.helpful: [Review.helpful_count.desc(), *newest],
    }[sort]


def display_name(full_name: str) -> str:
    """ "Hassan Raza" → "Hassan R." (privacy, as in the SDD mockup)."""
    parts = [p for p in full_name.split() if p]
    if not parts:
        return "Khojlo user"
    if len(parts) == 1:
        return parts[0]
    return f"{parts[0]} {parts[-1][0].upper()}."


def author_out(user: User) -> ReviewAuthor:
    return ReviewAuthor(
        id=user.id,
        name=display_name(user.full_name),
        initials=user.initials,
        tone=user.avatar_tone,
        avatar=photo_out(user.avatar),
        is_verified=bool(user.is_verified),
    )


def to_out(
    review: Review,
    *,
    viewer_id: int | None = None,
    voted: set[int] = frozenset(),
    reported: set[int] = frozenset(),
) -> ReviewOut:
    reply = None
    if review.owner_reply:
        reply = OwnerReply(text=review.owner_reply, created_at=review.owner_reply_at)
    return ReviewOut(
        id=review.id,
        business_id=review.business_id,
        rating=review.rating,
        comment=review.comment,
        photos=[photo_out(p.media) for p in review.photos],
        author=author_out(review.author),
        created_at=review.created_at,
        updated_at=review.updated_at,
        helpful_count=review.helpful_count,
        owner_reply=reply,
        is_mine=viewer_id is not None and review.user_id == viewer_id,
        voted_helpful=review.id in voted,
        reported=review.id in reported,
        is_visible=review.is_approved,
    )


def reviewed_business(b: BusinessProfile) -> ReviewedBusiness:
    return ReviewedBusiness(
        id=b.id, name=b.name, tone=b.tone, cover=photo_out(b.cover),
        category_label=b.category_label,
    )
