from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.business import BusinessCard, ServiceOut


# ─────────────── search ───────────────
class SearchResponse(BaseModel):
    items: list[BusinessCard]
    total: int
    limit: int
    offset: int
    sort: str
    summary: str
    # True when a multi-word search found nothing and "any word" matches are shown instead.
    relaxed: bool = False


class Suggestion(BaseModel):
    type: Literal["business", "category", "service"]
    label: str
    sublabel: str | None = None
    business_id: int | None = None
    category_slug: str | None = None


class SearchHistoryItem(BaseModel):
    query: str
    created_at: datetime


# ─────────────── compare ───────────────
class CompareItem(BusinessCard):
    services: list[ServiceOut] = Field(default_factory=list)
    active_offers: list[str] = Field(default_factory=list)


class CompareHighlights(BaseModel):
    """Ids of the best business on each row. Empty when a row doesn't separate them."""

    price: list[int] = Field(default_factory=list)
    rating: list[int] = Field(default_factory=list)
    distance: list[int] = Field(default_factory=list)
    open_now: list[int] = Field(default_factory=list)
    services: list[int] = Field(default_factory=list)
    offers: list[int] = Field(default_factory=list)
    saves: list[int] = Field(default_factory=list)


class CompareResponse(BaseModel):
    items: list[CompareItem]
    highlights: CompareHighlights
