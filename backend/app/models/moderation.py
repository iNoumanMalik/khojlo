"""Module 8 — admin and moderation (SRS FR-14, FR-15, FR-19; SDD Algorithms 9 and 10).

* `BusinessReport`: a user's report of a business listing. Reviews and conversations keep
  their own report tables (Modules 5 and 9).
* `ModerationFlag`: something the automatic rules noticed, for an admin to check. A flag
  never changes or hides content by itself: reported and flagged content stays visible
  until an admin decides (BR-13).
* `ModerationAction`: the audit log. Every verification decision, removal, warning and
  suspension is recorded, whether an admin or the automatic checks made it.
"""
import enum
from datetime import datetime, timezone

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ModerationReason(str, enum.Enum):
    """Why content or an account was acted on. Each is a section of the Community
    Guidelines (BR-10), so every notice can say which rule was broken."""

    spam = "spam"
    scam = "scam"
    adult = "adult"
    prohibited = "prohibited"
    harassment = "harassment"
    fake = "fake"
    other = "other"


REASON_LABELS: dict[ModerationReason, str] = {
    ModerationReason.spam: "Spam or advertising",
    ModerationReason.scam: "Scam or fraud",
    ModerationReason.adult: "Adult or sexual content",
    ModerationReason.prohibited: "Prohibited items or services",
    ModerationReason.harassment: "Harassment, hate or threats",
    ModerationReason.fake: "Fake or misleading information",
    ModerationReason.other: "Breaking the Community Guidelines",
}


class VerificationStatus(str, enum.Enum):
    """Where a business is in verification (SRS FR-14, UC-12; SDD business lifecycle).

    Businesses are listed as soon as they're published; verification adds the badge.
    The automatic checks verify a business once it passes them, and refer it to an
    admin when a report or flag needs a person to look (decision 1).
    """

    unverified = "unverified"  # the checks haven't all passed yet
    pending_review = "pending_review"  # referred to an admin
    needs_info = "needs_info"  # an admin asked the owner for more (UC-12 alternative flow)
    verified = "verified"
    rejected = "rejected"  # an admin declined or revoked the badge


class BusinessReportReason(str, enum.Enum):
    scam = "scam"
    prohibited = "prohibited"  # adult content or prohibited items for sale
    fake = "fake"  # not a real business
    wrong_info = "wrong_info"
    offensive = "offensive"
    other = "other"


class BusinessReportStatus(str, enum.Enum):
    open = "open"  # waiting for an admin
    actioned = "actioned"  # the admin suspended the listing
    dismissed = "dismissed"  # the admin kept it


class BusinessReport(Base):
    """A user's report of a business listing (FR-19, extended to businesses)."""

    __tablename__ = "business_reports"
    __table_args__ = (UniqueConstraint("business_id", "reporter_id", name="uq_business_report"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    reason: Mapped[BusinessReportReason] = mapped_column(
        Enum(BusinessReportReason, name="business_report_reason", native_enum=False, length=16)
    )
    note: Mapped[str] = mapped_column(String(500), default="")
    status: Mapped[BusinessReportStatus] = mapped_column(
        Enum(BusinessReportStatus, name="business_report_status", native_enum=False, length=16),
        default=BusinessReportStatus.open,
        server_default=text("'open'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    business = relationship("BusinessProfile")
    reporter = relationship("User", foreign_keys=[reporter_id], lazy="joined")


class FlagTarget(str, enum.Enum):
    business = "business"
    review = "review"
    offer = "offer"
    campaign = "campaign"
    user = "user"


class FlagLabel(str, enum.Enum):
    spam = "spam"
    scam = "scam"
    adult = "adult"
    offensive = "offensive"
    prohibited = "prohibited"
    fake_reviews = "fake_reviews"
    duplicate = "duplicate"


class FlagStatus(str, enum.Enum):
    open = "open"
    actioned = "actioned"  # an admin upheld it
    dismissed = "dismissed"  # an admin decided it was fine
    cleared = "cleared"  # the content was edited and no longer matches the rule


class ModerationFlag(Base):
    """A match from the automatic rules (the design's "Spam" section)."""

    __tablename__ = "moderation_flags"
    __table_args__ = (Index("ix_moderation_flags_target", "target_type", "target_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    target_type: Mapped[FlagTarget] = mapped_column(
        Enum(FlagTarget, name="flag_target", native_enum=False, length=16)
    )
    target_id: Mapped[int] = mapped_column(Integer)
    # The business the content belongs to or is about, for grouping and verification.
    business_id: Mapped[int | None] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), nullable=True, index=True
    )
    # The account responsible for the content (the author, or the business's owner).
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    rule: Mapped[str] = mapped_column(String(40))
    label: Mapped[FlagLabel] = mapped_column(
        Enum(FlagLabel, name="flag_label", native_enum=False, length=16)
    )
    # Why it was flagged, e.g. "Asks for payment in advance (JazzCash)".
    detail: Mapped[str] = mapped_column(String(300))
    # The matching text in context, so the admin needn't open the content.
    excerpt: Mapped[str] = mapped_column(String(300), default="")
    status: Mapped[FlagStatus] = mapped_column(
        Enum(FlagStatus, name="flag_status", native_enum=False, length=16),
        default=FlagStatus.open,
        server_default=text("'open'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )


class ActionKind(str, enum.Enum):
    # verification (SDD Algorithm 9)
    auto_verify = "auto_verify"  # the automatic checks passed
    refer = "refer"  # the checks passed except a report or flag: an admin decides
    unverify = "unverify"  # the name or location changed, so a new storefront photo is due
    approve = "approve"
    reject = "reject"
    request_info = "request_info"
    revoke = "revoke"
    review_requested = "review_requested"  # the owner asked for another look
    # content (SDD Algorithm 10)
    remove_review = "remove_review"
    close_conversation = "close_conversation"
    deactivate_offer = "deactivate_offer"
    unpublish_campaign = "unpublish_campaign"
    suspend_business = "suspend_business"
    reinstate_business = "reinstate_business"
    dismiss_report = "dismiss_report"
    dismiss_flag = "dismiss_flag"
    # accounts
    warn_user = "warn_user"
    suspend_user = "suspend_user"
    ban_user = "ban_user"
    lift_suspension = "lift_suspension"


class ModerationAction(Base):
    """One entry in the audit log."""

    __tablename__ = "moderation_actions"

    id: Mapped[int] = mapped_column(primary_key=True)
    # None: done by the automatic checks.
    admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    action: Mapped[ActionKind] = mapped_column(
        Enum(ActionKind, name="moderation_action_kind", native_enum=False, length=32), index=True
    )
    # What was acted on: "business", "review", "conversation", "offer", "campaign",
    # "user" or "flag".
    target_type: Mapped[str] = mapped_column(String(16))
    target_id: Mapped[int] = mapped_column(Integer)
    # The account the action affects (the author, the owner or the user acted on).
    subject_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    reason: Mapped[ModerationReason | None] = mapped_column(
        Enum(ModerationReason, name="moderation_reason", native_enum=False, length=16),
        nullable=True,
    )
    note: Mapped[str] = mapped_column(String(1000), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )

    admin = relationship("User", foreign_keys=[admin_id], lazy="joined")
