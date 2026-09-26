import enum
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class OfferStatus(str, enum.Enum):
    active = "Active"
    scheduled = "Scheduled"
    ended = "Ended"


# The catch-all category; its businesses describe themselves in `custom_category`.
OTHER_CATEGORY = "other"


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    # visual tone used by the design system (gold/plum/emerald/coral/ink)
    tone: Mapped[str] = mapped_column(String(16), default="gold")
    emoji: Mapped[str] = mapped_column(String(16), default="")
    # Heading the category is listed under in pickers ("Food & Drink", "Services", ...).
    group_name: Mapped[str] = mapped_column(String(40), default="")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # Extra words search should match, e.g. local terms: "darzi, stitching" for tailors.
    keywords: Mapped[str] = mapped_column(Text, default="")

    businesses = relationship("BusinessProfile", back_populates="category")

    @property
    def is_other(self) -> bool:
        return self.slug == OTHER_CATEGORY


class BusinessProfile(Base):
    __tablename__ = "businesses"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id"), nullable=True, index=True
    )

    name: Mapped[str] = mapped_column(String(160), nullable=False)
    # What kind of business it is when the category is "Other", e.g. "Calligraphy studio".
    custom_category: Mapped[str | None] = mapped_column(String(60), nullable=True)
    tagline: Mapped[str] = mapped_column(String(200), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    tone: Mapped[str] = mapped_column(String(16), default="gold")

    address: Mapped[str] = mapped_column(String(255), default="")
    phone: Mapped[str | None] = mapped_column(String(24), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    price_level: Mapped[str] = mapped_column(String(8), default="$$")
    # Optional price range in PKR (Module 4 budget filter + price comparison).
    # Either end may be missing: "from Rs 800" or "up to Rs 2,500".
    price_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    price_max: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Legacy, unused: photos live in `business_photos`. Kept so builds from before photo
    # support keep working against the shared database.
    images: Mapped[list] = mapped_column(JSON, default=list)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    # denormalized engagement counters kept fresh for fast feed / dashboard reads
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    save_count: Mapped[int] = mapped_column(Integer, default=0)
    rating: Mapped[float] = mapped_column(Float, default=0.0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )

    owner = relationship("User", back_populates="businesses")
    category = relationship("Category", back_populates="businesses")
    services = relationship("Service", back_populates="business", cascade="all, delete-orphan")
    hours = relationship("OpeningHours", back_populates="business", cascade="all, delete-orphan")
    offers = relationship("Offer", back_populates="business", cascade="all, delete-orphan")
    photos = relationship(
        "BusinessPhoto",
        back_populates="business",
        cascade="all, delete-orphan",
        order_by="BusinessPhoto.position",
    )

    @property
    def cover(self):
        """The cover photo's media row, or None (cards then use the tone gradient)."""
        return self.photos[0].media if self.photos else None

    @property
    def category_label(self) -> str | None:
        """What cards show: the owner's own description for "Other", else the category."""
        if self.category is None:
            return None
        if self.category.is_other and self.custom_category:
            return self.custom_category
        return self.category.name


class Service(Base):
    __tablename__ = "services"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    # Display text, e.g. "Rs 650". `price_amount` is the same price as a number (PKR).
    price: Mapped[str] = mapped_column(String(40), default="")
    price_amount: Mapped[int | None] = mapped_column(Integer, nullable=True)

    business = relationship("BusinessProfile", back_populates="services")


class OpeningHours(Base):
    __tablename__ = "opening_hours"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    day_of_week: Mapped[int] = mapped_column(Integer)  # 0 = Monday
    opens: Mapped[str] = mapped_column(String(8), default="09:00")
    closes: Mapped[str] = mapped_column(String(8), default="17:00")
    is_closed: Mapped[bool] = mapped_column(Boolean, default=False)

    business = relationship("BusinessProfile", back_populates="hours")


class Offer(Base):
    __tablename__ = "offers"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    starts_on: Mapped[str] = mapped_column(String(40), default="")
    ends_on: Mapped[str] = mapped_column(String(40), default="")
    status: Mapped[OfferStatus] = mapped_column(
        Enum(OfferStatus, native_enum=False, length=16), default=OfferStatus.active
    )
    tone: Mapped[str] = mapped_column(String(16), default="emerald")
    views: Mapped[int] = mapped_column(Integer, default=0)
    redemptions: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    business = relationship("BusinessProfile", back_populates="offers")
