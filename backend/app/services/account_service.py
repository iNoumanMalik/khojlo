"""Deleting an account and everything that belongs to it (SRS FR-32).

Nearly all of a user's data hangs off `users` with ON DELETE CASCADE: their businesses (and
those businesses' photos, offers, reviews and conversations), reviews, votes, reports, saved
lists, uploads, conversations and messages, devices, notifications, one-time codes and
search history. Profile views they made stay, without the viewer.

What the cascade can't do is fix the counters other rows keep about this user's activity,
so those are recalculated here.
"""
from __future__ import annotations

from sqlalchemy import distinct, func, select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile
from app.models.engagement import SavedBusiness, SavedList
from app.models.review import Review, ReviewVote
from app.models.user import User
from app.services.review_service import refresh_rating


def delete_account(db: Session, user: User) -> None:
    own = select(BusinessProfile.id).where(BusinessProfile.owner_id == user.id)
    reviewed = set(db.scalars(
        select(distinct(Review.business_id))
        .where(Review.user_id == user.id, Review.business_id.not_in(own))
    ))
    voted = set(db.scalars(select(ReviewVote.review_id).where(ReviewVote.user_id == user.id)))
    saved = set(db.scalars(
        select(distinct(SavedBusiness.business_id))
        .join(SavedList, SavedList.id == SavedBusiness.list_id)
        .where(SavedList.user_id == user.id, SavedBusiness.business_id.not_in(own))
    ))

    # Their profile photo is one of their uploads, which the delete removes; unlink it
    # first so the cascade doesn't also have to update the row it is deleting.
    user.avatar_media_id = None
    db.flush()
    db.delete(user)
    db.flush()
    db.expire_all()

    for business in db.scalars(select(BusinessProfile).where(BusinessProfile.id.in_(reviewed))):
        refresh_rating(db, business)
    for review in db.scalars(select(Review).where(Review.id.in_(voted))):
        review.helpful_count = db.scalar(
            select(func.count(ReviewVote.id)).where(ReviewVote.review_id == review.id)) or 0
    for business in db.scalars(select(BusinessProfile).where(BusinessProfile.id.in_(saved))):
        business.save_count = max(0, (business.save_count or 0) - 1)
    db.commit()
