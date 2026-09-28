"""Who gets notified about what (SRS FR-21, UC-15, BR-14).

`notify()` checks each recipient's settings, adds the Notifications-list rows (in the
caller's transaction) and returns a `PushJob` for the endpoint to run as a background task
after committing, so sending never slows down the response.
"""
from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime
from urllib.parse import quote

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.database import session_scope
from app.models.business import BusinessProfile
from app.models.engagement import SavedBusiness, SavedList
from app.models.notification import DeviceToken, Notification, NotificationKind
from app.models.user import User
from app.schemas.notification import NotificationPrefs
from app.services import push

# Which setting (NotificationPrefs field) covers each kind.
PREF_FOR_KIND = {
    NotificationKind.message: "messages",
    NotificationKind.review: "reviews",
    NotificationKind.review_reply: "reviews",
    NotificationKind.offer: "offers",
    NotificationKind.new_business: "new_places",
    NotificationKind.trending: "trending",
}


def preferences(user: User) -> NotificationPrefs:
    stored = user.notification_prefs or {}
    return NotificationPrefs(**{k: v for k, v in stored.items() if k in NotificationPrefs.model_fields})


def wants(user: User, kind: NotificationKind) -> bool:
    return getattr(preferences(user), PREF_FOR_KIND[kind])


def snippet(text: str, limit: int = 90) -> str:
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def business_route(b: BusinessProfile) -> str:
    return f"/business/{b.id}"


def reviews_route(b: BusinessProfile) -> str:
    return f"/business/{b.id}/reviews?name={quote(b.name)}"


@dataclass
class PushJob:
    """Sends one message to some devices, then forgets tokens FCM says are dead."""

    tokens: list[str]
    message: push.PushMessage

    def __call__(self) -> None:
        result = push.get_sender().send(self.tokens, self.message)
        if result.invalid:
            with session_scope() as db:
                db.execute(delete(DeviceToken).where(DeviceToken.token.in_(result.invalid)))
                db.commit()


def notify(
    db: Session,
    recipients: Iterable[User],
    kind: NotificationKind,
    title: str,
    body: str,
    route: str,
    *,
    tag: str | None = None,
    store: bool = True,
    now: datetime | None = None,
) -> PushJob | None:
    """Queue a notification for `recipients` who haven't turned this kind off.

    Chat messages (`kind=message`) are pushed only: the Chat tab is their list.
    The caller commits, then runs the returned job (if any) in the background.
    """
    users = {u.id: u for u in recipients if u is not None and wants(u, kind)}
    if not users:
        return None
    if store and kind != NotificationKind.message:
        db.add_all(
            Notification(user_id=uid, kind=kind, title=title, body=body, route=route,
                         **({"created_at": now} if now else {}))
            for uid in users
        )
    tokens = list(db.scalars(select(DeviceToken.token).where(DeviceToken.user_id.in_(users))))
    if not tokens:
        return None
    data = {"route": route, "kind": kind.value}
    return PushJob(tokens, push.PushMessage(title=title, body=body, data=data, tag=tag))


# ─────────────── recipients for the Module 3 triggers ───────────────
def users_who_saved(db: Session, business: BusinessProfile) -> list[User]:
    """People who saved the business, except its owner (new-offer alerts)."""
    return list(db.scalars(
        select(User).join(SavedList, SavedList.user_id == User.id)
        .join(SavedBusiness, SavedBusiness.list_id == SavedList.id)
        .where(SavedBusiness.business_id == business.id, User.id != business.owner_id)
        .distinct()
    ))


def users_interested_in(db: Session, business: BusinessProfile) -> list[User]:
    """People whose interests include the business's category, except its owner."""
    if business.category is None:
        return []
    slug = business.category.slug
    return [
        u for u in db.scalars(select(User).where(User.id != business.owner_id))
        if slug in (u.interests or [])
    ]
