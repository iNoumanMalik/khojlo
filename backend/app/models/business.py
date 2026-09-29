import enum
from datetime import date, datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
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


class DealType(str, enum.Enum):
    """What kind of deal an offer is; `Offer.deal_value` / `deal_text` complete it."""

    percent_off = "percent_off"  # value: 1–100 → "20% OFF"
    amount_off = "amount_off"  # value: rupees → "Rs 500 OFF"
    bogo = "bogo"  # "BUY 1 GET 1"
    free_item = "free_item"  # text: what's free → "FREE DESSERT"
    other = "other"  # text: the owner's own short label


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
    offers = relationship(
        "Offer", back_populates="business", cascade="all, delete-orphan", order_by="Offer.id"
    )
    campaigns = relationship(
        "Campaign", back_populates="business", cascade="all, delete-orphan",
        order_by="Campaign.id",
    )
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
    """A special offer: the deal itself (SRS FR-10, UC-11; SDD `Offer`).

    The owner switches it on or off (`is_active`, SDD ER `is_active`); whether it's draft,
    scheduled, active or expired follows from that and the dates — see
    `promotion_service.offer_state`.
    """

    __tablename__ = "offers"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    deal_type: Mapped[DealType] = mapped_column(
        Enum(DealType, native_enum=False, length=16), default=DealType.other
    )
    # The SDD's `discount`: percent for percent_off, rupees for amount_off.
    deal_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    deal_text: Mapped[str] = mapped_column(String(60), default="")
    start_date: Mapped[date] = mapped_column(Date)
    # None: open-ended ("15% off for students").
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    terms: Mapped[str] = mapped_column(Text, default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    tone: Mapped[str] = mapped_column(String(16), default="emerald")
    views: Mapped[int] = mapped_column(Integer, default=0)
    redemptions: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # When people who saved the business were told it went live (once per offer).
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    business = relationship("BusinessProfile", back_populates="offers")
