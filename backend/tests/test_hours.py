"""Opening-hours rules behind "Open now" (unit tests, no database)."""
from dataclasses import dataclass
from datetime import datetime, timezone

from app.services.hours import is_open_at, is_open_now, today_hours_label, to_local


@dataclass
class H:
    day_of_week: int
    opens: str = "09:00"
    closes: str = "17:00"
    is_closed: bool = False


# 2026-09-23 is a Wednesday (weekday 2).
def wed(hour: int, minute: int = 0) -> datetime:
    return datetime(2026, 9, 23, hour, minute)


def test_regular_day():
    hours = [H(2, "09:00", "17:00")]
    assert is_open_at(hours, wed(9, 0)) is True
    assert is_open_at(hours, wed(16, 59)) is True
    assert is_open_at(hours, wed(17, 0)) is False  # closing time is exclusive
    assert is_open_at(hours, wed(8, 59)) is False


def test_overnight_window_spills_into_the_next_day():
    hours = [H(1, "18:00", "02:00")]  # Tuesday night
    assert is_open_at(hours, wed(1, 30)) is True  # Wednesday 01:30
    assert is_open_at(hours, wed(2, 0)) is False
    assert is_open_at(hours, wed(19, 0)) is False  # Wednesday itself has no hours


def test_equal_times_mean_open_24_hours():
    hours = [H(2, "00:00", "00:00")]
    assert is_open_at(hours, wed(0, 0)) is True
    assert is_open_at(hours, wed(23, 59)) is True


def test_closed_days_and_unknown_hours():
    assert is_open_at([H(2, is_closed=True)], wed(12)) is False
    assert is_open_at([H(3)], wed(12)) is False  # hours exist, but none for Wednesday
    assert is_open_at([], wed(12)) is None  # no hours at all → unknown


def test_malformed_times_are_treated_as_closed():
    assert is_open_at([H(2, "noon", "late")], wed(12)) is False


def test_now_is_evaluated_in_business_time():
    # 07:00 UTC is 12:00 in Asia/Karachi
    instant = datetime(2026, 9, 23, 7, 0, tzinfo=timezone.utc)
    assert to_local(instant).hour == 12
    assert is_open_now([H(2, "11:00", "13:00")], instant) is True
    assert is_open_now([H(2, "06:00", "08:00")], instant) is False


def test_today_label():
    instant = datetime(2026, 9, 23, 7, 0, tzinfo=timezone.utc)
    assert today_hours_label([H(2, "09:00", "22:00")], instant) == "09:00–22:00"
    assert today_hours_label([H(2, "00:00", "00:00")], instant) == "Open 24 hours"
    assert today_hours_label([H(2, is_closed=True)], instant) == "Closed today"
    assert today_hours_label([H(4)], instant) == "Closed today"
    assert today_hours_label([], instant) is None
