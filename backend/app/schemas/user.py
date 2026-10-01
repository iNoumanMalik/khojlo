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
    # False for Google-only accounts (deleting one then needs no password).
    has_password: bool
    # The app asks the user to agree to the privacy policy while this is true.
    needs_privacy_consent: bool
    privacy_policy_version: str | None = None
    privacy_consent_at: datetime | None = None
    created_at: datetime


class PrivacyConsentRequest(BaseModel):
    policy_version: str = Field(max_length=32)


class DeleteAccountRequest(BaseModel):
    """Accounts with a password must re-enter it; Google-only accounts have none."""

    password: str | None = None


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
