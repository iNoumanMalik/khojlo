"""Module 4 — search, filtering and suggestions.

Structure follows the SDD class diagram: `SearchEngine` runs `SearchStrategy`
implementations (`KeywordSearch`, `CategorySearch`, `LocationSearch`, plus filters).
"""
from app.services.search.criteria import PRICE_TIERS, SearchCriteria, SortOption
from app.services.search.engine import SearchEngine, SearchOutcome
from app.services.search.strategies import (
    CategorySearch,
    KeywordSearch,
    LocationSearch,
    OfferFilter,
    OpenNowFilter,
    PriceFilter,
    RatingFilter,
    SearchContext,
    SearchStrategy,
    VerifiedFilter,
)

__all__ = [
    "PRICE_TIERS",
    "CategorySearch",
    "KeywordSearch",
    "LocationSearch",
    "OfferFilter",
    "OpenNowFilter",
    "PriceFilter",
    "RatingFilter",
    "SearchContext",
    "SearchCriteria",
    "SearchEngine",
    "SearchOutcome",
    "SearchStrategy",
    "SortOption",
    "VerifiedFilter",
]
