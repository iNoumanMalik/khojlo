"""Module 8 — request and response bodies used outside the admin panel: reporting a
business and the owner's verification checklist."""
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.moderation import BusinessReportReason, VerificationStatus
from app.schemas.media import PhotoOut


class BusinessReportIn(BaseModel):
    reason: BusinessReportReason
    note: str = Field(default="", max_length=500)


class CheckOut(BaseModel):
    key: str  # email | profile | storefront | record
    label: str
    passed: bool
    # What to do next when it hasn't passed.
    hint: str = ""


class VerificationOut(BaseModel):
    """The owner's view of verification: the checklist and where it stands."""

    business_id: int
    status: VerificationStatus
    is_verified: bool
    checks: list[CheckOut]
    # Private: only the owner and admins see it.
    storefront: PhotoOut | None = None
    storefront_at: datetime | None = None
    # The admin's message when they rejected it or asked for more.
    note: str = ""
    verified_at: datetime | None = None
    # The owner can answer "Request more info" or ask again after a rejection.
    can_request_review: bool = False
    is_suspended: bool = False
    # e.g. "Scam or fraud", while suspended.
    suspension_reason: str | None = None


class StorefrontIn(BaseModel):
    # A key from POST /media, taken with the camera in the app.
    photo: str = Field(pattern=r"^[0-9a-f]{32}$")


class ReviewRequestIn(BaseModel):
    note: str = Field(default="", max_length=1000)
