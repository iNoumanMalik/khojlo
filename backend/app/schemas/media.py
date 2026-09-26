from pydantic import BaseModel, ConfigDict


class PhotoOut(BaseModel):
    """An uploaded photo. URLs are paths on this API; clients resolve them against its origin.

    `width`/`height` give the aspect ratio (galleries show photos uncropped); `focal_x`/
    `focal_y` (0–1) say where to anchor crops in fixed-shape frames such as cards.
    """

    model_config = ConfigDict(from_attributes=True)

    key: str
    url: str
    thumb_url: str
    width: int
    height: int
    focal_x: float = 0.5
    focal_y: float = 0.5
