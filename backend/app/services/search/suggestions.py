"""Typeahead suggestions: categories, businesses and services matching what's typed."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.business import BusinessProfile, Category, Service
from app.schemas.search import Suggestion
from app.services.search.text import LIKE_ESCAPE, fold, like_pattern, word_starts_with

_CANDIDATE_LIMIT = 50


def suggest(db: Session, q: str, limit: int = 8) -> list[Suggestion]:
    needle = fold(q).strip()
    if not needle:
        return []
    pattern = like_pattern(needle)

    def prefix_rank(label: str) -> int | None:
        """0 = label starts with the text, 1 = a later word does, None = no word does.

        Typeahead only offers word-prefix matches: "ra" suggests "Ramen", not "Tiramisu".
        """
        folded = fold(label)
        if folded.startswith(needle):
            return 0
        if word_starts_with(folded, needle):
            return 1
        return None

    ranked: list[tuple[int, int, str, Suggestion]] = []

    for cat in db.execute(
        select(Category).where(
            Category.name.ilike(pattern, escape=LIKE_ESCAPE)
            | Category.keywords.ilike(pattern, escape=LIKE_ESCAPE)
        )
    ).scalars():
        rank = prefix_rank(cat.name)
        if rank is None:
            # A keyword match ("darzi") ranks below names that start with the text.
            keywords = [k.strip() for k in (cat.keywords or "").split(",")]
            if any(prefix_rank(k) is not None for k in keywords if k):
                rank = 1
        if rank is not None:
            ranked.append(
                (rank, 0, fold(cat.name),
                 Suggestion(type="category", label=cat.name, sublabel="Category",
                            category_slug=cat.slug))
            )

    businesses = db.execute(
        select(BusinessProfile)
        .options(selectinload(BusinessProfile.category))
        .where(
            BusinessProfile.is_published.is_(True),
            BusinessProfile.name.ilike(pattern, escape=LIKE_ESCAPE),
        )
        .limit(_CANDIDATE_LIMIT)
    ).scalars()
    for b in businesses:
        rank = prefix_rank(b.name)
        if rank is not None:
            ranked.append(
                (rank, 1, fold(b.name),
                 Suggestion(type="business", label=b.name,
                            sublabel=b.category_label,
                            business_id=b.id))
            )

    service_names = db.execute(
        select(Service.name)
        .join(BusinessProfile, BusinessProfile.id == Service.business_id)
        .where(
            BusinessProfile.is_published.is_(True),
            Service.name.ilike(pattern, escape=LIKE_ESCAPE),
        )
        .distinct()
        .limit(_CANDIDATE_LIMIT)
    ).scalars()
    seen_services: set[str] = set()
    for name in service_names:
        key = fold(name)
        rank = prefix_rank(name)
        if rank is not None and key not in seen_services:
            seen_services.add(key)
            ranked.append(
                (rank, 2, key,
                 Suggestion(type="service", label=name, sublabel="Service"))
            )

    ranked.sort(key=lambda r: (r[0], r[1], r[2]))
    return [s for *_, s in ranked[:limit]]
