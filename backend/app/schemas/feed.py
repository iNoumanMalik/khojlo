from pydantic import BaseModel

from app.schemas.business import BusinessCard, CategoryOut
from app.schemas.campaign import CampaignBanner


class FeedSection(BaseModel):
    key: str  # featured | because_you_like | trending | nearby | new
    title: str
    subtitle: str = ""
    layout: str  # hero | horizontal | list | stack
    businesses: list[BusinessCard]


class FeedResponse(BaseModel):
    greeting: str
    headline: str
    categories: list[CategoryOut]
    sections: list[FeedSection]
    # Live promotional campaigns, shown as banners at the top of Home.
    campaigns: list[CampaignBanner] = []
