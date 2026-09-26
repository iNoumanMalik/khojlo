import pytest
from sqlalchemy import text

from app.db.schema_check import expected_revisions, schema_problem
from tests.conftest import engine


@pytest.fixture(autouse=True)
def _drop_alembic_version():
    """alembic_version isn't in the ORM metadata, so the shared test schema won't drop it."""
    yield
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS alembic_version"))


def _record(revision: str) -> None:
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE IF NOT EXISTS alembic_version (version_num VARCHAR(32))"))
        conn.execute(text("DELETE FROM alembic_version"))
        conn.execute(text("INSERT INTO alembic_version VALUES (:v)"), {"v": revision})


def test_a_database_without_migrations_is_reported():
    problem = schema_problem(engine)
    assert problem and "alembic upgrade head" in problem and "no migrations" in problem


def test_a_database_behind_the_code_is_reported():
    _record("4ff96035ae0a")  # Module 3
    problem = schema_problem(engine)
    assert problem and "4ff96035ae0a" in problem


def test_an_up_to_date_database_passes():
    (head,) = expected_revisions()
    _record(head)
    assert schema_problem(engine) is None
