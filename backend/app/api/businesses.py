from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_owner, get_current_user, get_optional_user
from app.core.database import get_db
from app.models.business import (
    BusinessProfile,
    Category,
    OpeningHours,
    Service,
)
from app.models.engagement import SavedBusiness, SavedList
from app.models.moderation import BusinessReport, VerificationStatus
from app.models.notification import NotificationKind
from app.models.user import User
from app.schemas.business import (
    BusinessAnalytics,
    BusinessCard,
    BusinessCreate,
    BusinessDetail,
    BusinessUpdate,
    HoursReplace,
    PhotosReplace,
)
from app.schemas.moderation import (
    BusinessReportIn,
    CheckOut,
    ReviewRequestIn,
    StorefrontIn,
    VerificationOut,
)
from app.schemas.saved import SaveToListRequest
from app.services.business_service import (
    build_analytics,
    card_load_options,
    is_saved_by,
    photo_out,
    record_view,
    set_business_photos,
    to_card,
)
from app.services import moderation_rules as rules
from app.services import notification_service as ns
from app.services import verification_service as vs
from app.services.media_service import UnknownPhotos, delete_if_unused, resolve_keys
from app.services.moderation_service import ModerationError, reason_label
from app.services.promotion_service import live_offers, local_today, offer_out

UNPROCESSABLE = 422

router = APIRouter(prefix="/businesses", tags=["businesses"])


def _get_owned(db: Session, business_id: int, owner: User) -> BusinessProfile:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    # SEC-2: only the owner edits a business. Admins moderate through /admin (audited).
    if b.owner_id != owner.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your business")
    return b


def _run(background_tasks: BackgroundTasks, jobs) -> None:
    for job in jobs:
        if job is not None:
            background_tasks.add_task(job)


def _moderate(db: Session, b: BusinessProfile) -> list:
    """Module 8 after any owner change: the rules, then the automatic verification."""
    rules.check_business(db, b)
    return vs.refresh(db, b)


def _check_category(db: Session, b: BusinessProfile) -> None:
    """The category must exist; "Other" needs the owner's own description, others drop it."""
    if b.category_id is None:
        b.custom_category = None
        return
    category = db.get(Category, b.category_id)
    if category is None:
        raise HTTPException(status_code=UNPROCESSABLE, detail="Pick a category from the list.")
    if not category.is_other:
        b.custom_category = None
    elif not b.custom_category:
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail="Tell people what kind of business it is, e.g. “Calligraphy studio”.",
        )


def _resolve_photos(db: Session, keys: list[str], user: User, b: BusinessProfile | None = None):
    attached = {p.media_id for p in b.photos} if b is not None else set()
    try:
        return resolve_keys(db, keys, allowed_owner=user.id, already_attached=attached)
    except UnknownPhotos:
        raise HTTPException(
            status_code=UNPROCESSABLE,
            detail="Some photos couldn't be found. Please upload them again.",
        ) from None


# ─────────────── owner CRUD ───────────────
@router.get("/mine", response_model=list[BusinessCard])
def my_businesses(
    owner: User = Depends(get_current_owner), db: Session = Depends(get_db)
) -> list[BusinessCard]:
    rows = db.execute(
        select(BusinessProfile)
        .options(*card_load_options())
        .where(BusinessProfile.owner_id == owner.id)
    ).scalars().all()
    return [to_card(b) for b in rows]


@router.post("", response_model=BusinessDetail, status_code=status.HTTP_201_CREATED)
def create_business(
    payload: BusinessCreate,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    photos = _resolve_photos(db, payload.photos, owner)
    b = BusinessProfile(
        owner_id=owner.id,
        **payload.model_dump(exclude={"services", "hours", "photos"}),
    )
    _check_category(db, b)
    for s in payload.services:
        b.services.append(Service(**s.model_dump()))
    for h in payload.hours:
        b.hours.append(OpeningHours(**h.model_dump()))
    db.add(b)
    db.flush()
    set_business_photos(db, b, photos)
    db.refresh(b)
    jobs = _moderate(db, b)
    job = None
    if b.is_published and b.category is not None:
        category = b.category_label or b.category.name
        job = ns.notify(
            db, ns.users_interested_in(db, b), NotificationKind.new_business,
            title=f"New on Khojlo: {b.name}",
            body=ns.snippet(b.tagline) if b.tagline else f"A new place in {category}",
            route=ns.business_route(b),
        )
    db.commit()
    db.refresh(b)
    _run(background_tasks, [job, *jobs])
    return _detail(db, b, owner)


# The storefront photo shows these, so changing one needs a new photo (Module 8).
IDENTITY_FIELDS = ("name", "address", "latitude", "longitude")


@router.patch("/{business_id}", response_model=BusinessDetail)
def update_business(
    business_id: int,
    payload: BusinessUpdate,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    b = _get_owned(db, business_id, owner)
    changes = payload.model_dump(exclude_unset=True)
    if changes.get("is_published") and b.suspended_at is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Khojlo’s moderators suspended this business, so it can’t be published "
                   "until they reinstate it.",
        )
    before = {f: getattr(b, f) for f in IDENTITY_FIELDS}
    for field, value in changes.items():
        setattr(b, field, value)
    # Cross-field rules are checked on the merged record, since a patch may send one side.
    if b.price_min is not None and b.price_max is not None and b.price_min > b.price_max:
        raise HTTPException(
            status_code=422, detail="Minimum price can't be higher than the maximum price"
        )
    if (b.latitude is None) != (b.longitude is None):
        raise HTTPException(
            status_code=422, detail="Provide both latitude and longitude, or neither"
        )
    if b.latitude == 0 and b.longitude == 0:
        raise HTTPException(
            status_code=422,
            detail="That location (0, 0) isn't valid. Set the pin on the map again.",
        )
    _check_category(db, b)
    jobs = []
    if any(getattr(b, f) != before[f] for f in IDENTITY_FIELDS):
        jobs += vs.identity_changed(db, b)
    jobs += _moderate(db, b)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return _detail(db, b, owner)


@router.put("/{business_id}/photos", response_model=BusinessDetail)
def replace_photos(
    business_id: int,
    payload: PhotosReplace,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    """Set the gallery: photos in display order, the first being the cover (empty removes all).

    Each key must be one of your uploads (POST /media) or already in this gallery.
    """
    b = _get_owned(db, business_id, owner)
    set_business_photos(db, b, _resolve_photos(db, payload.photos, owner, b))
    db.refresh(b)
    jobs = vs.refresh(db, b)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return _detail(db, b, owner)


@router.put("/{business_id}/hours", response_model=BusinessDetail)
def replace_hours(
    business_id: int,
    payload: HoursReplace,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    """Replace the weekly opening hours (an empty list clears them)."""
    b = _get_owned(db, business_id, owner)
    b.hours = [OpeningHours(**h.model_dump()) for h in payload.hours]
    db.flush()
    jobs = vs.refresh(db, b)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return _detail(db, b, owner)


@router.delete("/{business_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_business(
    business_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> None:
    b = _get_owned(db, business_id, owner)
    photo_ids = {p.media_id for p in b.photos} | ({b.storefront_media_id} - {None})
    db.delete(b)
    db.flush()
    delete_if_unused(db, photo_ids)
    db.commit()


# ─────────────── analytics ───────────────
@router.get("/{business_id}/analytics", response_model=BusinessAnalytics)
def business_analytics(
    business_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessAnalytics:
    b = _get_owned(db, business_id, owner)
    return build_analytics(db, b)


# ─────────────── public detail + save ───────────────
def _detail(db: Session, b: BusinessProfile, viewer: User | None) -> BusinessDetail:
    card = to_card(b)
    today = local_today()
    return BusinessDetail(
        **card.model_dump(),
        description=b.description,
        category_id=b.category_id,
        custom_category=b.custom_category,
        phone=b.phone,
        photos=[photo_out(p.media) for p in b.photos],
        view_count=b.view_count,
        services=b.services,
        hours=b.hours,
        # Customers see live offers only (switched on and within their dates).
        offers=[offer_out(o, today) for o in live_offers(b.offers, today)],
        is_saved=is_saved_by(db, b.id, viewer.id) if viewer else False,
        is_owner=viewer is not None and b.owner_id == viewer.id,
    )


@router.get("/{business_id}", response_model=BusinessDetail)
def business_detail(
    business_id: int,
    track: bool = Query(
        default=True,
        description="Count this as a profile view. The owner's edit screens send false.",
    ),
    db: Session = Depends(get_db),
    viewer: User | None = Depends(get_optional_user),
) -> BusinessDetail:
    b = db.get(BusinessProfile, business_id)
    is_owner = viewer is not None and b is not None and b.owner_id == viewer.id
    # A suspended listing is gone for everyone but its owner (Module 8).
    if b is None or (b.suspended_at is not None and not is_owner):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    if track:
        record_view(db, b, viewer.id if viewer else None)
    return _detail(db, b, viewer)


@router.post("/{business_id}/save", response_model=BusinessDetail)
def save_business(
    business_id: int,
    payload: SaveToListRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")

    if payload.list_id is not None:
        target = db.get(SavedList, payload.list_id)
        if target is None or target.user_id != user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="List not found")
    else:
        target = db.execute(
            select(SavedList).where(SavedList.user_id == user.id).order_by(SavedList.created_at)
        ).scalars().first()
        if target is None:
            target = SavedList(user_id=user.id, name="Saved", tone="gold")
            db.add(target)
            db.flush()

    already = db.execute(
        select(SavedBusiness).where(
            SavedBusiness.list_id == target.id, SavedBusiness.business_id == b.id
        )
    ).scalar_one_or_none()
    if already is None:
        db.add(SavedBusiness(list_id=target.id, business_id=b.id))
        b.save_count = (b.save_count or 0) + 1
        db.commit()
    return _detail(db, b, user)


@router.delete("/{business_id}/save", response_model=BusinessDetail)
def unsave_business(
    business_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    rows = db.execute(
        select(SavedBusiness)
        .join(SavedList, SavedList.id == SavedBusiness.list_id)
        .where(SavedList.user_id == user.id, SavedBusiness.business_id == b.id)
    ).scalars().all()
    for row in rows:
        db.delete(row)
    if rows:
        b.save_count = max(0, (b.save_count or 0) - 1)
        db.commit()
    return _detail(db, b, user)


# ─────────────── Module 8: reporting a business (FR-19, extended) ───────────────
@router.post("/{business_id}/report", status_code=status.HTTP_201_CREATED,
             response_class=Response, summary="Report a business")
def report_business(
    business_id: int,
    payload: BusinessReportIn,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """For the admin's reports queue. The listing stays up until an admin decides (BR-13)."""
    b = db.get(BusinessProfile, business_id)
    if b is None or not b.is_published:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    if b.owner_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="You can’t report your own business.")
    db.add(BusinessReport(business_id=b.id, reporter_id=user.id, reason=payload.reason,
                          note=payload.note.strip()))
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="You’ve already reported this business. Thanks for letting "
                                   "us know.") from None
    jobs = vs.refresh(db, b)  # an open report refers a ready business to an admin
    db.commit()
    _run(background_tasks, jobs)
    return Response(status_code=status.HTTP_201_CREATED)


# ─────────────── Module 8: the owner's verification checklist ───────────────
def verification_out(db: Session, b: BusinessProfile) -> VerificationOut:
    return VerificationOut(
        business_id=b.id,
        status=b.verification_status,
        is_verified=b.is_verified,
        checks=[CheckOut(key=c.key, label=c.label, passed=c.passed,
                         hint="" if c.passed else c.hint) for c in vs.checks(db, b)],
        storefront=photo_out(b.storefront),
        storefront_at=b.storefront_at,
        note=b.verification_note or "",
        verified_at=b.verified_at,
        can_request_review=b.verification_status in (VerificationStatus.needs_info,
                                                     VerificationStatus.rejected),
        is_suspended=b.suspended_at is not None,
        suspension_reason=reason_label(b.suspension_reason) if b.suspended_at else None,
    )


@router.get("/{business_id}/verification", response_model=VerificationOut,
            summary="My business's verification checklist")
def get_verification(
    business_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> VerificationOut:
    return verification_out(db, _get_owned(db, business_id, owner))


@router.put("/{business_id}/verification/storefront", response_model=VerificationOut,
            summary="Add the storefront photo")
def set_storefront(
    business_id: int,
    payload: StorefrontIn,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> VerificationOut:
    """A photo of the shop front or signboard, taken in the app. Upload it with POST /media
    first. Only the owner and admins see it."""
    b = _get_owned(db, business_id, owner)
    attached = {b.storefront_media_id} - {None}
    try:
        media = resolve_keys(db, [payload.photo], allowed_owner=owner.id,
                             already_attached=attached)[0]
    except UnknownPhotos:
        raise HTTPException(status_code=UNPROCESSABLE,
                            detail="That photo couldn’t be found. Please take it again.") from None
    jobs = vs.set_storefront(db, b, media)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return verification_out(db, b)


@router.post("/{business_id}/verification/review", response_model=VerificationOut,
             summary="Ask Khojlo to look again")
def request_verification_review(
    business_id: int,
    payload: ReviewRequestIn,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> VerificationOut:
    """After "Request more info" (UC-12) or a rejection: back to the admin's queue."""
    b = _get_owned(db, business_id, owner)
    try:
        vs.request_review(db, b, payload.note)
    except ModerationError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from None
    db.commit()
    db.refresh(b)
    return verification_out(db, b)
