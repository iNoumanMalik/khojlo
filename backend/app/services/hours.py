"""Opening-hours logic shared by search ("Open now"), cards and comparison.

Hours are stored per weekday as local "HH:MM" strings. They are evaluated in the
businesses' timezone (``settings.BUSINESS_TIMEZONE``), never the server's UTC clock.

Conventions:
* ``closes`` earlier than ``opens`` → the business closes after midnight (18:00–02:00).
* ``closes`` equal to ``opens`` → open 24 hours.
* A weekday with no row, or a row with ``is_closed``, is closed that day.
* No rows at all → hours unknown (``None``), which is different from "closed".
"""
from __future__ import annotations

import logging
from collections.abc import Sequence
from datetime import datetime, timedelta, timezone, tzinfo
from functools import lru_cache
from typing import Protocol
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.core.config import settings

logger = logging.getLogger(__name__)

_DAY_MINUTES = 24 * 60

# Used only if the IANA database is unavailable (e.g. Windows without `tzdata`).
_FIXED_OFFSETS_HOURS = {"Asia/Karachi": 5}


class HoursLike(Protocol):
    day_of_week: int
    opens: str
    closes: str
    is_closed: bool


@lru_cache
def business_timezone() -> tzinfo:
    name = settings.BUSINESS_TIMEZONE
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        offset = _FIXED_OFFSETS_HOURS.get(name, 0)
        logger.warning(
            "Timezone %r not found (install `tzdata`); falling back to UTC%+d.", name, offset
        )
        return timezone(timedelta(hours=offset), name)


def to_local(now: datetime | None = None) -> datetime:
    """Convert an aware (or naive-UTC) instant to the businesses' local time."""
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    return now.astimezone(business_timezone())


def _minutes(hhmm: str) -> int | None:
    try:
        h_str, m_str = hhmm.strip().split(":")
        h, m = int(h_str), int(m_str)
    except (AttributeError, ValueError):
        return None
    if not (0 <= h <= 24 and 0 <= m < 60):
        return None
    return h * 60 + m


def _window(entry: HoursLike) -> tuple[int, int] | None:
    """Open window in minutes after local midnight; the end may exceed 24h (overnight)."""
    if entry.is_closed:
        return None
    opens, closes = _minutes(entry.opens), _minutes(entry.closes)
    if opens is None or closes is None:
        return None
    if closes <= opens:  # overnight, or equal → 24 hours
        closes += _DAY_MINUTES
    return opens, closes


def is_open_at(hours: Sequence[HoursLike], local: datetime) -> bool | None:
    """Whether a business is open at the given *local* time. None if hours are unknown."""
    if not hours:
        return None
    by_day = {h.day_of_week: h for h in hours}
    minute = local.hour * 60 + local.minute
    weekday = local.weekday()

    today = by_day.get(weekday)
    if today is not None:
        window = _window(today)
        if window and window[0] <= minute < window[1]:
            return True

    # Yesterday's overnight window spilling past midnight (e.g. Tue 18:00–02:00 at Wed 01:00).
    yesterday = by_day.get((weekday - 1) % 7)
    if yesterday is not None:
        window = _window(yesterday)
        if window and window[1] > _DAY_MINUTES and minute < window[1] - _DAY_MINUTES:
            return True
    return False


def is_open_now(hours: Sequence[HoursLike], now: datetime | None = None) -> bool | None:
    return is_open_at(hours, to_local(now))


def today_hours_label(hours: Sequence[HoursLike], now: datetime | None = None) -> str | None:
    """Human label for today's hours: "09:00–22:00", "Open 24 hours", "Closed today"."""
    if not hours:
        return None
    entry = {h.day_of_week: h for h in hours}.get(to_local(now).weekday())
    if entry is None or entry.is_closed:
        return "Closed today"
    opens, closes = _minutes(entry.opens), _minutes(entry.closes)
    if opens is None or closes is None:
        return None
    if opens == closes:
        return "Open 24 hours"
    return f"{entry.opens}–{entry.closes}"
