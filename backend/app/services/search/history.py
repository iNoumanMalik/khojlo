"""Search history: recording submitted searches, recent searches, popular searches."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, desc, func, select
from sqlalchemy.orm import Session

from app.models.business import Category
from app.models.search import SearchQuery
from app.schemas.search import SearchHistoryItem
from app.services.search.criteria import SearchCriteria
from app.services.search.text import normalize_query

POPULAR_WINDOW_DAYS = 30
_MAX_QUERY_LENGTH = 100


def record_search(
    db: Session, *, user_id: int | None, criteria: SearchCriteria, result_count: int
) -> None:
    """Store a submitted search. Blank queries (filter-only browsing) aren't recorded."""
    text = " ".join(criteria.query.split())[:_MAX_QUERY_LENGTH]
    if not text:
        return
    db.add(
        SearchQuery(
            user_id=user_id,
            query=text,
            normalized=normalize_query(text),
            filters=criteria.active_filters(),
            result_count=result_count,
        )
    )
    db.commit()


def recent_searches(db: Session, user_id: int, limit: int = 10) -> list[SearchHistoryItem]:
    """The user's latest distinct searches, newest first."""
    rows = db.execute(
        select(SearchQuery)
        .where(SearchQuery.user_id == user_id)
        .order_by(SearchQuery.created_at.desc(), SearchQuery.id.desc())
        .limit(limit * 10)
    ).scalars()
    seen: set[str] = set()
    items: list[SearchHistoryItem] = []
    for row in rows:
        if row.normalized in seen:
            continue
        seen.add(row.normalized)
        items.append(SearchHistoryItem(query=row.query, created_at=row.created_at))
        if len(items) >= limit:
            break
    return items


def clear_history(db: Session, user_id: int) -> None:
    db.execute(delete(SearchQuery).where(SearchQuery.user_id == user_id))
    db.commit()


def popular_searches(db: Session, *, limit: int = 8, now: datetime | None = None) -> list[str]:
    """Most frequent searches of the last 30 days that found something.

    Topped up with category names so the list is never empty on a fresh install.
    """
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(days=POPULAR_WINDOW_DAYS)
    count = func.count(SearchQuery.id)
    rows = db.execute(
        select(SearchQuery.normalized, count, func.max(SearchQuery.created_at))
        .where(SearchQuery.created_at >= since, SearchQuery.result_count > 0)
        .group_by(SearchQuery.normalized)
        .order_by(desc(count), desc(func.max(SearchQuery.created_at)))
        .limit(limit)
    ).all()
    popular = [normalized for normalized, _, _ in rows]

    if len(popular) < limit:
        taken = set(popular)
        for (name,) in db.execute(select(Category.name).order_by(Category.id)).all():
            label = normalize_query(name)
            if label not in taken:
                popular.append(label)
                taken.add(label)
            if len(popular) >= limit:
                break
    return popular
