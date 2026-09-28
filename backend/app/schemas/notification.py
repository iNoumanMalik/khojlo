"""Push notifications and the Notifications list — request and response bodies."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.notification import DevicePlatform, NotificationKind


class DeviceIn(BaseModel):
    token: str = Field(min_length=10, max_length=512)
    platform: DevicePlatform


class DeviceUnregisterIn(BaseModel):
    token: str = Field(min_length=1, max_length=512)


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    kind: NotificationKind
    title: str
    body: str
    route: str
    is_read: bool
    created_at: datetime


class NotificationPage(BaseModel):
    items: list[NotificationOut]
    total: int
    unread: int


class UnreadCountOut(BaseModel):
    total: int


class MarkReadIn(BaseModel):
    # Omit to mark everything read.
    ids: list[int] | None = None


class NotificationPrefs(BaseModel):
    """One switch per notification type (all on by default)."""

    messages: bool = True
    reviews: bool = True  # new reviews (owners) and owner replies (reviewers)
    offers: bool = True  # new offers from businesses you saved
    new_places: bool = True  # new businesses in your interests
    trending: bool = True
