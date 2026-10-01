"""Module 8 — automatic business verification (SRS FR-14 and UC-12 as reworded on
30 Sep 2026; SDD Algorithm 9).

Businesses are listed as soon as they're published. The Verified badge is given by the
system when a business passes every check, so no admin has to approve each one by hand.
Admins only see the businesses the checks refer to them, and can revoke a badge.

The checks:
1. **email**: the owner verified their email address;
2. **profile**: the listing is complete (category, description, address, map pin, phone,
   a photo and opening hours);
3. **storefront**: the owner took a photo of the shop front or signboard in the app;
4. **record**: no open report or automatic flag, and no report an admin upheld.

Passing 1–3 with a problem in 4 refers the business to an admin (`pending_review`).
Changing the name or location of a verified business removes the badge until a new
storefront photo is taken (SDD Algorithm 5 "IF verification required").
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile
from app.models.media import Media
from app.models.moderation import (
    ActionKind,
    BusinessReport,
    BusinessReportStatus,
    FlagStatus,
    FlagTarget,
    ModerationFlag,
    VerificationStatus,
)
from app.models.notification import NotificationKind
from app.models.user import User
from app.services.media_service import delete_if_unused
from app.services.moderation_service import (
    Job,
    ModerationError,
    log_action,
    notice,
    now_utc,
)

MIN_DESCRIPTION = 30
Decision = Literal["approve", "reject", "request_info", "revoke"]

# Statuses an admin owns: the automatic checks leave them alone.
_ADMIN_STATUSES = {VerificationStatus.pending_review, VerificationStatus.needs_info,
                   VerificationStatus.rejected}


@dataclass(frozen=True)
class Check:
    key: str
    label: str
    passed: bool
    hint: str = ""


def verification_route(b: BusinessProfile) -> str:
    return f"/verification/{b.id}"


def profile_gaps(b: BusinessProfile) -> list[str]:
    """What the listing still needs before it can be verified."""
    gaps = []
    if b.category_id is None:
        gaps.append("a category")
    if len((b.description or "").strip()) < MIN_DESCRIPTION:
        gaps.append(f"a description ({MIN_DESCRIPTION}+ characters)")
    if not (b.address or "").strip():
        gaps.append("an address")
    if b.latitude is None or b.longitude is None:
        gaps.append("a map pin")
    if not b.phone:
        gaps.append("a phone number")
    if not b.photos:
        gaps.append("a photo")
    if not any(not h.is_closed for h in b.hours):
        gaps.append("opening hours")
    return gaps


def open_flag_count(db: Session, b: BusinessProfile) -> int:
    """Open flags the business is responsible for: on the listing, its offers and
    campaigns, and its owner's account. Flags on reviews *of* it don't count."""
    return db.scalar(select(func.count(ModerationFlag.id)).where(
        ModerationFlag.status == FlagStatus.open,
        or_(
            (ModerationFlag.business_id == b.id)
            & ModerationFlag.target_type.in_([FlagTarget.business, FlagTarget.offer,
                                              FlagTarget.campaign]),
            (ModerationFlag.target_type == FlagTarget.user)
            & (ModerationFlag.target_id == b.owner_id),
        ),
    )) or 0


def report_count(db: Session, b: BusinessProfile, status: BusinessReportStatus) -> int:
    return db.scalar(select(func.count(BusinessReport.id)).where(
        BusinessReport.business_id == b.id, BusinessReport.status == status)) or 0


def has_record_problem(db: Session, b: BusinessProfile) -> bool:
    return bool(open_flag_count(db, b)
                or report_count(db, b, BusinessReportStatus.open)
                or report_count(db, b, BusinessReportStatus.actioned))


def checks(db: Session, b: BusinessProfile) -> list[Check]:
    gaps = profile_gaps(b)
    return [
        Check("email", "Email verified", bool(b.owner.is_verified),
              "Verify your email address from your profile."),
        Check("profile", "Listing complete", not gaps,
              ("Add " + ", ".join(gaps) + ".") if gaps else ""),
        Check("storefront", "Storefront photo taken", b.storefront_media_id is not None,
              "Take a photo of your shop front or signboard, with the name showing."),
        Check("record", "No open reports", not has_record_problem(db, b),
              "Khojlo’s team is looking at a report about this business."),
    ]


def _set_status(b: BusinessProfile, status: VerificationStatus, *, by: User | None = None,
                note: str | None = None, now: datetime) -> None:
    b.verification_status = status
    b.is_verified = status == VerificationStatus.verified
    if status == VerificationStatus.verified:
        b.verified_at, b.verified_by_id = now, by.id if by else None
    if note is not None:
        b.verification_note = note.strip()[:500]


def refresh(db: Session, b: BusinessProfile, *, now: datetime | None = None) -> list[Job]:
    """Re-run the checks after something changed; verify or refer when they allow it.

    Only an unverified business moves. A verified one keeps its badge (admins revoke it),
    and the review statuses wait for an admin or the owner.
    """
    if b.suspended_at is not None or b.verification_status != VerificationStatus.unverified:
        return []
    now = now or now_utc()
    db.flush()
    passed = {c.key: c.passed for c in checks(db, b)}
    if all(passed.values()):
        _set_status(b, VerificationStatus.verified, note="", now=now)
        log_action(db, admin=None, action=ActionKind.auto_verify, target_type="business",
                   target_id=b.id, subject_user_id=b.owner_id,
                   note="Passed the automatic checks.", now=now)
        job = notice(db, b.owner, NotificationKind.verification, f"{b.name} is verified",
                     "Your listing passed Khojlo’s checks and now shows the Verified badge.",
                     verification_route(b), now=now)
        return [job] if job else []
    if passed["email"] and passed["profile"] and passed["storefront"]:
        _set_status(b, VerificationStatus.pending_review, now=now)
        log_action(db, admin=None, action=ActionKind.refer, target_type="business",
                   target_id=b.id, subject_user_id=b.owner_id,
                   note="The checks passed, but a report or flag needs a person to look.",
                   now=now)
        job = notice(db, b.owner, NotificationKind.verification,
                     f"We’re taking a closer look at {b.name}",
                     "Khojlo’s team will review your listing before it gets the Verified "
                     "badge. You don’t need to do anything.", verification_route(b), now=now)
        return [job] if job else []
    return []


def identity_changed(db: Session, b: BusinessProfile, *, now: datetime | None = None
                     ) -> list[Job]:
    """The name or location changed: the storefront photo no longer proves it, so a new
    one is needed. A verified business loses the badge until then."""
    if b.storefront_media_id is None:
        return []
    now = now or now_utc()
    old = {b.storefront_media_id}
    b.storefront_media_id, b.storefront_at = None, None
    db.flush()
    delete_if_unused(db, old)
    if b.verification_status != VerificationStatus.verified:
        return []
    _set_status(b, VerificationStatus.unverified, now=now)
    log_action(db, admin=None, action=ActionKind.unverify, target_type="business",
               target_id=b.id, subject_user_id=b.owner_id,
               note="The name or location changed; a new storefront photo is needed.", now=now)
    job = notice(db, b.owner, NotificationKind.verification,
                 "Take a new storefront photo to keep your badge",
                 f"You changed {b.name}’s name or location, so Khojlo needs a new photo of "
                 "your shop front before showing the Verified badge again.",
                 verification_route(b), now=now)
    return [job] if job else []


def set_storefront(db: Session, b: BusinessProfile, media: Media, *,
                   now: datetime | None = None) -> list[Job]:
    now = now or now_utc()
    old = {b.storefront_media_id} - {None, media.id}
    b.storefront_media_id, b.storefront_at = media.id, now
    db.flush()
    delete_if_unused(db, old)
    db.expire(b, ["storefront"])
    return refresh(db, b, now=now)


def request_review(db: Session, b: BusinessProfile, note: str = "", *,
                   now: datetime | None = None) -> list[Job]:
    """The owner answers "Request more info", or asks again after a rejection."""
    if b.verification_status not in (VerificationStatus.needs_info,
                                     VerificationStatus.rejected):
        raise ModerationError("Khojlo isn’t waiting for anything from you right now.")
    if b.storefront_media_id is None:
        raise ModerationError("Take a storefront photo first.")
    now = now or now_utc()
    _set_status(b, VerificationStatus.pending_review, now=now)
    log_action(db, admin=None, action=ActionKind.review_requested, target_type="business",
               target_id=b.id, subject_user_id=b.owner_id, note=note, now=now)
    return []


def decide(db: Session, admin: User, b: BusinessProfile, decision: Decision, note: str = "",
           *, now: datetime | None = None) -> list[Job]:
    """An admin's verification decision (Algorithm 9: Verified or Rejected, then notify)."""
    now = now or now_utc()
    note = (note or "").strip()
    if decision in ("reject", "request_info", "revoke") and not note:
        raise ModerationError("Tell the owner why, so they know what to fix.")
    if decision == "approve":
        _set_status(b, VerificationStatus.verified, by=admin, note="", now=now)
        action, title = ActionKind.approve, f"{b.name} is verified"
        body = "Khojlo’s team reviewed your listing. It now shows the Verified badge."
    elif decision == "reject":
        _set_status(b, VerificationStatus.rejected, note=note, now=now)
        action, title = ActionKind.reject, f"{b.name} wasn’t verified"
        body = f"Khojlo’s team couldn’t verify your listing: {note}"
    elif decision == "request_info":
        _set_status(b, VerificationStatus.needs_info, note=note, now=now)
        action, title = ActionKind.request_info, f"Khojlo needs more about {b.name}"
        body = note
    elif decision == "revoke":
        if b.verification_status != VerificationStatus.verified:
            raise ModerationError("Only a verified business can have its badge revoked.")
        _set_status(b, VerificationStatus.rejected, note=note, now=now)
        action, title = ActionKind.revoke, f"{b.name}’s Verified badge was removed"
        body = f"Khojlo’s team removed the badge: {note}"
    else:
        raise ModerationError(f"Unknown decision “{decision}”.")
    log_action(db, admin=admin, action=action, target_type="business", target_id=b.id,
               subject_user_id=b.owner_id, note=note, now=now)
    job = notice(db, b.owner, NotificationKind.verification, title, body,
                 verification_route(b), now=now)
    return [job] if job else []
