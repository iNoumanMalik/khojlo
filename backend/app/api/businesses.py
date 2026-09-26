from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_owner, get_current_user, get_optional_user
from app.core.database import get_db
from app.models.business import BusinessProfile, Category, Offer, OpeningHours, Service
from app.models.engagement import SavedBusiness, SavedList
from app.models.user import User
from app.schemas.business import (
    BusinessAnalytics,
    BusinessCard,
    BusinessCreate,
    BusinessDetail,
    BusinessUpdate,
    HoursReplace,
    OfferIn,
    OfferOut,
    PhotosReplace,
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
from app.services.media_service import UnknownPhotos, delete_if_unused, resolve_keys

UNPROCESSABLE = 422

router = APIRouter(prefix="/businesses", tags=["businesses"])


def _get_owned(db: Session, business_id: int, owner: User) -> BusinessProfile:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    if b.owner_id != owner.id and owner.role.value != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your business")
    return b


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
    db.commit()
    db.refresh(b)
    return _detail(db, b, owner)


@router.patch("/{business_id}", response_model=BusinessDetail)
def update_business(
    business_id: int,
    payload: BusinessUpdate,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    b = _get_owned(db, business_id, owner)
    for field, value in payload.model_dump(exclude_unset=True).items():
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
    _check_category(db, b)
    db.commit()
    db.refresh(b)
    return _detail(db, b, owner)


@router.put("/{business_id}/photos", response_model=BusinessDetail)
def replace_photos(
    business_id: int,
    payload: PhotosReplace,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    """Set the gallery: photos in display order, the first being the cover (empty removes all).

    Each key must be one of your uploads (POST /media) or already in this gallery.
    """
    b = _get_owned(db, business_id, owner)
    set_business_photos(db, b, _resolve_photos(db, payload.photos, owner, b))
    db.commit()
    db.refresh(b)
    return _detail(db, b, owner)


@router.put("/{business_id}/hours", response_model=BusinessDetail)
def replace_hours(
    business_id: int,
    payload: HoursReplace,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> BusinessDetail:
    """Replace the weekly opening hours (an empty list clears them)."""
    b = _get_owned(db, business_id, owner)
    b.hours = [OpeningHours(**h.model_dump()) for h in payload.hours]
    db.commit()
    db.refresh(b)
    return _detail(db, b, owner)


@router.delete("/{business_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_business(
    business_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> None:
    b = _get_owned(db, business_id, owner)
    photo_ids = {p.media_id for p in b.photos}
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


# ─────────────── offers ───────────────
@router.get("/{business_id}/offers", response_model=list[OfferOut])
def list_offers(business_id: int, db: Session = Depends(get_db)) -> list[Offer]:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return b.offers


@router.post(
    "/{business_id}/offers", response_model=OfferOut, status_code=status.HTTP_201_CREATED
)
def create_offer(
    business_id: int,
    payload: OfferIn,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> Offer:
    b = _get_owned(db, business_id, owner)
    offer = Offer(business_id=b.id, **payload.model_dump())
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return offer


# ─────────────── public detail + save ───────────────
def _detail(db: Session, b: BusinessProfile, viewer: User | None) -> BusinessDetail:
    card = to_card(b)
    return BusinessDetail(
        **card.model_dump(),
        description=b.description,
        latitude=b.latitude,
        longitude=b.longitude,
        category_id=b.category_id,
        custom_category=b.custom_category,
        phone=b.phone,
        photos=[photo_out(p.media) for p in b.photos],
        view_count=b.view_count,
        services=b.services,
        hours=b.hours,
        offers=b.offers,
        is_saved=is_saved_by(db, b.id, viewer.id) if viewer else False,
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
    if b is None:
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
