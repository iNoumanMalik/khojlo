from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.user import UserRole


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str
    role: UserRole
    avatar_tone: str
    initials: str
    interests: list[str]
    is_verified: bool
    created_at: datetime


class UserUpdate(BaseModel):
    full_name: str | None = None
    avatar_tone: str | None = None


class InterestsUpdate(BaseModel):
    interests: list[str]
