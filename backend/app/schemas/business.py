from pydantic import BaseModel, ConfigDict, Field

from app.models.business import OfferStatus


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
    price: str = ""


class HoursIn(BaseModel):
    day_of_week: int = Field(ge=0, le=6)
    opens: str = "09:00"
    closes: str = "17:00"
    is_closed: bool = False


# ─────────────── business ───────────────
class BusinessBase(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    tagline: str = ""
    description: str = ""
    tone: str = "gold"
    address: str = ""
    latitude: float | None = None
    longitude: float | None = None
    price_level: str = "$$"
    images: list[str] = Field(default_factory=list)
    category_id: int | None = None


class BusinessCreate(BusinessBase):
    services: list[ServiceIn] = Field(default_factory=list)
    hours: list[HoursIn] = Field(default_factory=list)


class BusinessUpdate(BaseModel):
    name: str | None = None
    tagline: str | None = None
    description: str | None = None
    tone: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    price_level: str | None = None
    images: list[str] | None = None
    category_id: int | None = None
    is_published: bool | None = None


class ServiceOut(ServiceIn):
    model_config = ConfigDict(from_attributes=True)
    id: int


class HoursOut(HoursIn):
    model_config = ConfigDict(from_attributes=True)
    id: int


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
