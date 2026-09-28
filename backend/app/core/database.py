from collections.abc import Generator, Iterator
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Declarative base shared by all ORM models."""


def get_db() -> Generator:
    """FastAPI dependency that yields a scoped DB session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Sessions for work outside a request, such as WebSocket events and background push jobs
# (a request's own session is closed before its background tasks run). Tests point this
# at their database.
session_factory = SessionLocal


@contextmanager
def session_scope() -> Iterator[Session]:
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
