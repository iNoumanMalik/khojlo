"""`SearchEngine` — SDD class diagram §4.1, Algorithms 2 and 11.

The SDD's engine holds one strategy at a time (`setSearchStrategy`). A real request mixes
keyword, category and location, so this engine runs a *list* of strategies; the SDD's
single-strategy call is kept as `set_search_strategy()`.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import Select, select
from sqlalchemy.orm import Session, selectinload

from app.models.business import BusinessProfile, Category
from app.services.business_service import card_load_options, is_new_business
from app.services.search.criteria import SearchCriteria
from app.services.search.ranking import rank
from app.services.search.strategies import SearchContext, SearchStrategy, strategies_for


@dataclass
class SearchOutcome:
    items: list[BusinessProfile]  # the requested page, ranked
    total: int  # matches across all pages
    relaxed: bool  # True when a multi-word search fell back to "any word" matching
    summary: str
    context: SearchContext  # distances / open-now computed during the search


def base_query() -> Select:
    """Published businesses, with their category joined for keyword/category strategies."""
    return (
        select(BusinessProfile)
        .outerjoin(Category, BusinessProfile.category_id == Category.id)
        .where(BusinessProfile.is_published.is_(True))
    )


class SearchEngine:
    def __init__(self, db: Session, *, now: datetime | None = None):
        self.db = db
        self.now = now or datetime.now(timezone.utc)
        self._strategies: list[SearchStrategy] = []

    # ── SDD API ──
    def set_search_strategy(self, strategy: SearchStrategy) -> None:
        """SDD `setSearchStrategy()`: use exactly this one strategy."""
        self._strategies = [strategy]

    def add_search_strategy(self, strategy: SearchStrategy) -> "SearchEngine":
        self._strategies.append(strategy)
        return self

    def run(self, ctx: SearchContext) -> list[BusinessProfile]:
        """SDD Algorithm 11: execute the strategies and return every matching business."""
        stmt = base_query()
        for strategy in self._strategies:
            stmt = strategy.apply(stmt)
        stmt = stmt.options(*card_load_options(), selectinload(BusinessProfile.services))
        candidates = self.db.execute(stmt).scalars().all()
        return [b for b in candidates if all(s.matches(b, ctx) for s in self._strategies)]

    def search(self, criteria: SearchCriteria) -> SearchOutcome:
        """SDD Algorithm 2: match keyword + filters, rank, and page the results."""
        ctx = SearchContext(criteria, self.now)
        self._strategies = strategies_for(criteria)
        results = self.run(ctx)

        relaxed = False
        if not results and len(criteria.tokens) > 1:
            self._strategies = strategies_for(criteria, match_all=False)
            results = self.run(ctx)
            relaxed = bool(results)

        ranked = rank(results, ctx)
        page = ranked[criteria.offset : criteria.offset + criteria.limit]
        return SearchOutcome(
            items=page,
            total=len(ranked),
            relaxed=relaxed,
            summary=summarize(ranked, ctx),
            context=ctx,
        )


def summarize(results: list[BusinessProfile], ctx: SearchContext) -> str:
    """A short, rule-based digest of the whole result set.

    Fills the design's "AI summary" slot until the Module 7 assistant can generate one.
    """
    n = len(results)
    if n == 0:
        return "No places match yet. Try removing a filter or searching a broader word."

    parts = [f"{n} place{'s' if n != 1 else ''}"]

    tier, tier_count = Counter(b.price_level for b in results).most_common(1)[0]
    if n > 1 and tier_count / n >= 0.5:
        parts.append(f"mostly {tier}")

    open_states = [ctx.is_open(b) for b in results]
    if any(state is not None for state in open_states):
        parts.append(f"{sum(1 for s in open_states if s)} open now")

    ratings = [b.rating for b in results if (b.rating or 0) > 0]
    if ratings:
        parts.append(f"avg ★ {sum(ratings) / len(ratings):.1f}")

    distances = [d for d in (ctx.distance(b) for b in results) if d is not None]
    if distances:
        parts.append(f"nearest {min(distances):.1f} km")

    new_count = sum(1 for b in results if is_new_business(b, ctx.now))
    if new_count:
        parts.append(f"{new_count} new")

    return " · ".join(parts)
