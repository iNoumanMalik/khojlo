"""Relevance scoring and sort orders (SRS UC-4 business rule: rank by relevance).

Keyword relevance decides the order. Ties go to newer businesses, then nearer ones, then
better-rated ones — popularity never outranks a better text match, in line with the
proposal's aim of giving new businesses equal visibility.
"""
from __future__ import annotations

from collections.abc import Callable, Sequence
from datetime import datetime, timezone

from app.models.business import BusinessProfile
from app.services.business_service import is_new_business
from app.services.review_service import ranking_score
from app.services.search.criteria import SortOption
from app.services.search.strategies import FoldedText, SearchContext
from app.services.search.text import fold, word_starts_with

# Points per token, by where it matches (summed across fields).
WEIGHTS = {
    "name_exact": 100,  # the whole query equals the business name (once per search)
    "name_prefix": 60,  # a word in the name starts with the token
    "name": 40,  # the token appears inside the name
    "category": 30,
    "service": 20,
    "tagline": 15,
    "address": 10,
    "description": 8,
}

_TIER_RANK = {"$": 1, "$$": 2, "$$$": 3}
_FAR = float("inf")


def relevance(text: FoldedText, tokens: Sequence[str], query: str) -> int:
    score = 0
    if tokens and text.name == fold(query).strip():
        score += WEIGHTS["name_exact"]
    for token in tokens:
        if word_starts_with(text.name, token):
            score += WEIGHTS["name_prefix"]
        elif token in text.name:
            score += WEIGHTS["name"]
        if token in text.category:
            score += WEIGHTS["category"]
        if any(token in s for s in text.services):
            score += WEIGHTS["service"]
        if token in text.tagline:
            score += WEIGHTS["tagline"]
        if token in text.address:
            score += WEIGHTS["address"]
        if token in text.description:
            score += WEIGHTS["description"]
    return score


def _timestamp(value: datetime | None) -> float:
    if value is None:
        return 0.0
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.timestamp()


def rank(businesses: Sequence[BusinessProfile], ctx: SearchContext) -> list[BusinessProfile]:
    criteria = ctx.criteria
    tokens = criteria.tokens
    scores = {b.id: relevance(ctx.text(b), tokens, criteria.query) for b in businesses}

    def distance(b: BusinessProfile) -> float:
        d = ctx.distance(b)
        return _FAR if d is None else d

    def tier(b: BusinessProfile) -> int:
        return _TIER_RANK.get(b.price_level, 2)

    keys: dict[SortOption, Callable[[BusinessProfile], tuple]] = {
        SortOption.relevance: lambda b: (
            -scores[b.id],
            0 if is_new_business(b, ctx.now) else 1,
            distance(b),
            -ranking_score(b.rating, b.review_count),
            fold(b.name),
        ),
        SortOption.distance: lambda b: (distance(b), -scores[b.id], fold(b.name)),
        # Count-weighted, so one 5★ review doesn't outrank 4.8★ from 200 (Module 5).
        SortOption.rating: lambda b: (
            -ranking_score(b.rating, b.review_count),
            -(b.review_count or 0),
            fold(b.name),
        ),
        SortOption.price_low: lambda b: (
            tier(b),
            b.price_min if b.price_min is not None else _FAR,
            fold(b.name),
        ),
        SortOption.price_high: lambda b: (
            -tier(b),
            -(b.price_max if b.price_max is not None else (b.price_min or 0)),
            fold(b.name),
        ),
        SortOption.newest: lambda b: (-_timestamp(b.created_at), fold(b.name)),
        SortOption.popular: lambda b: (
            -(b.save_count or 0),
            -(b.view_count or 0),
            fold(b.name),
        ),
    }
    return sorted(businesses, key=keys[criteria.sort])
