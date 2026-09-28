"""Push notification devices, the Notifications list and settings (SRS FR-21, UC-15, BR-14)."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.notification import DeviceToken, Notification
from app.models.user import User
from app.schemas.notification import (
    DeviceIn,
    DeviceUnregisterIn,
    MarkReadIn,
    NotificationOut,
    NotificationPage,
    NotificationPrefs,
    UnreadCountOut,
)
from app.services.notification_service import preferences

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _out(n: Notification) -> NotificationOut:
    return NotificationOut(id=n.id, kind=n.kind, title=n.title, body=n.body, route=n.route,
                           is_read=n.read_at is not None, created_at=n.created_at)


def _unread(db: Session, user_id: int) -> int:
    return db.scalar(select(func.count(Notification.id)).where(
        Notification.user_id == user_id, Notification.read_at.is_(None))) or 0


# ─────────────── devices ───────────────
@router.put("/devices", status_code=status.HTTP_204_NO_CONTENT, response_class=Response,
            summary="Register this device for push notifications")
def register_device(
    payload: DeviceIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """Called whenever the app gets its FCM token. A device that signs in as someone else
    moves to that account, so pushes never reach the previous user."""
    device = db.scalar(select(DeviceToken).where(DeviceToken.token == payload.token))
    if device is None:
        db.add(DeviceToken(user_id=user.id, token=payload.token, platform=payload.platform))
    else:
        device.user_id = user.id
        device.platform = payload.platform
        device.last_seen_at = _now()
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/devices/unregister", status_code=status.HTTP_204_NO_CONTENT,
             response_class=Response, summary="Stop push notifications to this device")
def unregister_device(
    payload: DeviceUnregisterIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    """Called on logout."""
    device = db.scalar(select(DeviceToken).where(
        DeviceToken.token == payload.token, DeviceToken.user_id == user.id))
    if device is not None:
        db.delete(device)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ─────────────── the Notifications list ───────────────
@router.get("", response_model=NotificationPage, summary="My notifications, newest first")
def list_notifications(
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationPage:
    base = select(Notification).where(Notification.user_id == user.id)
    total = db.scalar(select(func.count()).select_from(base.subquery())) or 0
    rows = db.scalars(base.order_by(Notification.created_at.desc(), Notification.id.desc())
                      .limit(limit).offset(offset))
    return NotificationPage(items=[_out(n) for n in rows], total=total,
                            unread=_unread(db, user.id))


@router.get("/unread-count", response_model=UnreadCountOut, summary="Unread notifications")
def unread_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UnreadCountOut:
    return UnreadCountOut(total=_unread(db, user.id))


@router.post("/read", response_model=UnreadCountOut, summary="Mark notifications read")
def mark_read(
    payload: MarkReadIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UnreadCountOut:
    query = update(Notification).where(Notification.user_id == user.id,
                                       Notification.read_at.is_(None))
    if payload.ids is not None:
        query = query.where(Notification.id.in_(payload.ids))
    db.execute(query.values(read_at=_now()).execution_options(synchronize_session=False))
    db.commit()
    return UnreadCountOut(total=_unread(db, user.id))


# ─────────────── settings (BR-14) ───────────────
@router.get("/preferences", response_model=NotificationPrefs, summary="My notification settings")
def get_preferences(user: User = Depends(get_current_user)) -> NotificationPrefs:
    return preferences(user)


@router.put("/preferences", response_model=NotificationPrefs,
            summary="Change my notification settings")
def set_preferences(
    payload: NotificationPrefs,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationPrefs:
    user.notification_prefs = payload.model_dump()
    db.commit()
    return preferences(user)
