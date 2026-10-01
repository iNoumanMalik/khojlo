"""Module 8 — moderation actions, the audit log and account status (SRS FR-15, SEC-3;
SDD Algorithm 10 "Remove content / Keep content").

Every action here:
* changes the content or account,
* writes a `ModerationAction` (who, what, why), and
* tells the people affected, with a notification that can't be switched off.

Functions add rows to the caller's session and return jobs (push sends, emails) for the
endpoint to run in the background after it commits, like `notification_service.notify`.
"""
from __future__ import annotations

from collections.abc import Callable, Iterable
from datetime import datetime, timedelta, timezone
from typing import Literal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile, Offer
from app.models.campaign import Campaign
from app.models.chat import Conversation
from app.models.moderation import (
    REASON_LABELS,
    ActionKind,
    ModerationAction,
    ModerationReason,
)
from app.models.notification import NotificationKind
from app.models.review import Review
from app.models.user import User, UserRole
from app.services import email_service
from app.services import notification_service as ns
from app.services import review_service as rs
from app.services.hours import to_local

Job = Callable[[], None]
AccountAction = Literal["none", "warn", "suspend", "ban", "lift"]

GUIDELINES_ROUTE = "/guidelines"


class ModerationError(ValueError):
    """The action isn't allowed; the message is shown to the admin."""


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def aware(dt: datetime | None) -> datetime | None:
    if dt is not None and dt.tzinfo is None:  # SQLite returns naive datetimes
        return dt.replace(tzinfo=timezone.utc)
    return dt


def reason_label(reason: ModerationReason | str | None) -> str:
    try:
        return REASON_LABELS[ModerationReason(reason)]
    except ValueError:
        return REASON_LABELS[ModerationReason.other]


# ─────────────── account status (enforced in api/deps.py and at sign-in) ───────────────
def account_status(user: User, now: datetime | None = None
                   ) -> Literal["active", "suspended", "banned"]:
    if user.is_banned:
        return "banned"
    until = aware(user.suspended_until)
    if until is not None and until > (now or now_utc()):
        return "suspended"
    return "active"


def account_block(user: User, now: datetime | None = None) -> str | None:
    """Why this account can't use Khojlo right now, or None if it can."""
    status = account_status(user, now)
    if status == "banned":
        return ("This account has been banned for breaking Khojlo’s Community Guidelines "
                f"({reason_label(user.suspension_reason).lower()}).")
    if status == "suspended":
        until = to_local(aware(user.suspended_until))
        return (f"Your account is suspended until {until:%d %b %Y, %H:%M} for breaking "
                f"Khojlo’s Community Guidelines ({reason_label(user.suspension_reason).lower()}).")
    return None


# ─────────────── audit log and notices ───────────────
def log_action(
    db: Session,
    *,
    admin: User | None,
    action: ActionKind,
    target_type: str,
    target_id: int,
    subject_user_id: int | None = None,
    reason: ModerationReason | None = None,
    note: str = "",
    now: datetime | None = None,
) -> ModerationAction:
    entry = ModerationAction(
        admin_id=admin.id if admin else None, action=action, target_type=target_type,
        target_id=target_id, subject_user_id=subject_user_id, reason=reason,
        note=(note or "").strip()[:1000], created_at=now or now_utc(),
    )
    db.add(entry)
    return entry


def notice(db: Session, user: User | None, kind: NotificationKind, title: str, body: str,
           route: str = GUIDELINES_ROUTE, *, now: datetime | None = None) -> Job | None:
    if user is None:
        return None
    return ns.notify(db, [user], kind, title=title, body=body, route=route, now=now)


def _email(user: User, subject: str, heading: str, body: str) -> Job:
    return lambda: email_service.send_account_notice(
        to=user.email, subject=subject, heading=heading, body=body)


def _jobs(*jobs: Job | None) -> list[Job]:
    return [j for j in jobs if j is not None]


def tell_reporters(db: Session, reporters: Iterable[User], *, upheld: bool, what: str,
                   now: datetime | None = None) -> list[Job]:
    """Close the loop with the people who reported something (plan item 5)."""
    body = (f"We reviewed the {what} you reported and took action. Thanks for helping keep "
            "Khojlo safe." if upheld else
            f"We reviewed the {what} you reported. It doesn’t break our Community "
            "Guidelines, so it stays up. Thanks for letting us know.")
    return _jobs(*(notice(db, u, NotificationKind.account, "Thanks for your report", body,
                          now=now) for u in {u.id: u for u in reporters}.values()))


# ─────────────── content ───────────────
def hide_review(db: Session, admin: User, review: Review, reason: ModerationReason,
                note: str = "", *, now: datetime | None = None) -> list[Job]:
    """Algorithm 10 "Remove content": hidden from lists and the rating (Algorithm 7)."""
    if not review.is_approved:
        return []
    review.is_approved = False
    rs.refresh_rating(db, review.business)
    log_action(db, admin=admin, action=ActionKind.remove_review, target_type="review",
               target_id=review.id, subject_user_id=review.user_id, reason=reason, note=note,
               now=now)
    return _jobs(notice(
        db, review.author, NotificationKind.account, "Your review was removed",
        f"Your review of {review.business.name} was removed: {reason_label(reason).lower()}. "
        "Tap to read the Community Guidelines.", now=now))


def close_conversation(db: Session, admin: User, conversation: Conversation,
                       reason: ModerationReason, note: str = "", *,
                       now: datetime | None = None) -> list[Job]:
    if conversation.closed_at is not None:
        return []
    now = now or now_utc()
    conversation.closed_at = now
    log_action(db, admin=admin, action=ActionKind.close_conversation,
               target_type="conversation", target_id=conversation.id, reason=reason,
               note=note, now=now)
    body = (f"Khojlo’s moderators closed the conversation about {conversation.business.name} "
            f"after a report ({reason_label(reason).lower()}). You can still read it.")
    route = f"/conversations/{conversation.id}"
    return _jobs(
        notice(db, conversation.customer, NotificationKind.account, "A conversation was closed",
               body, route, now=now),
        notice(db, conversation.business.owner, NotificationKind.account,
               "A conversation was closed", body, route, now=now),
    )


def deactivate_offer(db: Session, admin: User, offer: Offer, reason: ModerationReason,
                     note: str = "", *, now: datetime | None = None) -> list[Job]:
    offer.is_active = False
    b = offer.business
    log_action(db, admin=admin, action=ActionKind.deactivate_offer, target_type="offer",
               target_id=offer.id, subject_user_id=b.owner_id, reason=reason, note=note,
               now=now)
    return _jobs(notice(
        db, b.owner, NotificationKind.account, "An offer was switched off",
        f"Khojlo’s moderators switched off “{offer.title}” at {b.name}: "
        f"{reason_label(reason).lower()}. Edit it before switching it on again.",
        f"/offers/{b.id}", now=now))


def unpublish_campaign(db: Session, admin: User, campaign: Campaign, reason: ModerationReason,
                       note: str = "", *, now: datetime | None = None) -> list[Job]:
    campaign.is_published = False
    b = campaign.business
    log_action(db, admin=admin, action=ActionKind.unpublish_campaign, target_type="campaign",
               target_id=campaign.id, subject_user_id=b.owner_id, reason=reason, note=note,
               now=now)
    return _jobs(notice(
        db, b.owner, NotificationKind.account, "A campaign was unpublished",
        f"Khojlo’s moderators unpublished “{campaign.name}” at {b.name}: "
        f"{reason_label(reason).lower()}. Edit it before publishing it again.",
        f"/offers/{b.id}", now=now))


def suspend_business(db: Session, admin: User | None, b: BusinessProfile,
                     reason: ModerationReason, note: str = "", *,
                     now: datetime | None = None) -> list[Job]:
    """Take a listing down: unpublished, and the owner can't republish it (decision 1:
    publish first, suspend bad listings)."""
    if b.suspended_at is not None:
        return []
    now = now or now_utc()
    b.suspended_at, b.suspension_reason, b.is_published = now, reason.value, False
    log_action(db, admin=admin, action=ActionKind.suspend_business, target_type="business",
               target_id=b.id, subject_user_id=b.owner_id, reason=reason, note=note, now=now)
    return _jobs(notice(
        db, b.owner, NotificationKind.account, f"{b.name} has been suspended",
        f"Khojlo’s moderators took {b.name} off Khojlo: {reason_label(reason).lower()}. "
        "It stays hidden until they reinstate it.", "/business", now=now))


def reinstate_business(db: Session, admin: User, b: BusinessProfile, note: str = "", *,
                       now: datetime | None = None) -> list[Job]:
    if b.suspended_at is None:
        return []
    b.suspended_at, b.suspension_reason, b.is_published = None, None, True
    log_action(db, admin=admin, action=ActionKind.reinstate_business, target_type="business",
               target_id=b.id, subject_user_id=b.owner_id, note=note, now=now)
    return _jobs(notice(
        db, b.owner, NotificationKind.account, f"{b.name} is back on Khojlo",
        f"Khojlo’s moderators reinstated {b.name}. Customers can find it again.",
        "/business", now=now))


# ─────────────── accounts ───────────────
def act_on_user(
    db: Session,
    admin: User,
    user: User,
    action: AccountAction,
    reason: ModerationReason = ModerationReason.other,
    note: str = "",
    *,
    days: int = 7,
    hide_reviews: bool = False,
    now: datetime | None = None,
) -> list[Job]:
    """Warn, suspend for `days`, ban, or lift a suspension or ban."""
    if action == "none":
        return []
    if user.id == admin.id:
        raise ModerationError("You can’t take action on your own account.")
    if user.role == UserRole.admin:
        raise ModerationError("Admin accounts can’t be warned, suspended or banned here.")
    now = now or now_utc()
    label = reason_label(reason)
    if action == "warn":
        log_action(db, admin=admin, action=ActionKind.warn_user, target_type="user",
                   target_id=user.id, subject_user_id=user.id, reason=reason, note=note, now=now)
        return _jobs(notice(
            db, user, NotificationKind.account, "A warning from Khojlo",
            f"{label}. Please read the Community Guidelines: breaking them again can get "
            "your account suspended.", now=now))
    if action == "suspend":
        user.suspended_until = now + timedelta(days=days)
        user.suspension_reason = reason.value
        log_action(db, admin=admin, action=ActionKind.suspend_user, target_type="user",
                   target_id=user.id, subject_user_id=user.id, reason=reason,
                   note=f"{days} day{'s' if days != 1 else ''}. {note}".strip(), now=now)
        until = to_local(user.suspended_until)
        body = (f"Your Khojlo account is suspended until {until:%d %b %Y} for breaking the "
                f"Community Guidelines ({label.lower()}).")
        return _jobs(
            notice(db, user, NotificationKind.account, "Your account is suspended", body,
                   now=now),
            _email(user, "Your Khojlo account is suspended", "Your account is suspended", body),
        )
    if action == "ban":
        user.is_banned, user.suspended_until = True, None
        user.suspension_reason = reason.value
        jobs: list[Job] = []
        for b in list(user.businesses):
            jobs += suspend_business(db, admin, b, reason, "The owner’s account was banned.",
                                     now=now)
        hidden = 0
        if hide_reviews:
            for review in db.scalars(select(Review).where(
                    Review.user_id == user.id, Review.deleted_at.is_(None),
                    Review.is_approved.is_(True))):
                review.is_approved = False
                rs.refresh_rating(db, review.business)
                hidden += 1
        extra = f" Hid {hidden} review{'s' if hidden != 1 else ''}." if hidden else ""
        log_action(db, admin=admin, action=ActionKind.ban_user, target_type="user",
                   target_id=user.id, subject_user_id=user.id, reason=reason,
                   note=(note + extra).strip(), now=now)
        body = (f"Your Khojlo account has been banned for breaking the Community Guidelines "
                f"({label.lower()}).")
        return jobs + _jobs(_email(user, "Your Khojlo account has been banned",
                                   "Your account has been banned", body))
    if action == "lift":
        if account_status(user, now) == "active":
            raise ModerationError("This account isn’t suspended or banned.")
        user.is_banned, user.suspended_until, user.suspension_reason = False, None, None
        log_action(db, admin=admin, action=ActionKind.lift_suspension, target_type="user",
                   target_id=user.id, subject_user_id=user.id, note=note, now=now)
        body = "Your Khojlo account is active again. Welcome back."
        return _jobs(
            notice(db, user, NotificationKind.account, "Your account is active again", body,
                   "/home", now=now),
            _email(user, "Your Khojlo account is active again", "Welcome back", body),
        )
    raise ModerationError(f"Unknown action “{action}”.")
