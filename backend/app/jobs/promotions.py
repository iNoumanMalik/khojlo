"""Send the "it's live" notifications owed by scheduled offers and campaigns.

    python -m app.jobs.promotions

Offers and campaigns go live on their start date with nothing running at midnight; their
one-time notification to people who saved the business is sent by whichever comes first:
this job (e.g. a daily cron at 9 AM) or the next time anyone opens Home. Safe to run
repeatedly: each offer and campaign is announced once.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone

from app.core.database import SessionLocal
from app.services.promotion_service import due_notices


def main(argv: list[str]) -> None:
    db = SessionLocal()
    try:
        jobs = due_notices(db, datetime.now(timezone.utc))
        db.commit()
    finally:
        db.close()
    for job in jobs:
        job()
    print(f"Sent {len(jobs)} promotion notification batch{'' if len(jobs) == 1 else 'es'}.")


if __name__ == "__main__":
    main(sys.argv[1:])
