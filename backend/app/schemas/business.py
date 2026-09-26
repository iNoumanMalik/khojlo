import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.business import OfferStatus

# Upper bound for any PKR amount we accept (a sanity limit, not a business rule).
MAX_PRICE_PKR = 10_000_000

PriceLevel = Literal["$", "$$", "$$$"]

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


def _check_price_order(price_min: int | None, price_max: int | None) -> None:
    if price_min is not None and price_max is not None and price_min > price_max:
        raise ValueError("Minimum price can't be higher than the maximum price")


def _check_coordinates(latitude: float | None, longitude: float | None) -> None:
    if (latitude is None) != (longitude is None):
        raise ValueError("Provide both latitude and longitude, or neither")


def check_unique_days(hours: list["HoursIn"]) -> None:
    days = [h.day_of_week for h in hours]
    if len(days) != len(set(days)):
        raise ValueError("Each day of the week can only appear once in opening hours")


# ─────────────── categories ───────────────
class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    tone: str


# ─────────────── nested inputs ───────────────
class ServiceIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    # Display text, e.g. "Rs 650".
    price: str = Field(default="", max_length=40)
    # The same price as a number in PKR (optional).
    price_amount: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)


class HoursIn(BaseModel):
    day_of_week: int = Field(ge=0, le=6, description="0 = Monday … 6 = Sunday")
    opens: str = Field(default="09:00", description="24-hour HH:MM")
    closes: str = Field(
        default="17:00",
        description="24-hour HH:MM. Earlier than `opens` means it closes after midnight; "
        "equal to `opens` means open 24 hours.",
    )
    is_closed: bool = False

    @field_validator("opens", "closes")
    @classmethod
    def _hhmm(cls, v: str) -> str:
        v = v.strip()
        if not _HHMM.match(v):
            raise ValueError("Time must be in 24-hour HH:MM format, e.g. 09:00")
        return v


# ─────────────── business ───────────────
class BusinessBase(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    tagline: str = Field(default="", max_length=200)
    description: str = ""
    tone: str = "gold"
    address: str = Field(default="", max_length=255)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    price_level: PriceLevel = "$$"
    price_min: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    price_max: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    images: list[str] = Field(default_factory=list)
    category_id: int | None = None

    @model_validator(mode="after")
    def _consistent(self) -> "BusinessBase":
        _check_price_order(self.price_min, self.price_max)
        _check_coordinates(self.latitude, self.longitude)
        return self


class BusinessCreate(BusinessBase):
    services: list[ServiceIn] = Field(default_factory=list)
    hours: list[HoursIn] = Field(default_factory=list)

    @model_validator(mode="after")
    def _unique_days(self) -> "BusinessCreate":
        check_unique_days(self.hours)
        return self


class BusinessUpdate(BaseModel):
    """Partial update. Cross-field rules (price order, lat/lng pairs) are checked
    against the merged record in the endpoint, since only one side may be sent."""

    name: str | None = Field(default=None, min_length=1, max_length=160)
    tagline: str | None = Field(default=None, max_length=200)
    description: str | None = None
    tone: str | None = None
    address: str | None = Field(default=None, max_length=255)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    price_level: PriceLevel | None = None
    price_min: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    price_max: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    images: list[str] | None = None
    category_id: int | None = None
    is_published: bool | None = None


class HoursReplace(BaseModel):
    """Full replacement of a business's weekly opening hours."""

    hours: list[HoursIn] = Field(default_factory=list, max_length=7)

    @model_validator(mode="after")
    def _unique_days(self) -> "HoursReplace":
        check_unique_days(self.hours)
        return self


class ServiceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    price: str = ""
    price_amount: int | None = None


class HoursOut(BaseModel):
    # Deliberately without the input validators: stored rows are served as-is.
    model_config = ConfigDict(from_attributes=True)

    id: int
    day_of_week: int
    opens: str
    closes: str
    is_closed: bool


class OfferIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    starts_on: str = ""
    ends_on: str = ""
    status: OfferStatus = OfferStatus.active
    tone: str = "emerald"


class OfferOut(OfferIn):
    model_config = ConfigDict(from_attributes=True)
    id: int
    views: int
    redemptions: int


class BusinessCard(BaseModel):
    """Compact representation used across the feed, search and saved lists."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    tagline: str
    tone: str
    address: str
    price_level: str
    rating: float
    review_count: int
    save_count: int
    is_verified: bool
    category_name: str | None = None
    distance_km: float | None = None
    # ── Module 4 additions (all optional / additive) ──
    category_slug: str | None = None
    price_min: int | None = None
    price_max: int | None = None
    # None means the business hasn't published opening hours.
    is_open_now: bool | None = None
    today_hours: str | None = None
    has_offer: bool = False
    is_new: bool = False


class BusinessDetail(BusinessCard):
    description: str
    latitude: float | None
    longitude: float | None
    images: list[str]
    view_count: int
    services: list[ServiceOut] = Field(default_factory=list)
    hours: list[HoursOut] = Field(default_factory=list)
    offers: list[OfferOut] = Field(default_factory=list)
    is_saved: bool = False


# ─────────────── analytics ───────────────
class WeeklyPoint(BaseModel):
    label: str  # M/T/W...
    value: int


class BusinessAnalytics(BaseModel):
    business_id: int
    profile_views: int
    saves: int
    messages: int
    rating: float
    review_count: int
    weekly_views: list[WeeklyPoint]
