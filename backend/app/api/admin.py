"""Module 8 — the admin panel API (SRS FR-14, FR-15, FR-19, UC-12, SEC-3; SDD Admin
`verifyBusiness()` / `moderateContent()`, Algorithms 9 and 10).

Every endpoint needs an admin account. Every change is written to the audit log and
the people affected are told.

* **Overview**: queue sizes, today's numbers, 14-day activity and the latest actions.
* **Businesses**: verification queue (businesses the automatic checks referred),
  recently auto-verified ones to spot-check, decisions, suspension.
* **Reports**: what users reported (reviews, conversations, businesses), grouped per item;
  uphold (remove the content) or dismiss (keep it), optionally acting on the account.
* **Flags**: what the automatic rules noticed; uphold or dismiss the same way.
* **Users**: find accounts; warn, suspend, ban or lift.
* **Activity**: the audit log.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_admin
from app.core.database import get_db
from app.models.business import BusinessProfile, Offer
from app.models.campaign import Campaign
from app.models.chat import (
    Conversation,
    ConversationReport,
    ConversationReportReason,
    ConversationReportStatus,
    Message,
)
from app.models.moderation import (
    ActionKind,
    BusinessReport,
    BusinessReportReason,
    BusinessReportStatus,
    FlagStatus,
    FlagTarget,
    ModerationAction,
    ModerationFlag,
    VerificationStatus,
)
from app.models.review import ReportReason, ReportStatus, Review, ReviewReport
from app.models.user import User, UserRole
from app.schemas.admin import (
    ActionOut,
    ActionPage,
    AdminBusinessBrief,
    AdminBusinessDetail,
    AdminBusinessRow,
    AdminConversation,
    AdminMessage,
    AdminPerson,
    AdminReview,
    AdminUserDetail,
    AdminUserRow,
    BusinessPage,
    DayCount,
    FlagOut,
    FlagPage,
    NoteIn,
    OverviewOut,
    ReportDetail,
    ReportEntry,
    ReportItem,
    ReportKind,
    ReportPage,
    ResolveIn,
    SuspendIn,
    UserActionIn,
    UserPage,
    VerificationDecisionIn,
)
from app.schemas.moderation import CheckOut
from app.services import moderation_service as ms
from app.services import verification_service as vs
from app.services.business_service import photo_out
from app.services.hours import to_local
from app.services.review_service import display_name

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(get_current_admin)])

RECENT_DAYS = 7
CHART_DAYS = 14
MAX_MESSAGES = 500

ACTION_LABELS = {
    ActionKind.auto_verify: "Verified automatically",
    ActionKind.refer: "Referred for review",
    ActionKind.unverify: "Removed the badge (name or location changed)",
    ActionKind.approve: "Verified a business",
    ActionKind.reject: "Declined verification",
    ActionKind.request_info: "Asked the owner for more",
    ActionKind.revoke: "Revoked a Verified badge",
    ActionKind.review_requested: "Owner asked for another look",
    ActionKind.remove_review: "Removed a review",
    ActionKind.close_conversation: "Closed a conversation",
    ActionKind.deactivate_offer: "Switched off an offer",
    ActionKind.unpublish_campaign: "Unpublished a campaign",
    ActionKind.suspend_business: "Suspended a business",
    ActionKind.reinstate_business: "Reinstated a business",
    ActionKind.dismiss_report: "Dismissed a report",
    ActionKind.dismiss_flag: "Dismissed a flag",
    ActionKind.warn_user: "Warned an account",
    ActionKind.suspend_user: "Suspended an account",
    ActionKind.ban_user: "Banned an account",
    ActionKind.lift_suspension: "Lifted a suspension or ban",
}

REVIEW_REASON_LABELS = {
    ReportReason.spam: "Spam or advertising",
    ReportReason.fake: "Fake — not a real visit",
    ReportReason.offensive: "Offensive or abusive",
    ReportReason.other: "Something else",
}
CONVERSATION_REASON_LABELS = {
    ConversationReportReason.spam: "Spam or advertising",
    ConversationReportReason.harassment: "Harassment or abuse",
    ConversationReportReason.scam: "A scam or fraud",
    ConversationReportReason.other: "Something else",
}
BUSINESS_REASON_LABELS = {
    BusinessReportReason.scam: "A scam or fraud",
    BusinessReportReason.prohibited: "Adult content or prohibited items",
    BusinessReportReason.fake: "Not a real business",
    BusinessReportReason.wrong_info: "Wrong information",
    BusinessReportReason.offensive: "Offensive content",
    BusinessReportReason.other: "Something else",
}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _run(background_tasks: BackgroundTasks, jobs) -> None:
    for job in jobs:
        if job is not None:
            background_tasks.add_task(job)


def _not_found(what: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{what} not found")


def _refused(exc: ms.ModerationError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


# ─────────────── presentation ───────────────
def person_out(user: User, now: datetime | None = None) -> AdminPerson:
    state = ms.account_status(user, now)
    return AdminPerson(
        id=user.id, full_name=user.full_name, email=user.email, role=user.role,
        initials=user.initials, tone=user.avatar_tone, avatar=photo_out(user.avatar),
        email_verified=bool(user.is_verified), status=state,
        suspended_until=ms.aware(user.suspended_until) if state == "suspended" else None,
        suspension_reason=ms.reason_label(user.suspension_reason) if state != "active" else None,
        created_at=user.created_at,
    )


def business_brief(b: BusinessProfile) -> AdminBusinessBrief:
    return AdminBusinessBrief(
        id=b.id, name=b.name, tone=b.tone, cover=photo_out(b.cover),
        category_label=b.category_label, address=b.address or "", owner_id=b.owner_id,
        owner_name=b.owner.full_name if b.owner else "",
        verification_status=b.verification_status, is_verified=b.is_verified,
        is_published=b.is_published, is_suspended=b.suspended_at is not None,
        suspension_reason=ms.reason_label(b.suspension_reason) if b.suspended_at else None,
        rating=b.rating or 0, review_count=b.review_count or 0, created_at=b.created_at,
        verified_at=b.verified_at,
        auto_verified=b.is_verified and b.verified_at is not None and b.verified_by_id is None,
        storefront=photo_out(b.storefront),
    )


def _open_business_reports(db: Session, business_id: int) -> int:
    return db.scalar(select(func.count(BusinessReport.id)).where(
        BusinessReport.business_id == business_id,
        BusinessReport.status == BusinessReportStatus.open)) or 0


def business_row(db: Session, b: BusinessProfile) -> AdminBusinessRow:
    return AdminBusinessRow(**business_brief(b).model_dump(),
                            open_reports=_open_business_reports(db, b.id),
                            open_flags=vs.open_flag_count(db, b))


class _Titles:
    """Human names for audit-log and flag targets, looked up once per request."""

    def __init__(self, db: Session):
        self.db = db
        self._cache: dict[tuple[str, int], str | None] = {}

    def __call__(self, target_type: str, target_id: int) -> str | None:
        key = (str(target_type), target_id)
        if key not in self._cache:
            self._cache[key] = self._lookup(*key)
        return self._cache[key]

    def _lookup(self, target_type: str, target_id: int) -> str | None:
        db = self.db
        if target_type == "business":
            b = db.get(BusinessProfile, target_id)
            return b.name if b else None
        if target_type == "review":
            r = db.get(Review, target_id)
            return f"Review of {r.business.name}" if r else None
        if target_type == "conversation":
            c = db.get(Conversation, target_id)
            return (f"Conversation between {display_name(c.customer.full_name)} and "
                    f"{c.business.name}") if c else None
        if target_type == "offer":
            o = db.get(Offer, target_id)
            return f"Offer “{o.title}” at {o.business.name}" if o else None
        if target_type == "campaign":
            c = db.get(Campaign, target_id)
            return f"Campaign “{c.name}” at {c.business.name}" if c else None
        if target_type == "user":
            u = db.get(User, target_id)
            return u.full_name if u else None
        return None


def action_out(entry: ModerationAction, titles: _Titles) -> ActionOut:
    subject = titles("user", entry.subject_user_id) if entry.subject_user_id else None
    return ActionOut(
        id=entry.id, action=entry.action, label=ACTION_LABELS.get(entry.action, entry.action),
        by=entry.admin.full_name if entry.admin else "Automatic checks",
        automatic=entry.admin_id is None, target_type=entry.target_type,
        target_id=entry.target_id, target_title=titles(entry.target_type, entry.target_id),
        subject_user_id=entry.subject_user_id, subject_name=subject, reason=entry.reason,
        reason_label=ms.reason_label(entry.reason) if entry.reason else None,
        note=entry.note or "", created_at=entry.created_at,
    )


def flag_out(flag: ModerationFlag, titles: _Titles) -> FlagOut:
    target = flag.target_type.value
    title = titles(target, flag.target_id) or f"{target.title()} #{flag.target_id}"
    return FlagOut(
        id=flag.id, target_type=flag.target_type, target_id=flag.target_id,
        target_title=title, business_id=flag.business_id, user_id=flag.user_id,
        user_name=titles("user", flag.user_id) if flag.user_id else None, rule=flag.rule,
        label=flag.label, detail=flag.detail, excerpt=flag.excerpt or "", status=flag.status,
        created_at=flag.created_at, resolved_at=flag.resolved_at,
    )


def _history(db: Session, target_type: str, target_id: int, titles: _Titles,
             limit: int = 30) -> list[ActionOut]:
    rows = db.scalars(select(ModerationAction).where(
        ModerationAction.target_type == target_type, ModerationAction.target_id == target_id,
    ).order_by(ModerationAction.created_at.desc(), ModerationAction.id.desc()).limit(limit))
    return [action_out(a, titles) for a in rows]


# ─────────────── overview ───────────────
@router.get("/overview", response_model=OverviewOut, summary="Queues, today and activity")
def overview(db: Session = Depends(get_db)) -> OverviewOut:
    now = _now()
    local_now = to_local(now)
    start_of_day = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_utc = start_of_day.astimezone(timezone.utc)
    week_ago = now - timedelta(days=RECENT_DAYS)

    def count(model, *where) -> int:
        return db.scalar(select(func.count()).select_from(model).where(*where)) or 0

    def items(column, *where) -> int:
        """Reported items, not report rows: two reports of one review are one to look at."""
        return db.scalar(select(func.count(func.distinct(column))).where(*where)) or 0

    open_review = items(ReviewReport.review_id, ReviewReport.status == ReportStatus.open)
    open_conversation = items(ConversationReport.conversation_id,
                              ConversationReport.status == ConversationReportStatus.open)
    open_business = items(BusinessReport.business_id,
                          BusinessReport.status == BusinessReportStatus.open)

    chart_start = (start_of_day - timedelta(days=CHART_DAYS - 1)).astimezone(timezone.utc)
    buckets: dict[str, Counter] = {k: Counter() for k in ("users", "businesses", "reports",
                                                           "flags")}

    def bucket(name: str, column) -> None:
        for (created,) in db.execute(select(column).where(column >= chart_start)):
            buckets[name][to_local(ms.aware(created)).date()] += 1

    bucket("users", User.created_at)
    bucket("businesses", BusinessProfile.created_at)
    bucket("reports", ReviewReport.created_at)
    bucket("reports", ConversationReport.created_at)
    bucket("reports", BusinessReport.created_at)
    bucket("flags", ModerationFlag.created_at)
    daily = []
    for i in range(CHART_DAYS - 1, -1, -1):
        day = (start_of_day - timedelta(days=i)).date()
        daily.append(DayCount(day=day, label=day.strftime("%a"),
                              **{k: buckets[k][day] for k in buckets}))

    titles = _Titles(db)
    recent = db.scalars(select(ModerationAction).order_by(
        ModerationAction.created_at.desc(), ModerationAction.id.desc()).limit(10))
    return OverviewOut(
        pending_review=count(BusinessProfile,
                             BusinessProfile.verification_status == VerificationStatus.pending_review,
                             BusinessProfile.suspended_at.is_(None)),
        needs_info=count(BusinessProfile,
                         BusinessProfile.verification_status == VerificationStatus.needs_info),
        open_reports=open_review + open_conversation + open_business,
        open_review_reports=open_review,
        open_conversation_reports=open_conversation,
        open_business_reports=open_business,
        open_flags=count(ModerationFlag, ModerationFlag.status == FlagStatus.open),
        suspended_accounts=count(User, User.is_banned.is_(False), User.suspended_until > now),
        banned_accounts=count(User, User.is_banned.is_(True)),
        suspended_businesses=count(BusinessProfile, BusinessProfile.suspended_at.is_not(None)),
        users_total=count(User),
        businesses_total=count(BusinessProfile),
        verified_total=count(BusinessProfile, BusinessProfile.is_verified.is_(True)),
        new_users_today=count(User, User.created_at >= today_utc),
        new_businesses_today=count(BusinessProfile, BusinessProfile.created_at >= today_utc),
        reviews_today=count(Review, Review.created_at >= today_utc),
        messages_today=count(Message, Message.created_at >= today_utc),
        auto_verified_week=count(ModerationAction,
                                 ModerationAction.action == ActionKind.auto_verify,
                                 ModerationAction.created_at >= week_ago),
        daily=daily,
        recent=[action_out(a, titles) for a in recent],
    )


# ─────────────── businesses and verification (FR-14, UC-12, Algorithm 9) ───────────────
BusinessFilter = Literal["all", "pending_review", "needs_info", "rejected", "verified",
                         "unverified", "suspended", "recently_verified"]


@router.get("/businesses", response_model=BusinessPage,
            summary="Businesses: the verification queue and everything else")
def list_businesses(
    status_filter: BusinessFilter = Query(default="all", alias="status"),
    q: str = Query(default="", max_length=100),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> BusinessPage:
    """`pending_review` is the queue the automatic checks referred (oldest first).
    `recently_verified` lists the last week's verifications to spot-check."""
    query = select(BusinessProfile)
    order = [BusinessProfile.created_at.desc(), BusinessProfile.id.desc()]
    if status_filter == "suspended":
        query = query.where(BusinessProfile.suspended_at.is_not(None))
    elif status_filter == "recently_verified":
        query = query.where(BusinessProfile.is_verified.is_(True),
                            BusinessProfile.verified_at >= _now() - timedelta(days=RECENT_DAYS))
        order = [BusinessProfile.verified_at.desc(), BusinessProfile.id.desc()]
    elif status_filter != "all":
        query = query.where(BusinessProfile.verification_status == VerificationStatus(status_filter))
        if status_filter == "pending_review":
            query = query.where(BusinessProfile.suspended_at.is_(None))
            order = [BusinessProfile.created_at.asc(), BusinessProfile.id.asc()]
    if q.strip():
        query = query.where(BusinessProfile.name.ilike(f"%{q.strip()}%"))
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(*order).limit(limit).offset(offset))
    return BusinessPage(items=[business_row(db, b) for b in rows], total=total)


def _business(db: Session, business_id: int) -> BusinessProfile:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise _not_found("Business")
    return b


def _business_reports(db: Session, b: BusinessProfile) -> list[ReportEntry]:
    rows = db.scalars(select(BusinessReport).where(BusinessReport.business_id == b.id)
                      .order_by(BusinessReport.created_at.desc()))
    return [_business_report_entry(r) for r in rows]


def _business_report_entry(r: BusinessReport) -> ReportEntry:
    return ReportEntry(id=r.id, reason=r.reason.value,
                       reason_label=BUSINESS_REASON_LABELS.get(r.reason, r.reason.value),
                       note=r.note or "", reporter_id=r.reporter_id,
                       reporter_name=r.reporter.full_name if r.reporter else "",
                       status=r.status.value, created_at=r.created_at)


def _business_flags(db: Session, b: BusinessProfile, titles: _Titles) -> list[FlagOut]:
    rows = db.scalars(select(ModerationFlag).where(
        or_(
            (ModerationFlag.business_id == b.id)
            & ModerationFlag.target_type.in_([FlagTarget.business, FlagTarget.offer,
                                              FlagTarget.campaign]),
            (ModerationFlag.target_type == FlagTarget.user)
            & (ModerationFlag.target_id == b.owner_id),
        )
    ).order_by(ModerationFlag.created_at.desc()).limit(50))
    return [flag_out(f, titles) for f in rows]


def business_detail(db: Session, b: BusinessProfile) -> AdminBusinessDetail:
    titles = _Titles(db)
    verified_by = None
    if b.is_verified:
        admin = db.get(User, b.verified_by_id) if b.verified_by_id else None
        verified_by = admin.full_name if admin else "Automatic checks"
    owner_note = db.scalar(select(ModerationAction.note).where(
        ModerationAction.target_type == "business", ModerationAction.target_id == b.id,
        ModerationAction.action == ActionKind.review_requested,
    ).order_by(ModerationAction.created_at.desc(), ModerationAction.id.desc()).limit(1))
    return AdminBusinessDetail(
        **business_row(db, b).model_dump(),
        description=b.description or "", tagline=b.tagline or "", phone=b.phone,
        photos=[photo_out(p.media) for p in b.photos],
        latitude=b.latitude, longitude=b.longitude, storefront_at=b.storefront_at,
        verification_note=b.verification_note or "", verified_by=verified_by,
        owner_note=owner_note or None,
        checks=[CheckOut(key=c.key, label=c.label, passed=c.passed, hint=c.hint)
                for c in vs.checks(db, b)],
        owner=person_out(b.owner),
        flags=_business_flags(db, b, titles),
        reports=_business_reports(db, b),
        history=_history(db, "business", b.id, titles),
    )


@router.get("/businesses/{business_id}", response_model=AdminBusinessDetail)
def get_business(business_id: int, db: Session = Depends(get_db)) -> AdminBusinessDetail:
    return business_detail(db, _business(db, business_id))


@router.post("/businesses/{business_id}/verification", response_model=AdminBusinessDetail,
             summary="Approve, reject, ask for more, or revoke (Algorithm 9)")
def decide_verification(
    business_id: int,
    payload: VerificationDecisionIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> AdminBusinessDetail:
    b = _business(db, business_id)
    try:
        jobs = vs.decide(db, admin, b, payload.decision, payload.note)
    except ms.ModerationError as exc:
        raise _refused(exc) from None
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return business_detail(db, b)


@router.post("/businesses/{business_id}/suspend", response_model=AdminBusinessDetail,
             summary="Take a listing down")
def suspend_business(
    business_id: int,
    payload: SuspendIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> AdminBusinessDetail:
    b = _business(db, business_id)
    if b.suspended_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="This business is already suspended.")
    jobs = ms.suspend_business(db, admin, b, payload.reason, payload.note)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return business_detail(db, b)


@router.post("/businesses/{business_id}/reinstate", response_model=AdminBusinessDetail,
             summary="Put a suspended listing back")
def reinstate_business(
    business_id: int,
    payload: NoteIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> AdminBusinessDetail:
    b = _business(db, business_id)
    if b.suspended_at is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="This business isn’t suspended.")
    jobs = ms.reinstate_business(db, admin, b, payload.note)
    db.commit()
    db.refresh(b)
    _run(background_tasks, jobs)
    return business_detail(db, b)


# ─────────────── reports (FR-15, FR-19, Algorithm 10) ───────────────
ReportStatusFilter = Literal["open", "resolved", "all"]
_OPEN = {"review": ReportStatus.open, "conversation": ConversationReportStatus.open,
         "business": BusinessReportStatus.open}


def _report_rows(db: Session, kind: ReportKind, status_filter: ReportStatusFilter):
    model = {"review": ReviewReport, "conversation": ConversationReport,
             "business": BusinessReport}[kind]
    query = select(model)
    if status_filter == "open":
        query = query.where(model.status == _OPEN[kind])
    elif status_filter == "resolved":
        query = query.where(model.status != _OPEN[kind])
    return list(db.scalars(query))


def _target_id(kind: ReportKind, report) -> int:
    return {"review": lambda r: r.review_id, "conversation": lambda r: r.conversation_id,
            "business": lambda r: r.business_id}[kind](report)


def _reason_label(kind: ReportKind, reason) -> str:
    labels = {"review": REVIEW_REASON_LABELS, "conversation": CONVERSATION_REASON_LABELS,
              "business": BUSINESS_REASON_LABELS}[kind]
    return labels.get(reason, str(getattr(reason, "value", reason)))


def _report_item(db: Session, kind: ReportKind, target_id: int, reports: list
                 ) -> ReportItem | None:
    business_id = None
    if kind == "review":
        review = db.get(Review, target_id)
        if review is None:
            return None
        title = f"Review of {review.business.name} by {display_name(review.author.full_name)}"
        snippet, business_id = review.comment[:160], review.business_id
    elif kind == "conversation":
        c = db.get(Conversation, target_id)
        if c is None:
            return None
        title = f"{display_name(c.customer.full_name)} and {c.business.name}"
        snippet, business_id = next((r.note for r in reports if r.note), ""), c.business_id
    else:
        b = db.get(BusinessProfile, target_id)
        if b is None:
            return None
        title, snippet, business_id = b.name, b.tagline or b.address or "", b.id
    created = [ms.aware(r.created_at) for r in reports]
    return ReportItem(
        kind=kind, target_id=target_id, title=title, snippet=snippet,
        report_count=len({r.reporter_id for r in reports}),
        reasons=dict(Counter(_reason_label(kind, r.reason) for r in reports)),
        first_at=min(created), latest_at=max(created),
        open=any(r.status == _OPEN[kind] for r in reports), business_id=business_id,
    )


@router.get("/reports", response_model=ReportPage,
            summary="Reported reviews, conversations and businesses, grouped per item")
def list_reports(
    kind: Literal["all", "review", "conversation", "business"] = "all",
    status_filter: ReportStatusFilter = Query(default="open", alias="status"),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> ReportPage:
    """Open items come most-reported first, then oldest first; resolved ones newest first."""
    kinds: list[ReportKind] = ["review", "conversation", "business"] if kind == "all" else [kind]
    items: list[ReportItem] = []
    for k in kinds:
        grouped: dict[int, list] = defaultdict(list)
        for r in _report_rows(db, k, status_filter):
            grouped[_target_id(k, r)].append(r)
        for target_id, reports in grouped.items():
            if (item := _report_item(db, k, target_id, reports)) is not None:
                items.append(item)
    if status_filter == "open":
        items.sort(key=lambda i: (-i.report_count, i.first_at))
    else:
        items.sort(key=lambda i: i.latest_at, reverse=True)
    return ReportPage(items=items[offset:offset + limit], total=len(items))


def _reports_for(db: Session, kind: ReportKind, target_id: int) -> list:
    model, column = {
        "review": (ReviewReport, ReviewReport.review_id),
        "conversation": (ConversationReport, ConversationReport.conversation_id),
        "business": (BusinessReport, BusinessReport.business_id),
    }[kind]
    return list(db.scalars(select(model).where(column == target_id)
                           .order_by(model.created_at.desc())))


def _entry(db: Session, kind: ReportKind, r) -> ReportEntry:
    reporter = db.get(User, r.reporter_id)
    return ReportEntry(id=r.id, reason=r.reason.value, reason_label=_reason_label(kind, r.reason),
                       note=r.note or "", reporter_id=r.reporter_id,
                       reporter_name=reporter.full_name if reporter else "",
                       status=r.status.value, created_at=r.created_at)


def report_detail(db: Session, kind: ReportKind, target_id: int) -> ReportDetail:
    reports = _reports_for(db, kind, target_id)
    if not reports:  # admins see a conversation only because someone reported it (SEC-5)
        raise _not_found("Report")
    titles = _Titles(db)
    item = _report_item(db, kind, target_id, reports)
    if item is None:
        raise _not_found("Reported content")
    detail = ReportDetail(kind=kind, target_id=target_id, title=item.title, open=item.open,
                          reports=[_entry(db, kind, r) for r in reports])
    if kind == "review":
        review = db.get(Review, target_id)
        detail.review = AdminReview(
            id=review.id, rating=review.rating, comment=review.comment,
            photos=[photo_out(p.media) for p in review.photos], created_at=review.created_at,
            is_visible=review.is_approved and review.deleted_at is None,
            author=person_out(review.author), business=business_brief(review.business))
        detail.accounts = [person_out(review.author)]
        detail.flags = [flag_out(f, titles) for f in db.scalars(select(ModerationFlag).where(
            ModerationFlag.target_type == FlagTarget.review,
            ModerationFlag.target_id == review.id))]
        detail.history = _history(db, "review", review.id, titles)
    elif kind == "conversation":
        c = db.get(Conversation, target_id)
        owner = c.business.owner
        messages = list(db.scalars(select(Message).where(Message.conversation_id == c.id)
                                   .order_by(Message.id.desc()).limit(MAX_MESSAGES)))
        detail.conversation = AdminConversation(
            id=c.id, business=business_brief(c.business), customer=person_out(c.customer),
            owner=person_out(owner),
            messages=[AdminMessage(id=m.id, side="business" if m.from_business else "customer",
                                   body=m.body, photo=photo_out(m.photo), created_at=m.created_at)
                      for m in reversed(messages)],
            closed=c.closed_at is not None, blocked_by=c.blocked_by)
        # The reported side first: whoever didn't make the reports.
        reporters = {r.reporter_id for r in reports}
        people = [c.customer, owner]
        if c.customer.id in reporters and owner.id not in reporters:
            people.reverse()
        detail.accounts = [person_out(u) for u in people]
        detail.history = _history(db, "conversation", c.id, titles)
    else:
        b = db.get(BusinessProfile, target_id)
        detail.business = business_brief(b)
        detail.accounts = [person_out(b.owner)]
        detail.flags = _business_flags(db, b, titles)
        detail.history = _history(db, "business", b.id, titles)
    return detail


@router.get("/reports/{kind}/{target_id}", response_model=ReportDetail)
def get_report(kind: ReportKind, target_id: int, db: Session = Depends(get_db)) -> ReportDetail:
    return report_detail(db, kind, target_id)


def _settle_flags(db: Session, admin: User, target: FlagTarget, target_id: int,
                  now: datetime, *, except_id: int | None = None) -> None:
    """Once content is removed, its other open flags are settled too: nobody needs to
    decide on a review that's already gone."""
    for flag in db.scalars(select(ModerationFlag).where(
            ModerationFlag.target_type == target, ModerationFlag.target_id == target_id,
            ModerationFlag.status == FlagStatus.open)):
        if flag.id != except_id:
            flag.status, flag.resolved_at, flag.resolved_by_id = FlagStatus.actioned, now, admin.id


def _settle_reports(db: Session, admin: User, kind: ReportKind, target_id: int,
                    now: datetime) -> list:
    """Upholding a flag removed reported content: resolve its open reports as upheld and
    tell the reporters, as if the report had been decided."""
    pending = [r for r in _reports_for(db, kind, target_id) if r.status == _OPEN[kind]]
    status_for = {"review": ReportStatus.removed, "conversation": ConversationReportStatus.removed,
                  "business": BusinessReportStatus.actioned}
    for r in pending:
        r.status, r.resolved_at, r.resolved_by_id = status_for[kind], now, admin.id
    reporters = [u for u in (db.get(User, r.reporter_id) for r in pending) if u is not None]
    return ms.tell_reporters(db, reporters, upheld=True, what=kind, now=now) if reporters else []


def _account_jobs(db: Session, admin: User, payload: ResolveIn, default: User | None,
                  allowed: list[User]) -> list:
    """The optional follow-up on the account behind the content."""
    if payload.account_action == "none":
        return []
    target = default
    if payload.account_user_id is not None:
        target = next((u for u in allowed if u.id == payload.account_user_id), None)
        if target is None:
            raise HTTPException(status_code=422, detail="Choose one of the accounts involved.")
    if target is None:
        raise HTTPException(status_code=422, detail="Choose which account to act on.")
    return ms.act_on_user(db, admin, target, payload.account_action, payload.reason,
                          payload.note, days=payload.suspend_days,
                          hide_reviews=payload.hide_reviews)


@router.post("/reports/{kind}/{target_id}/resolve", response_model=ReportDetail,
             summary="Uphold (remove the content) or dismiss (keep it)")
def resolve_report(
    kind: ReportKind,
    target_id: int,
    payload: ResolveIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> ReportDetail:
    """SDD Algorithm 10. Upholding removes a review, closes a conversation or suspends a
    business. Every open report on the item is resolved and each reporter is told."""
    now = _now()
    pending = [r for r in _reports_for(db, kind, target_id) if r.status == _OPEN[kind]]
    if not pending:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="These reports have already been resolved.")
    uphold = payload.decision == "uphold"
    jobs: list = []
    business: BusinessProfile | None = None
    try:
        if kind == "review":
            review = db.get(Review, target_id)
            what, default, allowed = "review", review.author, [review.author]
            if uphold:
                jobs += ms.hide_review(db, admin, review, payload.reason, payload.note, now=now)
            new_status = ReportStatus.removed if uphold else ReportStatus.dismissed
        elif kind == "conversation":
            c = db.get(Conversation, target_id)
            what, default, allowed = "conversation", None, [c.customer, c.business.owner]
            if uphold:
                jobs += ms.close_conversation(db, admin, c, payload.reason, payload.note,
                                              now=now)
            new_status = (ConversationReportStatus.removed if uphold
                          else ConversationReportStatus.dismissed)
        else:
            business = db.get(BusinessProfile, target_id)
            what, default, allowed = "business", business.owner, [business.owner]
            if uphold:
                jobs += ms.suspend_business(db, admin, business, payload.reason, payload.note,
                                            now=now)
            new_status = (BusinessReportStatus.actioned if uphold
                          else BusinessReportStatus.dismissed)
        jobs += _account_jobs(db, admin, payload, default, allowed)
    except ms.ModerationError as exc:
        raise _refused(exc) from None
    for r in pending:
        r.status, r.resolved_at, r.resolved_by_id = new_status, now, admin.id
    if uphold and kind in ("review", "business"):
        _settle_flags(db, admin, FlagTarget(kind), target_id, now)
    if not uphold:
        ms.log_action(db, admin=admin, action=ActionKind.dismiss_report, target_type=kind,
                      target_id=target_id, reason=payload.reason, note=payload.note, now=now)
        if business is not None:
            jobs += vs.refresh(db, business, now=now)  # a cleared record may now pass
    reporters = [u for u in (db.get(User, r.reporter_id) for r in pending) if u is not None]
    jobs += ms.tell_reporters(db, reporters, upheld=uphold, what=what, now=now)
    db.commit()
    _run(background_tasks, jobs)
    return report_detail(db, kind, target_id)


# ─────────────── flags from the automatic rules ───────────────
@router.get("/flags", response_model=FlagPage, summary="What the automatic rules noticed")
def list_flags(
    status_filter: Literal["open", "resolved", "all"] = Query(default="open", alias="status"),
    target_type: FlagTarget | None = None,
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> FlagPage:
    query = select(ModerationFlag)
    if status_filter == "open":
        query = query.where(ModerationFlag.status == FlagStatus.open)
    elif status_filter == "resolved":
        query = query.where(ModerationFlag.status != FlagStatus.open)
    if target_type is not None:
        query = query.where(ModerationFlag.target_type == target_type)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(ModerationFlag.created_at.desc(), ModerationFlag.id.desc())
                      .limit(limit).offset(offset))
    titles = _Titles(db)
    return FlagPage(items=[flag_out(f, titles) for f in rows], total=total)


@router.post("/flags/{flag_id}/resolve", response_model=FlagOut,
             summary="Uphold (act on the content) or dismiss a flag")
def resolve_flag(
    flag_id: int,
    payload: ResolveIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> FlagOut:
    """Upholding removes a review, switches off an offer, unpublishes a campaign or
    suspends a business. A flag on an account only records the decision; use the
    account action to warn or suspend it."""
    flag = db.get(ModerationFlag, flag_id)
    if flag is None:
        raise _not_found("Flag")
    if flag.status != FlagStatus.open:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="This flag has already been resolved.")
    now = _now()
    uphold = payload.decision == "uphold"
    responsible = db.get(User, flag.user_id) if flag.user_id else None
    jobs: list = []
    business = db.get(BusinessProfile, flag.business_id) if flag.business_id else None
    try:
        if uphold:
            if flag.target_type == FlagTarget.review and (r := db.get(Review, flag.target_id)):
                jobs += ms.hide_review(db, admin, r, payload.reason, payload.note, now=now)
                jobs += _settle_reports(db, admin, "review", r.id, now)
            elif flag.target_type == FlagTarget.offer and (o := db.get(Offer, flag.target_id)):
                jobs += ms.deactivate_offer(db, admin, o, payload.reason, payload.note, now=now)
            elif flag.target_type == FlagTarget.campaign and (
                    c := db.get(Campaign, flag.target_id)):
                jobs += ms.unpublish_campaign(db, admin, c, payload.reason, payload.note,
                                              now=now)
            elif flag.target_type == FlagTarget.business and business is not None:
                jobs += ms.suspend_business(db, admin, business, payload.reason, payload.note,
                                            now=now)
                jobs += _settle_reports(db, admin, "business", business.id, now)
        jobs += _account_jobs(db, admin, payload, responsible,
                              [responsible] if responsible else [])
    except ms.ModerationError as exc:
        raise _refused(exc) from None
    flag.status = FlagStatus.actioned if uphold else FlagStatus.dismissed
    flag.resolved_at, flag.resolved_by_id = now, admin.id
    if uphold and flag.target_type in (FlagTarget.review, FlagTarget.business):
        _settle_flags(db, admin, flag.target_type, flag.target_id, now, except_id=flag.id)
    if not uphold:
        ms.log_action(db, admin=admin, action=ActionKind.dismiss_flag, target_type="flag",
                      target_id=flag.id, subject_user_id=flag.user_id, reason=payload.reason,
                      note=f"{flag.detail}. {payload.note}".strip(), now=now)
        if business is not None:
            jobs += vs.refresh(db, business, now=now)
    db.commit()
    _run(background_tasks, jobs)
    return flag_out(flag, _Titles(db))


# ─────────────── users ───────────────
UserFilter = Literal["all", "active", "suspended", "banned"]


def _user_counts(db: Session, user: User) -> dict:
    def count(model, *where) -> int:
        return db.scalar(select(func.count()).select_from(model).where(*where)) or 0

    own_reviews = select(Review.id).where(Review.user_id == user.id)
    own_businesses = select(BusinessProfile.id).where(BusinessProfile.owner_id == user.id)
    return dict(
        businesses=count(BusinessProfile, BusinessProfile.owner_id == user.id),
        reviews=count(Review, Review.user_id == user.id, Review.deleted_at.is_(None)),
        reports_against=count(ReviewReport, ReviewReport.review_id.in_(own_reviews),
                              ReviewReport.status == ReportStatus.open)
        + count(BusinessReport, BusinessReport.business_id.in_(own_businesses),
                BusinessReport.status == BusinessReportStatus.open),
        open_flags=count(ModerationFlag, ModerationFlag.user_id == user.id,
                         ModerationFlag.status == FlagStatus.open),
        warnings=count(ModerationAction, ModerationAction.subject_user_id == user.id,
                       ModerationAction.action == ActionKind.warn_user),
    )


def user_row(db: Session, user: User) -> AdminUserRow:
    return AdminUserRow(**person_out(user).model_dump(), **_user_counts(db, user))


@router.get("/users", response_model=UserPage, summary="Find accounts")
def list_users(
    q: str = Query(default="", max_length=100),
    status_filter: UserFilter = Query(default="all", alias="status"),
    role: UserRole | None = None,
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> UserPage:
    now = _now()
    query = select(User)
    if q.strip():
        term = f"%{q.strip()}%"
        query = query.where(or_(User.full_name.ilike(term), User.email.ilike(term)))
    if role is not None:
        query = query.where(User.role == role)
    if status_filter == "banned":
        query = query.where(User.is_banned.is_(True))
    elif status_filter == "suspended":
        query = query.where(User.is_banned.is_(False), User.suspended_until > now)
    elif status_filter == "active":
        query = query.where(User.is_banned.is_(False),
                            or_(User.suspended_until.is_(None), User.suspended_until <= now))
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(User.created_at.desc(), User.id.desc())
                      .limit(limit).offset(offset))
    return UserPage(items=[user_row(db, u) for u in rows], total=total)


def user_detail(db: Session, user: User) -> AdminUserDetail:
    titles = _Titles(db)
    history = db.scalars(select(ModerationAction).where(
        ModerationAction.subject_user_id == user.id,
    ).order_by(ModerationAction.created_at.desc(), ModerationAction.id.desc()).limit(50))
    flags = db.scalars(select(ModerationFlag).where(ModerationFlag.user_id == user.id)
                       .order_by(ModerationFlag.created_at.desc()).limit(50))
    removed = db.scalar(select(func.count(Review.id)).where(
        Review.user_id == user.id, Review.deleted_at.is_(None),
        Review.is_approved.is_(False))) or 0
    return AdminUserDetail(
        **user_row(db, user).model_dump(), phone=user.phone, removed_reviews=removed,
        owned=[business_brief(b) for b in user.businesses],
        flags=[flag_out(f, titles) for f in flags],
        history=[action_out(a, titles) for a in history],
    )


def _user(db: Session, user_id: int) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise _not_found("Account")
    return user


@router.get("/users/{user_id}", response_model=AdminUserDetail)
def get_user(user_id: int, db: Session = Depends(get_db)) -> AdminUserDetail:
    return user_detail(db, _user(db, user_id))


@router.post("/users/{user_id}/action", response_model=AdminUserDetail,
             summary="Warn, suspend, ban, or lift a suspension or ban")
def act_on_user(
    user_id: int,
    payload: UserActionIn,
    background_tasks: BackgroundTasks,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetail:
    user = _user(db, user_id)
    try:
        jobs = ms.act_on_user(db, admin, user, payload.action, payload.reason, payload.note,
                              days=payload.days, hide_reviews=payload.hide_reviews)
    except ms.ModerationError as exc:
        raise _refused(exc) from None
    db.commit()
    db.refresh(user)
    _run(background_tasks, jobs)
    return user_detail(db, user)


# ─────────────── activity (the audit log) ───────────────
@router.get("/actions", response_model=ActionPage, summary="The audit log, newest first")
def list_actions(
    target_type: str | None = Query(default=None, max_length=16),
    target_id: int | None = None,
    subject_user_id: int | None = None,
    automatic: bool | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> ActionPage:
    query = select(ModerationAction)
    if target_type:
        query = query.where(ModerationAction.target_type == target_type)
    if target_id is not None:
        query = query.where(ModerationAction.target_id == target_id)
    if subject_user_id is not None:
        query = query.where(ModerationAction.subject_user_id == subject_user_id)
    if automatic is not None:
        query = query.where(ModerationAction.admin_id.is_(None) if automatic
                            else ModerationAction.admin_id.is_not(None))
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(ModerationAction.created_at.desc(),
                                     ModerationAction.id.desc()).limit(limit).offset(offset))
    titles = _Titles(db)
    return ActionPage(items=[action_out(a, titles) for a in rows], total=total)
