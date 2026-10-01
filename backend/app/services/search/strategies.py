"""Search strategies — the SDD's Strategy pattern (class diagram, §4.1).

`SearchStrategy` is the interface; `KeywordSearch`, `CategorySearch` and `LocationSearch`
are the three implementations named in the SDD. The filter strategies (price, rating,
offers, verified, open now) follow the same interface, so `SearchEngine` can combine any
of them for one request.

Each strategy narrows candidates twice:
* `apply()` adds SQL conditions (cheap, runs in the database);
* `matches()` confirms in Python what SQL can't express portably across SQLite and
  Postgres — accent-insensitive text, exact great-circle distance, and "open now".
"""
from __future__ import annotations

import math
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import Select, and_, exists, func, or_
from sqlalchemy.orm import InstrumentedAttribute

from app.models.business import BusinessProfile, Category, Service
from app.services.promotion_service import live_offers, local_today, offer_may_be_live
from app.services.business_service import distance_km
from app.services.hours import is_open_now
from app.services.search.criteria import MapBounds, SearchCriteria
from app.services.search.text import LIKE_ESCAPE, fold, like_pattern, tokenize

_KM_PER_DEGREE_LAT = 111.32
# Stand-in for an open-ended price range ("from Rs 800") in SQL comparisons.
_NO_UPPER_PRICE = 2**31 - 1


# ─────────────── shared per-search state ───────────────
@dataclass(frozen=True)
class FoldedText:
    """A business's searchable text, folded once per search (lowercase, no accents)."""

    name: str
    category: str
    services: tuple[str, ...]
    tagline: str
    address: str
    description: str

    def contains(self, token: str) -> bool:
        return (
            token in self.name
            or token in self.category
            or token in self.tagline
            or token in self.address
            or token in self.description
            or any(token in s for s in self.services)
        )


class SearchContext:
    """Scratch space shared by the strategies and the ranker during one search."""

    def __init__(self, criteria: SearchCriteria, now: datetime):
        self.criteria = criteria
        self.now = now
        self._text: dict[int, FoldedText] = {}
        self._distance: dict[int, float | None] = {}
        self._open: dict[int, bool | None] = {}

    def text(self, b: BusinessProfile) -> FoldedText:
        if b.id not in self._text:
            category = " ".join(
                part for part in (
                    b.category.name if b.category else "",
                    b.category.keywords if b.category else "",
                    b.custom_category or "",
                ) if part
            )
            self._text[b.id] = FoldedText(
                name=fold(b.name),
                category=fold(category),
                services=tuple(fold(s.name) for s in b.services),
                tagline=fold(b.tagline),
                address=fold(b.address),
                description=fold(b.description),
            )
        return self._text[b.id]

    def distance(self, b: BusinessProfile) -> float | None:
        """Exact distance from the searcher, or None without an origin or coordinates."""
        if b.id not in self._distance:
            origin = self.criteria.origin
            if origin is None or b.latitude is None or b.longitude is None:
                self._distance[b.id] = None
            else:
                self._distance[b.id] = distance_km(origin[0], origin[1], b.latitude, b.longitude)
        return self._distance[b.id]

    def is_open(self, b: BusinessProfile) -> bool | None:
        if b.id not in self._open:
            self._open[b.id] = is_open_now(b.hours, self.now)
        return self._open[b.id]


# ─────────────── the interface ───────────────
class SearchStrategy(ABC):
    """SDD `SearchStrategy`: narrows the set of businesses for one aspect of a search."""

    def apply(self, stmt: Select) -> Select:
        """Add SQL conditions. The statement already joins `Category` (outer join)."""
        return stmt

    @abstractmethod
    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        """Final in-memory check for one candidate."""


# ─────────────── the SDD's three strategies ───────────────
class KeywordSearch(SearchStrategy):
    """Matches keywords against name, tagline, description, address, category and services.

    "Category" covers the category's name and search keywords (local terms such as
    "darzi") plus the owner's own description for businesses listed under "Other".

    With `match_all` every token must match somewhere (precise). Without it, any token
    may match — the engine's fallback when a multi-word search finds nothing.
    """

    def __init__(self, keyword: str, *, match_all: bool = True):
        self.keyword = keyword
        self.tokens = tokenize(keyword)
        self.match_all = match_all

    @staticmethod
    def _ilike(column: InstrumentedAttribute, pattern: str):
        return column.ilike(pattern, escape=LIKE_ESCAPE)

    def _token_clause(self, token: str):
        pattern = like_pattern(token)
        service_match = exists().where(
            Service.business_id == BusinessProfile.id, self._ilike(Service.name, pattern)
        )
        return or_(
            self._ilike(BusinessProfile.name, pattern),
            self._ilike(BusinessProfile.tagline, pattern),
            self._ilike(BusinessProfile.description, pattern),
            self._ilike(BusinessProfile.address, pattern),
            self._ilike(Category.name, pattern),
            self._ilike(Category.keywords, pattern),
            self._ilike(BusinessProfile.custom_category, pattern),
            service_match,
        )

    def apply(self, stmt: Select) -> Select:
        if not self.tokens:
            return stmt
        clauses = [self._token_clause(t) for t in self.tokens]
        return stmt.where(and_(*clauses) if self.match_all else or_(*clauses))

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        if not self.tokens:
            return True
        text = ctx.text(business)
        hits = (text.contains(t) for t in self.tokens)
        return all(hits) if self.match_all else any(hits)


class CategorySearch(SearchStrategy):
    """Restricts results to one or more category slugs."""

    def __init__(self, categories: list[str]):
        self.categories = [c.strip().lower() for c in categories if c.strip()]

    def apply(self, stmt: Select) -> Select:
        return stmt.where(Category.slug.in_(self.categories)) if self.categories else stmt

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        if not self.categories:
            return True
        return business.category is not None and business.category.slug in self.categories


class LocationSearch(SearchStrategy):
    """Keeps businesses within `radius_km` of (latitude, longitude).

    SQL applies a bounding box; Python then checks the exact great-circle distance.
    Businesses without coordinates can't be placed, so they're excluded.
    """

    def __init__(self, latitude: float, longitude: float, radius_km: float):
        self.latitude = latitude
        self.longitude = longitude
        self.radius_km = radius_km

    def apply(self, stmt: Select) -> Select:
        dlat = self.radius_km / _KM_PER_DEGREE_LAT
        cos_lat = max(math.cos(math.radians(self.latitude)), 0.01)
        dlng = self.radius_km / (_KM_PER_DEGREE_LAT * cos_lat)
        return stmt.where(
            BusinessProfile.latitude.is_not(None),
            BusinessProfile.longitude.is_not(None),
            BusinessProfile.latitude.between(self.latitude - dlat, self.latitude + dlat),
            BusinessProfile.longitude.between(self.longitude - dlng, self.longitude + dlng),
        )

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        if business.latitude is None or business.longitude is None:
            return False
        d = distance_km(self.latitude, self.longitude, business.latitude, business.longitude)
        return d <= self.radius_km


class AreaSearch(SearchStrategy):
    """Module 6: keeps businesses inside the visible map area (SRS FR-12).

    Businesses without coordinates can't be drawn on a map (BR-7), so they're excluded.
    """

    def __init__(self, bounds: MapBounds):
        self.bounds = bounds

    def apply(self, stmt: Select) -> Select:
        b = self.bounds
        return stmt.where(
            BusinessProfile.latitude.between(b.south, b.north),
            BusinessProfile.longitude.between(b.west, b.east),
        )

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        if business.latitude is None or business.longitude is None:
            return False
        return self.bounds.contains(business.latitude, business.longitude)


# ─────────────── filter strategies ───────────────
class PriceFilter(SearchStrategy):
    """Price tier ($/$$/$$$) and/or a PKR budget.

    A budget keeps businesses whose price range overlaps it. A missing lower end counts
    as Rs 0 and a missing upper end as open-ended; businesses with no range at all are
    excluded while a budget is set.
    """

    def __init__(
        self, levels: list[str], min_price: int | None = None, max_price: int | None = None
    ):
        self.levels = levels
        self.min_price = min_price
        self.max_price = max_price

    @property
    def _has_budget(self) -> bool:
        return self.min_price is not None or self.max_price is not None

    def apply(self, stmt: Select) -> Select:
        b = BusinessProfile
        if self.levels:
            stmt = stmt.where(b.price_level.in_(self.levels))
        if self._has_budget:
            stmt = stmt.where(or_(b.price_min.is_not(None), b.price_max.is_not(None)))
        if self.max_price is not None:
            stmt = stmt.where(func.coalesce(b.price_min, 0) <= self.max_price)
        if self.min_price is not None:
            stmt = stmt.where(func.coalesce(b.price_max, _NO_UPPER_PRICE) >= self.min_price)
        return stmt

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        if self.levels and business.price_level not in self.levels:
            return False
        if not self._has_budget:
            return True
        low, high = business.price_min, business.price_max
        if low is None and high is None:
            return False
        if self.max_price is not None and (low or 0) > self.max_price:
            return False
        if self.min_price is not None and high is not None and high < self.min_price:
            return False
        return True


class RatingFilter(SearchStrategy):
    def __init__(self, min_rating: float):
        self.min_rating = min_rating

    def apply(self, stmt: Select) -> Select:
        return stmt.where(BusinessProfile.rating >= self.min_rating)

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        return (business.rating or 0) >= self.min_rating


class OfferFilter(SearchStrategy):
    """Businesses with at least one live offer (switched on and within its dates)."""

    def apply(self, stmt: Select) -> Select:
        return stmt.where(exists().where(offer_may_be_live()))

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        return bool(live_offers(business.offers, local_today(ctx.now)))


class VerifiedFilter(SearchStrategy):
    """Only businesses with the Verified badge (SRS BR-3, FR-14; Module 8 verifies them)."""

    def apply(self, stmt: Select) -> Select:
        return stmt.where(BusinessProfile.is_verified.is_(True))

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        return bool(business.is_verified)


class OpenNowFilter(SearchStrategy):
    """Open right now in the businesses' timezone. Unknown hours don't count as open."""

    def matches(self, business: BusinessProfile, ctx: SearchContext) -> bool:
        return ctx.is_open(business) is True


def strategies_for(criteria: SearchCriteria, *, match_all: bool = True) -> list[SearchStrategy]:
    """Pick the strategies a request needs, cheapest-to-evaluate first."""
    strategies: list[SearchStrategy] = []
    if criteria.categories:
        strategies.append(CategorySearch(criteria.categories))
    if criteria.verified_only:
        strategies.append(VerifiedFilter())
    if criteria.min_rating is not None:
        strategies.append(RatingFilter(criteria.min_rating))
    if criteria.price_levels or criteria.min_price is not None or criteria.max_price is not None:
        strategies.append(
            PriceFilter(criteria.price_levels, criteria.min_price, criteria.max_price)
        )
    if criteria.has_offer:
        strategies.append(OfferFilter())
    if criteria.bounds is not None:
        strategies.append(AreaSearch(criteria.bounds))
    if criteria.origin is not None and criteria.radius_km is not None:
        strategies.append(LocationSearch(criteria.lat, criteria.lng, criteria.radius_km))
    if criteria.tokens:
        strategies.append(KeywordSearch(criteria.query, match_all=match_all))
    if criteria.open_now:
        strategies.append(OpenNowFilter())
    return strategies
