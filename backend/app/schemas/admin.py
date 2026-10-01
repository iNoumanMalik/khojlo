"""Module 8 — admin panel request and response bodies (SRS FR-14, FR-15, SEC-3)."""
from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.models.moderation import (
    ActionKind,
    FlagLabel,
    FlagStatus,
    FlagTarget,
    ModerationReason,
    VerificationStatus,
)
from app.models.user import UserRole
from app.schemas.media import PhotoOut
from app.schemas.moderation import CheckOut

AccountStatus = Literal["active", "suspended", "banned"]
ReportKind = Literal["review", "conversation", "business"]


# ─────────────── people and businesses ───────────────
class AdminPerson(BaseModel):
    id: int
    full_name: str
    email: str
    role: UserRole
    initials: str
    tone: str
    avatar: PhotoOut | None = None
    email_verified: bool
    status: AccountStatus
    suspended_until: datetime | None = None
    # A reason label, e.g. "Scam or fraud", while suspended or banned.
    suspension_reason: str | None = None
    created_at: datetime


class AdminBusinessBrief(BaseModel):
    id: int
    name: str
    tone: str
    cover: PhotoOut | None = None
    category_label: str | None = None
    address: str = ""
    owner_id: int
    owner_name: str
    verification_status: VerificationStatus
    is_verified: bool
    is_published: bool
    is_suspended: bool
    suspension_reason: str | None = None
    rating: float = 0
    review_count: int = 0
    created_at: datetime
    verified_at: datetime | None = None
    # Verified by the automatic checks rather than an admin (spot-check these).
    auto_verified: bool = False
    storefront: PhotoOut | None = None


class AdminBusinessRow(AdminBusinessBrief):
    open_reports: int = 0
    open_flags: int = 0


class BusinessPage(BaseModel):
    items: list[AdminBusinessRow]
    total: int


# ─────────────── audit log and flags ───────────────
class ActionOut(BaseModel):
    id: int
    action: ActionKind
    # "Suspended a business"
    label: str
    # The admin's name, or "Automatic checks".
    by: str
    automatic: bool
    target_type: str
    target_id: int
    target_title: str | None = None
    subject_user_id: int | None = None
    subject_name: str | None = None
    reason: ModerationReason | None = None
    reason_label: str | None = None
    note: str = ""
    created_at: datetime


class ActionPage(BaseModel):
    items: list[ActionOut]
    total: int


class FlagOut(BaseModel):
    id: int
    target_type: FlagTarget
    target_id: int
    # "Review of Chai Khana", a business name, an offer title…
    target_title: str
    business_id: int | None = None
    user_id: int | None = None
    user_name: str | None = None
    rule: str
    label: FlagLabel
    detail: str
    excerpt: str = ""
    status: FlagStatus
    created_at: datetime
    resolved_at: datetime | None = None


class FlagPage(BaseModel):
    items: list[FlagOut]
    total: int


# ─────────────── reports ───────────────
class ReportEntry(BaseModel):
    id: int
    reason: str
    reason_label: str
    note: str = ""
    reporter_id: int
    reporter_name: str
    status: str
    created_at: datetime


class ReportItem(BaseModel):
    """Everything reported about one review, conversation or business."""

    kind: ReportKind
    target_id: int
    title: str
    snippet: str = ""
    report_count: int
    # Reason label → how many reports gave it.
    reasons: dict[str, int]
    first_at: datetime
    latest_at: datetime
    open: bool
    business_id: int | None = None


class ReportPage(BaseModel):
    items: list[ReportItem]
    total: int


class AdminReview(BaseModel):
    id: int
    rating: int
    comment: str
    photos: list[PhotoOut] = Field(default_factory=list)
    created_at: datetime
    is_visible: bool
    author: AdminPerson
    business: AdminBusinessBrief


class AdminMessage(BaseModel):
    id: int
    side: Literal["customer", "business"]
    body: str
    photo: PhotoOut | None = None
    created_at: datetime


class AdminConversation(BaseModel):
    """Shown only because a participant reported it (decision 8, SEC-5 exception)."""

    id: int
    business: AdminBusinessBrief
    customer: AdminPerson
    owner: AdminPerson
    messages: list[AdminMessage]
    closed: bool
    blocked_by: str | None = None


class ReportDetail(BaseModel):
    kind: ReportKind
    target_id: int
    title: str
    open: bool
    reports: list[ReportEntry]
    review: AdminReview | None = None
    conversation: AdminConversation | None = None
    business: AdminBusinessBrief | None = None
    # Accounts an action could apply to, the most likely one first.
    accounts: list[AdminPerson] = Field(default_factory=list)
    flags: list[FlagOut] = Field(default_factory=list)
    history: list[ActionOut] = Field(default_factory=list)


class AccountActionIn(BaseModel):
    """An optional follow-up on the account behind the content."""

    account_action: Literal["none", "warn", "suspend", "ban"] = "none"
    # Required for conversations (either participant); defaults to the author or owner.
    account_user_id: int | None = None
    suspend_days: int = Field(default=7, ge=1, le=365)
    # With a ban: also hide every review the account wrote.
    hide_reviews: bool = False


class ResolveIn(AccountActionIn):
    """SDD Algorithm 10: uphold (remove the content) or dismiss (keep it)."""

    decision: Literal["uphold", "dismiss"]
    reason: ModerationReason = ModerationReason.other
    note: str = Field(default="", max_length=1000)


# ─────────────── business detail and actions ───────────────
class AdminBusinessDetail(AdminBusinessRow):
    description: str = ""
    tagline: str = ""
    phone: str | None = None
    photos: list[PhotoOut] = Field(default_factory=list)
    latitude: float | None = None
    longitude: float | None = None
    storefront_at: datetime | None = None
    verification_note: str = ""
    # The admin who verified it, or "Automatic checks".
    verified_by: str | None = None
    # The owner's message when they last asked for another look.
    owner_note: str | None = None
    checks: list[CheckOut] = Field(default_factory=list)
    owner: AdminPerson
    flags: list[FlagOut] = Field(default_factory=list)
    reports: list[ReportEntry] = Field(default_factory=list)
    history: list[ActionOut] = Field(default_factory=list)


class VerificationDecisionIn(BaseModel):
    decision: Literal["approve", "reject", "request_info", "revoke"]
    # Required unless approving: the owner sees it.
    note: str = Field(default="", max_length=500)


class SuspendIn(BaseModel):
    reason: ModerationReason
    note: str = Field(default="", max_length=1000)


class NoteIn(BaseModel):
    note: str = Field(default="", max_length=1000)


# ─────────────── users ───────────────
class AdminUserRow(AdminPerson):
    businesses: int = 0
    reviews: int = 0
    # Open reports about their reviews and businesses.
    reports_against: int = 0
    open_flags: int = 0
    warnings: int = 0


class UserPage(BaseModel):
    items: list[AdminUserRow]
    total: int


class AdminUserDetail(AdminUserRow):
    phone: str | None = None
    removed_reviews: int = 0
    owned: list[AdminBusinessBrief] = Field(default_factory=list)
    flags: list[FlagOut] = Field(default_factory=list)
    history: list[ActionOut] = Field(default_factory=list)


class UserActionIn(BaseModel):
    action: Literal["warn", "suspend", "ban", "lift"]
    reason: ModerationReason = ModerationReason.other
    note: str = Field(default="", max_length=1000)
    days: int = Field(default=7, ge=1, le=365)
    hide_reviews: bool = False


# ─────────────── overview ───────────────
class DayCount(BaseModel):
    day: date
    # "Mon"
    label: str
    users: int = 0
    businesses: int = 0
    reports: int = 0
    flags: int = 0


class OverviewOut(BaseModel):
    pending_review: int
    needs_info: int
    open_reports: int
    open_review_reports: int
    open_conversation_reports: int
    open_business_reports: int
    open_flags: int
    suspended_accounts: int
    banned_accounts: int
    suspended_businesses: int
    users_total: int
    businesses_total: int
    verified_total: int
    new_users_today: int
    new_businesses_today: int
    reviews_today: int
    messages_today: int
    auto_verified_week: int
    daily: list[DayCount]
    recent: list[ActionOut]
