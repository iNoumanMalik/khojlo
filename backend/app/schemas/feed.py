from pydantic import BaseModel

from app.schemas.business import BusinessCard, CategoryOut


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
