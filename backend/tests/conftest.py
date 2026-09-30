import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.database import Base, get_db
from app.core.privacy import PRIVACY_POLICY_VERSION
from app.main import app

# The startup schema check would connect to the real DATABASE_URL; tests use SQLite below.
settings.SCHEMA_CHECK_ON_STARTUP = False

# Isolated in-memory SQLite for fast, dependency-free tests.
engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)


@event.listens_for(engine, "connect")
def _sqlite_foreign_keys(dbapi_connection, _):
    """Enforce foreign keys (and their ON DELETE rules) like PostgreSQL does."""
    dbapi_connection.execute("PRAGMA foreign_keys=ON")


TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def _schema():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def sent_emails(monkeypatch):
    """Registration/OTP flows send email in a background task — capture instead of hitting
    real SMTP, and let tests assert on the code that would have been emailed.
    """
    sent: list[tuple[str, str, str]] = []
    monkeypatch.setattr(
        "app.services.otp_service.send_verify_email_otp",
        lambda to, code: sent.append(("verify_email", to, code)),
    )
    monkeypatch.setattr(
        "app.services.otp_service.send_password_reset_otp",
        lambda to, code: sent.append(("reset_password", to, code)),
    )
    return sent


@pytest.fixture(autouse=True)
def _outside_request_sessions(monkeypatch):
    """WebSocket events and background push jobs open their own sessions: use SQLite too."""
    monkeypatch.setattr("app.core.database.session_factory", TestingSessionLocal)


class RecordingSender:
    """Stands in for Firebase: records each push instead of sending it."""

    def __init__(self):
        self.sent: list[tuple[list[str], object]] = []
        # Tokens to report back as no longer valid (as FCM would).
        self.invalid: set[str] = set()

    def send(self, tokens, message):
        from app.services.push import SendResult

        self.sent.append((list(tokens), message))
        return SendResult(sent=len(tokens), invalid=[t for t in tokens if t in self.invalid])

    def titles(self) -> list[str]:
        return [message.title for _, message in self.sent]


@pytest.fixture(autouse=True)
def pushes(monkeypatch):
    sender = RecordingSender()
    monkeypatch.setattr("app.services.push.get_sender", lambda: sender)
    return sender


@pytest.fixture
def client():
    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def register(client, email, role="customer", **extra):
    payload = {
        "full_name": extra.get("full_name", "Test User"),
        "email": email,
        "password": "password123",
        "role": role,
        "interests": extra.get("interests", []),
        "privacy_policy_version": extra.get("privacy_policy_version", PRIVACY_POLICY_VERSION),
    }
    return client.post("/api/v1/auth/register", json=payload)


def login(client, email):
    r = client.post("/api/v1/auth/login", json={"email": email, "password": "password123"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}
