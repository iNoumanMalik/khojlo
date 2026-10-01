from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.chat import CLOSE_UNAUTHORIZED
from app.api.deps import get_current_user, require_current_privacy_policy
from app.core.database import get_db
from app.core.security import verify_password
from app.models.engagement import SavedBusiness, SavedList
from app.models.user import User
from app.schemas.saved import SavedListCreate, SavedListOut
from app.schemas.user import (
    DeleteAccountRequest,
    InterestsUpdate,
    PrivacyConsentRequest,
    UserOut,
    UserUpdate,
)
from app.services.account_service import delete_account
from app.services.business_service import to_card
from app.services.media_service import UnknownPhotos, delete_if_unused, resolve_keys
from app.services.realtime import manager

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def read_me(user: User = Depends(get_current_user)) -> User:
    return user


@router.patch("/me", response_model=UserOut)
def update_me(
    payload: UserUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    changes = payload.model_dump(exclude_unset=True)
    if changes.get("full_name") is not None:
        user.full_name = changes["full_name"]
    if changes.get("avatar_tone") is not None:
        user.avatar_tone = changes["avatar_tone"]
    if "phone" in changes:
        user.phone = changes["phone"]
    previous_avatar = user.avatar_media_id
    if "avatar" in changes:
        if changes["avatar"] is None:
            user.avatar_media_id = None
        else:
            try:
                (media,) = resolve_keys(db, [changes["avatar"]], allowed_owner=user.id)
            except UnknownPhotos:
                raise HTTPException(
                    status_code=422, detail="That photo couldn't be found. Please upload it again."
                ) from None
            user.avatar_media_id = media.id
    db.flush()
    if previous_avatar is not None and previous_avatar != user.avatar_media_id:
        delete_if_unused(db, {previous_avatar})
    db.commit()
    db.refresh(user)
    return user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    payload: DeleteAccountRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Permanently delete the account and everything in it (SRS FR-32)."""
    if user.hashed_password is not None and not verify_password(
        payload.password or "", user.hashed_password
    ):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Incorrect password")
    user_id = user.id
    delete_account(db, user)
    background_tasks.add_task(manager.disconnect, user_id, CLOSE_UNAUTHORIZED)


@router.post("/me/privacy-consent", response_model=UserOut)
def agree_to_privacy_policy(
    payload: PrivacyConsentRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    """Record that the user agreed to the current privacy policy (SRS FR-31)."""
    require_current_privacy_policy(payload.policy_version)
    user.record_privacy_consent()
    db.commit()
    db.refresh(user)
    return user


@router.put("/me/interests", response_model=UserOut)
def set_interests(
    payload: InterestsUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    user.interests = payload.interests
    db.commit()
    db.refresh(user)
    return user


# ─────────────── saved lists ───────────────
def _serialize_list(sl: SavedList) -> SavedListOut:
    return SavedListOut(
        id=sl.id,
        name=sl.name,
        tone=sl.tone,
        count=len(sl.items),
        businesses=[to_card(item.business) for item in sl.items if item.business],
    )


@router.get("/me/saved", response_model=list[SavedListOut])
def my_saved_lists(
    user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[SavedListOut]:
    lists = db.execute(
        select(SavedList).where(SavedList.user_id == user.id).order_by(SavedList.created_at)
    ).scalars().all()
    return [_serialize_list(sl) for sl in lists]


@router.post("/me/saved", response_model=SavedListOut, status_code=status.HTTP_201_CREATED)
def create_saved_list(
    payload: SavedListCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SavedListOut:
    sl = SavedList(user_id=user.id, name=payload.name, tone=payload.tone)
    db.add(sl)
    db.commit()
    db.refresh(sl)
    return _serialize_list(sl)


@router.delete("/me/saved/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_list(
    list_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    sl = db.get(SavedList, list_id)
    if sl is None or sl.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="List not found")
    db.delete(sl)
    db.commit()
