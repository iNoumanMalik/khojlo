import enum
from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, String, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserRole(str, enum.Enum):
    customer = "customer"
    business_owner = "business_owner"
    admin = "admin"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    # null for accounts created via a social provider (e.g. Google) that never set a password.
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)
    google_id: Mapped[str | None] = mapped_column(String(64), unique=True, index=True, nullable=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, native_enum=False, length=32), default=UserRole.customer, nullable=False
    )
    avatar_tone: Mapped[str] = mapped_column(String(16), default="gold")
    phone: Mapped[str | None] = mapped_column(String(24), nullable=True)
    # Profile photo; initials on `avatar_tone` are shown when there's none. `use_alter`
    # because media also points back at users (the uploader).
    avatar_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media.id", ondelete="SET NULL", use_alter=True, name="fk_users_avatar_media"),
        nullable=True,
    )
    # list of interest slugs powering personalization ("food", "gym", ...)
    interests: Mapped[list] = mapped_column(JSON, default=list)
    # Notification types the user turned off, e.g. {"offers": false}. Missing keys mean on.
    notification_prefs: Mapped[dict] = mapped_column(
        JSON, default=dict, server_default=text("'{}'")
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    businesses = relationship(
        "BusinessProfile", back_populates="owner", cascade="all, delete-orphan"
    )
    saved_lists = relationship(
        "SavedList", back_populates="user", cascade="all, delete-orphan"
    )
    avatar = relationship("Media", foreign_keys=[avatar_media_id], lazy="joined")

    @property
    def initials(self) -> str:
        parts = [p for p in self.full_name.split() if p]
        if not parts:
            return "?"
        if len(parts) == 1:
            return parts[0][0].upper()
        return (parts[0][0] + parts[-1][0]).upper()
