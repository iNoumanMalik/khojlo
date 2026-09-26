from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.user import UserRole
from app.schemas.business import normalize_phone
from app.schemas.media import PhotoOut


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str
    role: UserRole
    avatar_tone: str
    # Profile photo; None means show initials on `avatar_tone`.
    avatar: PhotoOut | None = None
    phone: str | None = None
    initials: str
    interests: list[str]
    is_verified: bool
    created_at: datetime


class UserUpdate(BaseModel):
    """Partial update: omitted fields are left alone; `phone`/`avatar` set to null clear them."""

    full_name: str | None = Field(default=None, max_length=120)
    avatar_tone: str | None = Field(default=None, max_length=16)
    phone: str | None = None
    # A key from POST /media.
    avatar: str | None = None

    _phone = field_validator("phone")(normalize_phone)

    @field_validator("full_name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = " ".join(v.split())
        if not v:
            raise ValueError("Your name can't be empty")
        return v


class InterestsUpdate(BaseModel):
    interests: list[str]
