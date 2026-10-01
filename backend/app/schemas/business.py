import re
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.business import DealType
from app.schemas.media import PhotoOut

# Upper bound for any PKR amount we accept (a sanity limit, not a business rule).
MAX_PRICE_PKR = 10_000_000
# Cover + gallery.
MAX_BUSINESS_PHOTOS = 10

PriceLevel = Literal["$", "$$", "$$$"]

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


def _check_price_order(price_min: int | None, price_max: int | None) -> None:
    if price_min is not None and price_max is not None and price_min > price_max:
        raise ValueError("Minimum price can't be higher than the maximum price")


def _check_coordinates(latitude: float | None, longitude: float | None) -> None:
    """SRS BR-7: valid GPS coordinates. (0, 0) is what a failed GPS fix reports, not a place."""
    if (latitude is None) != (longitude is None):
        raise ValueError("Provide both latitude and longitude, or neither")
    if latitude == 0 and longitude == 0:
        raise ValueError("That location (0, 0) isn't valid. Set the pin on the map again.")


_PHONE_CHARS = re.compile(r"^\+?[\d\s\-()]+$")


def normalize_phone(value: str | None) -> str | None:
    """Trim a phone number and check it looks like one; an empty value clears it."""
    if value is None:
        return None
    value = " ".join(value.split())
    if not value:
        return None
    digits = sum(ch.isdigit() for ch in value)
    if len(value) > 24 or not _PHONE_CHARS.match(value) or not 7 <= digits <= 15:
        raise ValueError("Enter a valid phone number, e.g. 0300 1234567 or +92 300 1234567")
    return value


def normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = " ".join(value.split())
    return value or None


def check_photo_keys(keys: list[str]) -> list[str]:
    if len(keys) > MAX_BUSINESS_PHOTOS:
        raise ValueError(f"A business can have up to {MAX_BUSINESS_PHOTOS} photos")
    if len(keys) != len(set(keys)):
        raise ValueError("Each photo can only appear once")
    return keys


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
    emoji: str = ""
    group_name: str = ""
    sort_order: int = 0
    # The catch-all "Other" category: owners describe their business in `custom_category`.
    is_other: bool = False
    # Published businesses in this category (only filled by GET /categories).
    business_count: int = 0


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
    phone: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    price_level: PriceLevel = "$$"
    price_min: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    price_max: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    category_id: int | None = None
    # Required when the category is "Other" (checked against the category in the endpoint).
    custom_category: str | None = Field(default=None, max_length=60)

    _phone = field_validator("phone")(normalize_phone)
    _custom = field_validator("custom_category")(normalize_optional_text)

    @model_validator(mode="after")
    def _consistent(self) -> "BusinessBase":
        _check_price_order(self.price_min, self.price_max)
        _check_coordinates(self.latitude, self.longitude)
        return self


class BusinessCreate(BusinessBase):
    services: list[ServiceIn] = Field(default_factory=list)
    hours: list[HoursIn] = Field(default_factory=list)
    # Keys from POST /media, in order; the first is the cover.
    photos: list[str] = Field(default_factory=list)

    _photos = field_validator("photos")(check_photo_keys)

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
    phone: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    price_level: PriceLevel | None = None
    price_min: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    price_max: int | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    category_id: int | None = None
    custom_category: str | None = Field(default=None, max_length=60)
    is_published: bool | None = None

    _phone = field_validator("phone")(normalize_phone)
    _custom = field_validator("custom_category")(normalize_optional_text)


class PhotosReplace(BaseModel):
    """The full, ordered gallery (keys from POST /media); the first photo is the cover."""

    photos: list[str] = Field(default_factory=list)

    _photos = field_validator("photos")(check_photo_keys)


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
    """A special offer (UC-11). `is_active` false keeps it a draft."""

    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=1000)
    deal_type: DealType = DealType.other
    deal_value: float | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    deal_text: str = Field(default="", max_length=40)
    start_date: date
    end_date: date | None = None
    terms: str = Field(default="", max_length=2000)
    is_active: bool = False
    tone: str = Field(default="emerald", max_length=16)


class OfferUpdate(BaseModel):
    """Partial update: omitted fields stay; `end_date: null` makes it open-ended."""

    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    deal_type: DealType | None = None
    deal_value: float | None = Field(default=None, ge=0, le=MAX_PRICE_PKR)
    deal_text: str | None = Field(default=None, max_length=40)
    start_date: date | None = None
    end_date: date | None = None
    terms: str | None = Field(default=None, max_length=2000)
    is_active: bool | None = None
    tone: str | None = Field(default=None, max_length=16)


class OfferOut(BaseModel):
    id: int
    title: str
    description: str = ""
    deal_type: DealType
    deal_value: float | None = None
    deal_text: str = ""
    # Badge text built from the deal: "20% OFF", "BUY 1 GET 1".
    deal_label: str
    start_date: date
    end_date: date | None = None
    terms: str = ""
    is_active: bool
    # draft | scheduled | active | expired (from is_active and the dates).
    status: str
    tone: str = "emerald"
    views: int = 0
    redemptions: int = 0


class CampaignRef(BaseModel):
    """The business's live campaign, for the "Active promotion" badge on cards."""

    id: int
    name: str


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
    # ── photos & categories ──
    # None: no photos yet, so clients draw the tone gradient.
    cover: PhotoOut | None = None
    # What to show as the business type: the owner's own words for "Other".
    category_label: str | None = None
    # ── Offers & campaigns: the live campaign behind the "Active promotion" badge ──
    active_campaign: CampaignRef | None = None
    # ── Module 6: where to put the map pin (None: no location set) ──
    latitude: float | None = None
    longitude: float | None = None
    # ── Module 8: taken down by a moderator (only its owner still sees it) ──
    is_suspended: bool = False


class BusinessDetail(BusinessCard):
    description: str
    category_id: int | None = None
    custom_category: str | None = None
    phone: str | None = None
    # Cover first, then the gallery.
    photos: list[PhotoOut] = Field(default_factory=list)
    view_count: int
    services: list[ServiceOut] = Field(default_factory=list)
    hours: list[HoursOut] = Field(default_factory=list)
    offers: list[OfferOut] = Field(default_factory=list)
    is_saved: bool = False
    # The viewer owns this business (the app shows "View messages" instead of "Message").
    is_owner: bool = False


# ─────────────── analytics ───────────────
class WeeklyPoint(BaseModel):
    label: str  # M/T/W...
    value: int


class BusinessAnalytics(BaseModel):
    business_id: int
    profile_views: int
    saves: int
    # Customer messages received in the last 7 days, and how many are still unread.
    messages: int
    unread_messages: int = 0
    rating: float
    review_count: int
    weekly_views: list[WeeklyPoint]
