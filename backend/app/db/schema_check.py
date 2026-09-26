"""Warn at startup when the database schema is behind the code.

Every request that touches a table with an unapplied column fails with a 500, which the app
can only report as "couldn't load" — so say plainly in the server log what to run instead.
"""
from __future__ import annotations

import logging
from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

log = logging.getLogger("uvicorn.error")

BACKEND_DIR = Path(__file__).resolve().parents[2]


def expected_revisions() -> set[str]:
    """The migration heads shipped with this code."""
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    return set(ScriptDirectory.from_config(config).get_heads())


def applied_revisions(engine: Engine) -> set[str]:
    """The revisions recorded in the database (empty if Alembic never ran there)."""
    with engine.connect() as conn:
        if not inspect(conn).has_table("alembic_version"):
            return set()
        return {row[0] for row in conn.execute(text("SELECT version_num FROM alembic_version"))}


def schema_problem(engine: Engine) -> str | None:
    """A human-readable description of the mismatch, or None when the schema is current."""
    expected = expected_revisions()
    applied = applied_revisions(engine)
    if applied == expected:
        return None
    found = ", ".join(sorted(applied)) or "no migrations"
    return (
        f"Database schema is out of date (database has {found}; code expects "
        f"{', '.join(sorted(expected))}). Run `alembic upgrade head` in backend/ — "
        "API requests will fail until you do."
    )


def warn_if_outdated(engine: Engine) -> None:
    try:
        problem = schema_problem(engine)
    except Exception as exc:  # unreachable DB etc. — the first request will surface it
        log.warning("Could not check the database schema: %s", exc.__class__.__name__)
        return
    if problem:
        log.warning(problem)
