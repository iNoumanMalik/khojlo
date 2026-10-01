"""Promotional campaign request and response bodies."""
from datetime import date

from pydantic import BaseModel, Field

from app.schemas.business import BusinessCard, OfferOut, ServiceOut
from app.schemas.media import PhotoOut

MAX_LINKED = 10


class CampaignIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=1500)
    message: str = Field(default="", max_length=160)
    # Key from POST /media; None for the business's colour gradient.
    banner: str | None = None
    start_date: date
    end_date: date
    terms: str = Field(default="", max_length=2000)
    # Existing offers to promote, in display order (never copies of them).
    offer_ids: list[int] = Field(default_factory=list, max_length=MAX_LINKED)
    # Services to feature, from the business's service list.
    service_ids: list[int] = Field(default_factory=list, max_length=MAX_LINKED)
    is_published: bool = False
    notify_savers: bool = False


class CampaignUpdate(BaseModel):
    """Partial update: omitted fields stay as they are; `banner: null` removes the image."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=1500)
    message: str | None = Field(default=None, max_length=160)
    banner: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    terms: str | None = Field(default=None, max_length=2000)
    offer_ids: list[int] | None = Field(default=None, max_length=MAX_LINKED)
    service_ids: list[int] | None = Field(default=None, max_length=MAX_LINKED)
    is_published: bool | None = None
    notify_savers: bool | None = None


class CampaignBanner(BaseModel):
    """A live campaign as a Home banner."""

    id: int
    name: str
    message: str = ""
    banner: PhotoOut | None = None
    tone: str = "gold"
    start_date: date
    end_date: date
    business_id: int
    business_name: str
    offer_count: int
    # The first offer's badge text, e.g. "20% OFF".
    top_deal: str | None = None


class CampaignOut(BaseModel):
    id: int
    name: str
    description: str = ""
    message: str = ""
    banner: PhotoOut | None = None
    start_date: date
    end_date: date
    terms: str = ""
    is_published: bool
    notify_savers: bool = False
    # draft | scheduled | active | expired (from is_published and the dates).
    status: str
    # Customers see it right now (published, in its dates, with a live offer).
    is_visible: bool
    # Customers get only the live offers; the owner gets every linked offer.
    offers: list[OfferOut]
    services: list[ServiceOut] = []
    business: BusinessCard
