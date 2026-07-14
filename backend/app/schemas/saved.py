from pydantic import BaseModel, ConfigDict, Field

from app.schemas.business import BusinessCard


class SavedListCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    tone: str = "gold"


class SavedListOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    tone: str
    count: int = 0
    businesses: list[BusinessCard] = Field(default_factory=list)


class SaveToListRequest(BaseModel):
    list_id: int | None = None  # when None, save to (or create) the default list
