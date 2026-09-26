"""Uploaded photos: business covers and galleries, and profile pictures.

SDD §5.1 keeps all persistent data in PostgreSQL, so photos live there too. Each upload is
re-encoded into a large variant (full-width surfaces) and a thumbnail (small cards). The
image bytes are deferred, so loading businesses or users never pulls them.
"""
from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, LargeBinary, String, UniqueConstraint
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship

from app.core.config import settings
from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Media(Base):
    __tablename__ = "media"

    id: Mapped[int] = mapped_column(primary_key=True)
    # Public, unguessable id used in URLs. A new upload always gets a new key, so the
    # bytes behind a URL never change and clients may cache them forever.
    key: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    # The uploader; only they can attach the photo to a business or their profile.
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    content_type: Mapped[str] = mapped_column(String(32), default="image/jpeg")
    # Dimensions of the large variant (the thumbnail has the same aspect ratio).
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    # Centre of interest (0–1 from the left / top) so automatic crops keep the subject.
    focal_x: Mapped[float] = mapped_column(Float, default=0.5)
    focal_y: Mapped[float] = mapped_column(Float, default=0.5)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    data: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))
    thumb: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, index=True
    )

    @property
    def url(self) -> str:
        return f"{settings.API_V1_PREFIX}/media/{self.key}"

    @property
    def thumb_url(self) -> str:
        return f"{self.url}/thumb"


class BusinessPhoto(Base):
    """A photo in a business's gallery. The photo at position 0 is the cover."""

    __tablename__ = "business_photos"
    __table_args__ = (UniqueConstraint("business_id", "media_id", name="uq_business_photo"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    media_id: Mapped[int] = mapped_column(ForeignKey("media.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer, default=0)

    business = relationship("BusinessProfile", back_populates="photos")
    media = relationship("Media", lazy="joined")
