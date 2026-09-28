"""Tell each user what's trending in their interests (Module 3: "trending listings").

    python -m app.jobs.trending_digest            # send
    python -m app.jobs.trending_digest --dry-run  # list who would get what, send nothing

For each user with interests, it picks the published business in those categories with the
most profile views over the last 7 days (ties go to the better, count-weighted rating), and
sends one "Trending in …" notification. Nobody gets more than one within 20 hours, so it's
safe to run again, e.g. from a daily cron job after the demo.
"""
from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.database import SessionLocal
from app.models.business import BusinessProfile
from app.models.engagement import BusinessView
from app.models.notification import Notification, NotificationKind
from app.models.user import User
from app.services import notification_service as ns
from app.services.review_service import ranking_score

WINDOW = timedelta(days=7)
QUIET_PERIOD = timedelta(hours=20)


def trending_picks(db: Session, now: datetime | None = None) -> list[tuple[User, BusinessProfile]]:
    now = now or datetime.now(timezone.utc)
    views = dict(db.execute(
        select(BusinessView.business_id, func.count(BusinessView.id))
        .where(BusinessView.created_at >= now - WINDOW)
        .group_by(BusinessView.business_id)
    ).all())
    businesses = db.scalars(
        select(BusinessProfile).options(selectinload(BusinessProfile.category))
        .where(BusinessProfile.is_published.is_(True), BusinessProfile.category_id.is_not(None))
    ).all()

    def heat(b: BusinessProfile) -> tuple[int, float]:
        return views.get(b.id, 0), ranking_score(b.rating, b.review_count)

    by_category: dict[str, list[BusinessProfile]] = {}
    for b in sorted(businesses, key=heat, reverse=True):
        by_category.setdefault(b.category.slug, []).append(b)

    recently_told = set(db.scalars(select(Notification.user_id).where(
        Notification.kind == NotificationKind.trending,
        Notification.created_at >= now - QUIET_PERIOD,
    )))
    picks = []
    for user in db.scalars(select(User).order_by(User.id)):
        if user.id in recently_told or not user.interests \
                or not ns.wants(user, NotificationKind.trending):
            continue
        candidates = [
            b for slug in user.interests for b in by_category.get(slug, [])
            if b.owner_id != user.id
        ]
        if candidates:
            picks.append((user, max(candidates, key=heat)))
    return picks


def run(db: Session, *, now: datetime | None = None, dry_run: bool = False
        ) -> list[tuple[User, BusinessProfile]]:
    now = now or datetime.now(timezone.utc)
    picks = trending_picks(db, now)
    jobs = []
    for user, b in picks:
        category = b.category_label or b.category.name
        body = f"{b.name} is popular this week"
        if b.tagline:
            body += f": {ns.snippet(b.tagline, 70)}"
        job = ns.notify(db, [user], NotificationKind.trending, title=f"Trending in {category}",
                        body=body, route=ns.business_route(b), now=now)
        if job is not None:
            jobs.append(job)
    if dry_run:
        db.rollback()
        return picks
    db.commit()
    for job in jobs:
        job()
    return picks


def main(argv: list[str]) -> None:
    dry_run = "--dry-run" in argv
    db = SessionLocal()
    try:
        picks = run(db, dry_run=dry_run)
    finally:
        db.close()
    verb = "Would notify" if dry_run else "Notified"
    for user, b in picks:
        print(f"{verb} {user.email}: {b.name} ({b.category.name})")
    print(f"{verb} {len(picks)} user{'' if len(picks) == 1 else 's'}.")


if __name__ == "__main__":
    main(sys.argv[1:])
