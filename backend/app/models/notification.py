"""Push notifications (SRS FR-21, UC-15; Module 3) and the in-app Notifications list.

Devices register a Firebase Cloud Messaging token. Events such as a new review or offer
add a row to the recipient's Notifications list and push to their devices. Chat messages
are pushed but not listed: the Chat tab is their inbox.
"""
import enum
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DevicePlatform(str, enum.Enum):
    android = "android"
    web = "web"
    ios = "ios"


class NotificationKind(str, enum.Enum):
    """Also the keys of `User.notification_prefs` (plus "message")."""

    message = "message"  # pushed only; never stored in the list
    review = "review"
    review_reply = "review_reply"
    offer = "offer"
    new_business = "new_business"
    trending = "trending"
    # Module 8. Not switchable: people must hear about decisions on their account.
    account = "account"  # warnings, suspensions, removed content, report outcomes
    verification = "verification"  # the business's verification status changed


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # FCM registration token. Unique: a device signed in as someone else moves to them.
    token: Mapped[str] = mapped_column(String(512), unique=True)
    platform: Mapped[DevicePlatform] = mapped_column(
        Enum(DevicePlatform, name="device_platform", native_enum=False, length=16)
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[NotificationKind] = mapped_column(
        Enum(NotificationKind, name="notification_kind", native_enum=False, length=16)
    )
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(String(500), default="")
    # The app screen to open, e.g. "/business/5/reviews".
    route: Mapped[str] = mapped_column(String(200), default="")
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )
