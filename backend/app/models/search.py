from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SearchQuery(Base):
    """One submitted search (Module 4).

    Powers "Recent searches" (per user) and "Popular searches" (everyone, last 30 days).
    The proposal's Module 10 also lists search history as a personalization signal, so
    anonymous searches are kept too (``user_id`` is null for them).
    """

    __tablename__ = "search_queries"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    # Text as the user typed it (trimmed).
    query: Mapped[str] = mapped_column(String(100), nullable=False)
    # Case-folded, whitespace-collapsed form used to group identical searches.
    normalized: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    # Filters active at the time, e.g. {"category": ["cafes"], "open_now": true}.
    filters: Mapped[dict] = mapped_column(JSON, default=dict)
    result_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )
