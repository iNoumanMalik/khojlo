"""Module 9 — chat request and response bodies."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.models.chat import ConversationReportReason
from app.schemas.business import OfferOut
from app.schemas.media import PhotoOut

MAX_MESSAGE = 2000

# Which participant the viewer is: the customer, or the business (its owner).
Side = Literal["customer", "business"]


class ChatPerson(BaseModel):
    """The customer, as the business owner sees them."""

    id: int
    # "Ali C.": first name and last initial, as on reviews.
    name: str
    initials: str
    tone: str
    avatar: PhotoOut | None = None


class ChatBusinessBrief(BaseModel):
    id: int
    name: str
    tone: str
    cover: PhotoOut | None = None
    category_label: str | None = None


class ChatBusiness(ChatBusinessBrief):
    """The business header a customer sees in a conversation (design: business header,
    quick actions and offers)."""

    is_verified: bool = False
    is_open_now: bool | None = None
    today_hours: str | None = None
    phone: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    offers: list[OfferOut] = Field(default_factory=list)


class MessageOut(BaseModel):
    id: int
    conversation_id: int
    body: str
    photo: PhotoOut | None = None
    from_business: bool
    # Sent by the viewer.
    is_mine: bool
    created_at: datetime
    # Echo of the sender's client id, so the sender's app can match its pending bubble.
    client_id: str | None = None


class ConversationSummary(BaseModel):
    id: int
    my_side: Side
    business: ChatBusinessBrief
    customer: ChatPerson
    last_message: MessageOut | None = None
    last_message_at: datetime | None = None
    unread_count: int = 0


class ConversationDetail(ConversationSummary):
    business: ChatBusiness
    # How far the other side has read: messages up to this id show "Seen".
    other_last_read_id: int | None = None
    my_last_read_id: int | None = None
    # ── Module 8 ──
    blocked_by_me: bool = False
    blocked_by_them: bool = False
    # Closed by Khojlo's moderators after a report.
    closed: bool = False
    # Whether the viewer can send a message now.
    can_send: bool = True


class MessagePage(BaseModel):
    # Oldest first.
    items: list[MessageOut]
    # Older messages exist before the first item.
    has_more: bool = False


class ConversationCreate(BaseModel):
    business_id: int


class MessageIn(BaseModel):
    body: str = Field(default="", max_length=MAX_MESSAGE)
    # Random id from the app, so a retried send isn't stored twice.
    client_id: str | None = Field(default=None, max_length=36)
    # A key from POST /media.
    photo: str | None = Field(default=None, max_length=32)


class UnreadOut(BaseModel):
    total: int


class ReadOut(BaseModel):
    last_read_id: int | None
    unread_total: int


class ConversationReportIn(BaseModel):
    reason: ConversationReportReason
    note: str = Field(default="", max_length=500)
