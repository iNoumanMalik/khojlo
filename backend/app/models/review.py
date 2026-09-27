"""Module 5 — reviews and ratings (SRS FR-6, UC-7; SDD `Review`, ER diagram `REVIEW`).

A business's `rating` and `review_count` are derived from these rows (SDD Algorithm 7) and
recalculated on every change by `review_service.refresh_rating`.
"""
import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
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


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (
        CheckConstraint("rating BETWEEN 1 AND 5", name="ck_reviews_rating_range"),
        # BR-4: one review per business per user. Deleted reviews don't count, so the
        # user can write a new one after deleting theirs.
        Index(
            "uq_reviews_user_business_active",
            "user_id",
            "business_id",
            unique=True,
            postgresql_where=text("deleted_at IS NULL"),
            sqlite_where=text("deleted_at IS NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")
    # False once an admin hides it (Module 8). Hidden reviews leave lists and ratings.
    is_approved: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    # Denormalised count of helpful votes, for the "Most helpful" sort.
    helpful_count: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    # The business owner's public reply (one per review).
    owner_reply: Mapped[str | None] = mapped_column(Text, nullable=True)
    owner_reply_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )
    # Set when the author edits the rating, comment or photos ("edited").
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Soft delete, as in the SDD ER diagram.
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    business = relationship("BusinessProfile")
    author = relationship("User", lazy="joined")
    photos = relationship(
        "ReviewPhoto",
        back_populates="review",
        cascade="all, delete-orphan",
        order_by="ReviewPhoto.position",
        lazy="selectin",
    )


class ReviewPhoto(Base):
    __tablename__ = "review_photos"
    __table_args__ = (UniqueConstraint("review_id", "media_id", name="uq_review_photo"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[int] = mapped_column(ForeignKey("media.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer, default=0)

    review = relationship("Review", back_populates="photos")
    media = relationship("Media", lazy="joined")


class ReviewVote(Base):
    """A "helpful" vote: one per user per review."""

    __tablename__ = "review_votes"
    __table_args__ = (UniqueConstraint("review_id", "user_id", name="uq_review_vote"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class ReportReason(str, enum.Enum):
    spam = "spam"
    fake = "fake"
    offensive = "offensive"
    other = "other"


class ReportStatus(str, enum.Enum):
    open = "open"  # waiting for an admin (Module 8 "Flagged reviews")
    removed = "removed"  # the admin hid the review
    dismissed = "dismissed"  # the admin kept it


class ReviewReport(Base):
    """A user's report of a review (SDD Algorithm 10 "Retrieve reported content")."""

    __tablename__ = "review_reports"
    __table_args__ = (UniqueConstraint("review_id", "reporter_id", name="uq_review_report"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[ReportReason] = mapped_column(
        Enum(ReportReason, name="report_reason", native_enum=False, length=16)
    )
    note: Mapped[str] = mapped_column(String(500), default="")
    status: Mapped[ReportStatus] = mapped_column(
        Enum(ReportStatus, name="report_status", native_enum=False, length=16),
        default=ReportStatus.open,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
