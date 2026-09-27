"""Module 5 — review request and response bodies."""
import enum
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.review import ReportReason
from app.schemas.media import PhotoOut

MAX_COMMENT = 1000
MAX_REPLY = 1000
MAX_PHOTOS = 3


class ReviewSort(str, enum.Enum):
    relevant = "relevant"  # verified reviewers first, then reviews with text/photos, helpful, new
    recent = "recent"
    highest = "highest"
    lowest = "lowest"
    helpful = "helpful"


class ReviewAuthor(BaseModel):
    id: int
    # "Hassan R.": first name and last initial, as in the SDD mockup.
    name: str
    initials: str
    tone: str
    avatar: PhotoOut | None = None
    # Verified email: shown with a badge and listed first (Module 5 decision 2a).
    is_verified: bool


class OwnerReply(BaseModel):
    text: str
    created_at: datetime


class ReviewOut(BaseModel):
    id: int
    business_id: int
    rating: int
    comment: str
    photos: list[PhotoOut] = []
    author: ReviewAuthor
    created_at: datetime
    # Set when the author edited it ("edited").
    updated_at: datetime | None = None
    helpful_count: int = 0
    owner_reply: OwnerReply | None = None
    # About the viewer:
    is_mine: bool = False
    voted_helpful: bool = False
    reported: bool = False
    # False when a moderator hid it; only ever visible to its author.
    is_visible: bool = True


class ReviewSummary(BaseModel):
    average: float
    count: int
    # Reviews per star, keys "1"…"5".
    distribution: dict[int, int]
    with_photos: int = 0
    # Only for the business's owner: reviews still waiting for a reply.
    unreplied: int | None = None


class ReviewPage(BaseModel):
    summary: ReviewSummary
    items: list[ReviewOut]
    # Reviews matching the star/photo filters (the summary always covers all of them).
    total: int
    limit: int
    offset: int
    sort: ReviewSort
    # The viewer's own review of this business, shown first with Edit / Delete.
    mine: ReviewOut | None = None
    # Whether the viewer may write a review now (signed in, not the owner, none yet).
    can_review: bool = False
    # The viewer owns the business, so they can reply.
    is_owner: bool = False


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5, description="1–5 stars")
    comment: str = Field(default="", max_length=MAX_COMMENT)
    # Keys from POST /media, in display order.
    photos: list[str] = Field(default_factory=list, max_length=MAX_PHOTOS)


class ReviewUpdate(BaseModel):
    """Partial update: omitted fields stay as they are."""

    rating: int | None = Field(default=None, ge=1, le=5)
    comment: str | None = Field(default=None, max_length=MAX_COMMENT)
    photos: list[str] | None = Field(default=None, max_length=MAX_PHOTOS)


class ReplyIn(BaseModel):
    text: str = Field(min_length=1, max_length=MAX_REPLY)


class ReportIn(BaseModel):
    reason: ReportReason
    note: str = Field(default="", max_length=500)


class HelpfulOut(BaseModel):
    helpful_count: int
    voted_helpful: bool


class ReviewedBusiness(BaseModel):
    id: int
    name: str
    tone: str
    cover: PhotoOut | None = None
    category_label: str | None = None


class MyReview(ReviewOut):
    business: ReviewedBusiness
