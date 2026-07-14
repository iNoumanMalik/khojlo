from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SavedList(Base):
    """A named collection of saved businesses (e.g. "Date night", "Coffee tour")."""

    __tablename__ = "saved_lists"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    tone: Mapped[str] = mapped_column(String(16), default="gold")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    user = relationship("User", back_populates="saved_lists")
    items = relationship(
        "SavedBusiness", back_populates="saved_list", cascade="all, delete-orphan"
    )


class SavedBusiness(Base):
    __tablename__ = "saved_businesses"
    __table_args__ = (UniqueConstraint("list_id", "business_id", name="uq_list_business"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    list_id: Mapped[int] = mapped_column(
        ForeignKey("saved_lists.id", ondelete="CASCADE"), index=True
    )
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    saved_list = relationship("SavedList", back_populates="items")
    business = relationship("BusinessProfile")


class BusinessView(Base):
    """One row per profile view — powers the weekly analytics chart."""

    __tablename__ = "business_views"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    viewer_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )


class Review(Base):
    """Stub review model — seeded with mock data to feed the prototype Reviews screen."""

    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    author_name: Mapped[str] = mapped_column(String(120), default="")
    author_tone: Mapped[str] = mapped_column(String(16), default="gold")
    rating: Mapped[int] = mapped_column(Integer, default=5)
    body: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
