"""The search request as a plain value object (SDD: `Customer.searchBusinesses(query, filters)`)."""
from __future__ import annotations

import enum
from dataclasses import dataclass, field
from typing import Any

from app.services.search.text import tokenize

PRICE_TIERS: tuple[str, ...] = ("$", "$$", "$$$")


class SortOption(str, enum.Enum):
    relevance = "relevance"  # best match; ties favour new, then near, then well-rated places
    distance = "distance"
    rating = "rating"
    price_low = "price_low"
    price_high = "price_high"
    newest = "newest"
    popular = "popular"


@dataclass
class SearchCriteria:
    query: str = ""
    categories: list[str] = field(default_factory=list)
    price_levels: list[str] = field(default_factory=list)
    min_price: int | None = None
    max_price: int | None = None
    min_rating: float | None = None
    open_now: bool = False
    has_offer: bool = False
    verified_only: bool = False
    lat: float | None = None
    lng: float | None = None
    radius_km: float | None = None
    sort: SortOption = SortOption.relevance
    limit: int = 20
    offset: int = 0

    @property
    def tokens(self) -> list[str]:
        return tokenize(self.query)

    @property
    def origin(self) -> tuple[float, float] | None:
        if self.lat is None or self.lng is None:
            return None
        return self.lat, self.lng

    def active_filters(self) -> dict[str, Any]:
        """Non-default filters, as stored with a search-history row."""
        filters: dict[str, Any] = {}
        if self.categories:
            filters["category"] = list(self.categories)
        if self.price_levels:
            filters["price"] = list(self.price_levels)
        for key in ("min_price", "max_price", "min_rating", "radius_km"):
            value = getattr(self, key)
            if value is not None:
                filters[key] = value
        for key in ("open_now", "has_offer", "verified_only"):
            if getattr(self, key):
                filters[key] = True
        if self.sort is not SortOption.relevance:
            filters["sort"] = self.sort.value
        return filters
