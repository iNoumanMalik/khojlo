"""Module 5 — reviews and ratings API (SRS FR-6, UC-7, BR-4; SDD `Review`, Algorithm 7).

Anyone may read reviews. Any signed-in user may write one review per business, except
the business's owner, who can reply publicly instead. Users can mark reviews helpful and
report them; reports wait for the admin (Module 8, SDD Algorithm 10).
"""
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_optional_user
from app.core.database import get_db
from app.models.business import BusinessProfile
from app.models.media import Media
from app.models.notification import NotificationKind
from app.models.review import Review, ReviewPhoto, ReviewReport, ReviewVote
from app.models.user import User
from app.schemas.review import (
    HelpfulOut,
    MyReview,
    ReplyIn,
    ReportIn,
    ReviewCreate,
    ReviewOut,
    ReviewPage,
    ReviewSort,
    ReviewUpdate,
)
from app.services import moderation_rules as rules
from app.services import notification_service as ns
from app.services import review_service as rs
from app.services.media_service import UnknownPhotos, delete_if_unused, resolve_keys

router = APIRouter(tags=["reviews"])

UNPROCESSABLE = 422


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _business(db: Session, business_id: int) -> BusinessProfile:
    b = db.get(BusinessProfile, business_id)
    if b is None or not b.is_published:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return b


def _review(db: Session, review_id: int) -> Review:
    r = db.get(Review, review_id)
    if r is None or r.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    return r


def _visible_review(db: Session, review_id: int) -> Review:
    r = _review(db, review_id)
    if not r.is_approved:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    return r


def _own_review(db: Session, review_id: int, user: User) -> Review:
    r = _review(db, review_id)
    if r.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="You can only change your own review.")
    return r


def _my_active_review(db: Session, business_id: int, user_id: int) -> Review | None:
    return db.scalar(select(Review).where(
        Review.business_id == business_id, Review.user_id == user_id, Review.deleted_at.is_(None)
    ))


def _viewer_marks(db: Session, user: User | None, ids: list[int]) -> tuple[set[int], set[int]]:
    """Which of these reviews the viewer voted helpful, and which they reported."""
    if user is None or not ids:
        return set(), set()
    voted = set(db.scalars(select(ReviewVote.review_id).where(
        ReviewVote.user_id == user.id, ReviewVote.review_id.in_(ids))))
    reported = set(db.scalars(select(ReviewReport.review_id).where(
        ReviewReport.reporter_id == user.id, ReviewReport.review_id.in_(ids))))
    return voted, reported


def _resolve_photos(db: Session, keys: list[str], user: User, review: Review | None = None
                    ) -> list[Media]:
    attached = {p.media_id for p in review.photos} if review is not None else set()
    if len(set(keys)) != len(keys):
        raise HTTPException(status_code=UNPROCESSABLE, detail="The same photo was added twice.")
    try:
        return resolve_keys(db, keys, allowed_owner=user.id, already_attached=attached)
    except UnknownPhotos:
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail="Some photos couldn't be found. Please upload them again.",
        ) from None


def _set_photos(db: Session, review: Review, media: list[Media]) -> None:
    """Make `media` the review's photos, in order; drop removed ones if nothing uses them."""
    wanted = {m.id: position for position, m in enumerate(media)}
    removed = set()
    for photo in list(review.photos):
        if photo.media_id in wanted:
            photo.position = wanted.pop(photo.media_id)
        else:
            removed.add(photo.media_id)
            review.photos.remove(photo)
    for m in media:
        if m.id in wanted:
            review.photos.append(ReviewPhoto(media_id=m.id, position=wanted[m.id]))
    db.flush()
    delete_if_unused(db, removed)


def _out(db: Session, review: Review, user: User | None) -> ReviewOut:
    voted, reported = _viewer_marks(db, user, [review.id])
    return rs.to_out(review, viewer_id=user.id if user else None, voted=voted, reported=reported)


# ─────────────── reading ───────────────
@router.get("/businesses/{business_id}/reviews", response_model=ReviewPage,
            summary="Reviews of a business, with the rating summary")
def list_reviews(
    business_id: int,
    sort: ReviewSort = Query(default=ReviewSort.relevant),
    stars: list[int] = Query(default=[], description="Only these star ratings; repeatable"),
    photos: bool = Query(default=False, description="Only reviews with photos"),
    limit: int = Query(default=10, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> ReviewPage:
    b = _business(db, business_id)
    if any(s < 1 or s > 5 for s in stars):
        raise HTTPException(status_code=UNPROCESSABLE, detail="Star filters must be 1–5.")
    is_owner = user is not None and b.owner_id == user.id

    query = rs.active_reviews().join(User, Review.author).where(Review.business_id == b.id)
    if stars:
        query = query.where(Review.rating.in_(stars))
    if photos:
        query = query.where(Review.photos.any())
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    items = list(db.scalars(query.order_by(*rs.order_by(sort)).limit(limit).offset(offset)))

    mine = _my_active_review(db, b.id, user.id) if user else None
    marked = [r.id for r in items] + ([mine.id] if mine else [])
    voted, reported = _viewer_marks(db, user, marked)
    viewer_id = user.id if user else None
    return ReviewPage(
        summary=rs.summary(db, b.id, for_owner=is_owner),
        items=[rs.to_out(r, viewer_id=viewer_id, voted=voted, reported=reported) for r in items],
        total=total,
        limit=limit,
        offset=offset,
        sort=sort,
        mine=rs.to_out(mine, viewer_id=viewer_id, voted=voted, reported=reported) if mine else None,
        can_review=user is not None and not is_owner and mine is None,
        is_owner=is_owner,
    )


@router.get("/users/me/reviews", response_model=list[MyReview], summary="My reviews")
def my_reviews(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MyReview]:
    reviews = db.scalars(
        select(Review).where(Review.user_id == user.id, Review.deleted_at.is_(None))
        .order_by(Review.created_at.desc(), Review.id.desc())
    )
    return [
        MyReview(**rs.to_out(r, viewer_id=user.id).model_dump(),
                 business=rs.reviewed_business(r.business))
        for r in reviews
    ]


# ─────────────── writing (UC-7) ───────────────
@router.post("/businesses/{business_id}/reviews", response_model=ReviewOut,
             status_code=status.HTTP_201_CREATED, summary="Write a review")
def create_review(
    business_id: int,
    payload: ReviewCreate,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReviewOut:
    """SDD Algorithm 7: validate, store, recalculate the business's average rating."""
    b = _business(db, business_id)
    if b.owner_id == user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="You can't review your own business. You can reply to reviews instead.")
    if _my_active_review(db, b.id, user.id) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail=f"You've already reviewed {b.name}. Edit your review instead.")
    media = _resolve_photos(db, payload.photos, user)
    review = Review(business_id=b.id, user_id=user.id, rating=payload.rating,
                    comment=payload.comment.strip())
    db.add(review)
    try:
        db.flush()
    except IntegrityError:  # a second, simultaneous submission (BR-4)
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail=f"You've already reviewed {b.name}. Edit your review instead.") from None
    _set_photos(db, review, media)
    rs.refresh_rating(db, b)
    rules.check_review(db, review)  # Module 8: flags for an admin, nothing hidden (BR-13)
    stars = "★" * review.rating
    job = ns.notify(
        db, [b.owner], NotificationKind.review,
        title=f"New {review.rating}★ review for {b.name}",
        body=f"{rs.display_name(user.full_name)}: {ns.snippet(review.comment)}"
        if review.comment else f"{rs.display_name(user.full_name)} rated you {stars}",
        route=ns.reviews_route(b),
    )
    db.commit()
    db.refresh(review)
    if job is not None:
        background_tasks.add_task(job)
    return _out(db, review, user)


@router.patch("/reviews/{review_id}", response_model=ReviewOut, summary="Edit my review")
def update_review(
    review_id: int,
    payload: ReviewUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReviewOut:
    """UC-7 alternative flow "Edit review"."""
    review = _own_review(db, review_id, user)
    changes = payload.model_dump(exclude_unset=True)
    changed = False
    if changes.get("rating") is not None and changes["rating"] != review.rating:
        review.rating = changes["rating"]
        changed = True
    if changes.get("comment") is not None and changes["comment"].strip() != review.comment:
        review.comment = changes["comment"].strip()
        changed = True
    if changes.get("photos") is not None:
        media = _resolve_photos(db, changes["photos"], user, review)
        if [m.id for m in media] != [p.media_id for p in review.photos]:
            _set_photos(db, review, media)
            changed = True
    if changed:
        review.updated_at = _now()
        rs.refresh_rating(db, review.business)
        rules.check_review(db, review)
        db.commit()
        db.refresh(review)
    return _out(db, review, user)


@router.delete("/reviews/{review_id}", status_code=status.HTTP_204_NO_CONTENT,
               response_class=Response, summary="Delete my review")
def delete_review(
    review_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """Soft delete (SDD ER `deleted_at`); the user may then write a new review."""
    review = _own_review(db, review_id, user)
    review.deleted_at = _now()
    photo_ids = {p.media_id for p in review.photos}
    review.photos.clear()
    db.flush()
    delete_if_unused(db, photo_ids)
    rs.refresh_rating(db, review.business)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ─────────────── owner replies ───────────────
def _owned_review(db: Session, review_id: int, user: User) -> Review:
    review = _visible_review(db, review_id)
    if review.business.owner_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Only the business owner can reply to its reviews.")
    return review


@router.put("/reviews/{review_id}/reply", response_model=ReviewOut, summary="Reply as the owner")
def reply(
    review_id: int,
    payload: ReplyIn,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReviewOut:
    review = _owned_review(db, review_id, user)
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=UNPROCESSABLE, detail="Write a reply first.")
    if text != review.owner_reply:
        is_new = review.owner_reply is None
        review.owner_reply = text
        review.owner_reply_at = _now()
        job = None
        if is_new:  # edits to a reply don't notify again
            job = ns.notify(
                db, [review.author], NotificationKind.review_reply,
                title=f"{review.business.name} replied to your review",
                body=ns.snippet(text), route=ns.reviews_route(review.business),
            )
        db.commit()
        db.refresh(review)
        if job is not None:
            background_tasks.add_task(job)
    return _out(db, review, user)


@router.delete("/reviews/{review_id}/reply", response_model=ReviewOut,
               summary="Remove the owner's reply")
def delete_reply(
    review_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReviewOut:
    review = _owned_review(db, review_id, user)
    review.owner_reply = None
    review.owner_reply_at = None
    db.commit()
    db.refresh(review)
    return _out(db, review, user)


# ─────────────── helpful votes and reports ───────────────
def _others_review(db: Session, review_id: int, user: User, action: str) -> Review:
    review = _visible_review(db, review_id)
    if review.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"You can't {action} your own review.")
    return review


def _helpful_state(db: Session, review: Review, user: User) -> HelpfulOut:
    review.helpful_count = db.scalar(
        select(func.count(ReviewVote.id)).where(ReviewVote.review_id == review.id)) or 0
    voted = db.scalar(select(ReviewVote.id).where(
        ReviewVote.review_id == review.id, ReviewVote.user_id == user.id)) is not None
    db.commit()
    return HelpfulOut(helpful_count=review.helpful_count, voted_helpful=voted)


@router.put("/reviews/{review_id}/helpful", response_model=HelpfulOut,
            summary="Mark a review helpful")
def vote_helpful(
    review_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HelpfulOut:
    review = _others_review(db, review_id, user, "vote on")
    exists = db.scalar(select(ReviewVote.id).where(
        ReviewVote.review_id == review.id, ReviewVote.user_id == user.id))
    if exists is None:
        db.add(ReviewVote(review_id=review.id, user_id=user.id))
        try:
            db.flush()
        except IntegrityError:  # voted twice at once: the first vote stands
            db.rollback()
            review = _visible_review(db, review_id)
    return _helpful_state(db, review, user)


@router.delete("/reviews/{review_id}/helpful", response_model=HelpfulOut,
               summary="Take back a helpful vote")
def unvote_helpful(
    review_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HelpfulOut:
    review = _others_review(db, review_id, user, "vote on")
    vote = db.scalar(select(ReviewVote).where(
        ReviewVote.review_id == review.id, ReviewVote.user_id == user.id))
    if vote is not None:
        db.delete(vote)
        db.flush()
    return _helpful_state(db, review, user)


@router.post("/reviews/{review_id}/report", status_code=status.HTTP_201_CREATED,
             response_class=Response, summary="Report a review")
def report_review(
    review_id: int,
    payload: ReportIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """Stored for the admin's "Flagged reviews" queue (Module 8, SDD Algorithm 10)."""
    review = _others_review(db, review_id, user, "report")
    db.add(ReviewReport(review_id=review.id, reporter_id=user.id, reason=payload.reason,
                        note=payload.note.strip()))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="You've already reported this review. Thanks for letting us know.") from None
    return Response(status_code=status.HTTP_201_CREATED)
