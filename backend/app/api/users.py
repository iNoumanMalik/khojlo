from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.engagement import SavedBusiness, SavedList
from app.models.user import User
from app.schemas.saved import SavedListCreate, SavedListOut
from app.schemas.user import InterestsUpdate, UserOut, UserUpdate
from app.services.business_service import to_card

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
    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.avatar_tone is not None:
        user.avatar_tone = payload.avatar_tone
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
