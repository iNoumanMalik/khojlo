"""Module 9 — chat between customers and businesses (SRS FR-23–FR-25, UC-13, UC-14;
SDD `Message`, ER diagram `MESSAGE`).

A conversation belongs to one customer and one business. Only customers start them; the
business's owner replies on its behalf (BR-16). How far each side has read is kept on the
conversation, which gives both the unread counts and the "Seen" receipts.
"""
import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        UniqueConstraint("customer_id", "business_id", name="uq_conversation_customer_business"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    # None until the first message; conversations without messages aren't listed.
    last_message_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    # The newest message each side has seen.
    customer_last_read_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    business_last_read_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Module 8: the side that blocked the other ("customer" / "business"). Nobody can send
    # while it's blocked; only the blocker can unblock.
    blocked_by: Mapped[str | None] = mapped_column(String(16), nullable=True)
    blocked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Closed by a moderator after a report was upheld: readable, but no new messages.
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    customer = relationship("User", lazy="joined")
    business = relationship("BusinessProfile", lazy="joined")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        # A retried send carries the same client id, so it can't create a duplicate.
        UniqueConstraint("conversation_id", "client_id", name="uq_message_client_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    # Sent by the business (its owner) rather than the customer.
    from_business: Mapped[bool] = mapped_column(Boolean, default=False)
    body: Mapped[str] = mapped_column(Text, default="")
    media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media.id", ondelete="SET NULL"), nullable=True
    )
    client_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )

    photo = relationship("Media", lazy="joined")


class ConversationReportReason(str, enum.Enum):
    spam = "spam"
    harassment = "harassment"
    scam = "scam"
    other = "other"


class ConversationReportStatus(str, enum.Enum):
    open = "open"  # waiting for an admin (Module 8)
    removed = "removed"
    dismissed = "dismissed"


class ConversationReport(Base):
    """A participant's report of a conversation, for the Module 8 moderation queue."""

    __tablename__ = "conversation_reports"
    __table_args__ = (
        UniqueConstraint("conversation_id", "reporter_id", name="uq_conversation_report"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), index=True
    )
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    reason: Mapped[ConversationReportReason] = mapped_column(
        Enum(ConversationReportReason, name="conversation_report_reason", native_enum=False,
             length=16)
    )
    note: Mapped[str] = mapped_column(String(500), default="")
    status: Mapped[ConversationReportStatus] = mapped_column(
        Enum(ConversationReportStatus, name="conversation_report_status", native_enum=False,
             length=16),
        default=ConversationReportStatus.open,
        server_default=text("'open'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
