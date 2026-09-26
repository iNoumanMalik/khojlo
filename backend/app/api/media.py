"""Photo upload and delivery (business photos and profile pictures).

Upload first, then attach the returned key to a business (`photos` on create, or
PUT /businesses/{id}/photos) or to your profile (`avatar` on PATCH /users/me).
"""
from fastapi import APIRouter, Depends, File, HTTPException, Path, UploadFile
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.media import Media
from app.models.user import User
from app.schemas.media import PhotoOut
from app.services.media_service import MAX_UPLOAD_BYTES, ImageRejected, store_upload

router = APIRouter(prefix="/media", tags=["media"])

UNPROCESSABLE = 422
TOO_LARGE = 413
# A key never points at different bytes, so browsers and the app may cache for a year.
CACHE_FOREVER = "public, max-age=31536000, immutable"
MediaKey = Path(pattern=r"^[0-9a-f]{32}$")


@router.post("", response_model=PhotoOut, status_code=201)
def upload_photo(
    file: UploadFile = File(description="A JPG, PNG or WebP photo, up to 10 MB"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Media:
    raw = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=TOO_LARGE, detail="Photos must be 10 MB or smaller.")
    try:
        return store_upload(db, user, raw)
    except ImageRejected as exc:
        raise HTTPException(status_code=UNPROCESSABLE, detail=str(exc)) from None


def _serve(db: Session, key: str, column) -> Response:
    blob = db.execute(select(column).where(Media.key == key)).scalar_one_or_none()
    if blob is None:
        raise HTTPException(status_code=404, detail="Photo not found")
    return Response(content=blob, media_type="image/jpeg",
                    headers={"Cache-Control": CACHE_FOREVER})


@router.get("/{key}", response_class=Response, responses={200: {"content": {"image/jpeg": {}}}})
def photo(key: str = MediaKey, db: Session = Depends(get_db)) -> Response:
    """The large variant (up to 1600 px on the long edge)."""
    return _serve(db, key, Media.data)


@router.get("/{key}/thumb", response_class=Response,
            responses={200: {"content": {"image/jpeg": {}}}})
def photo_thumb(key: str = MediaKey, db: Session = Depends(get_db)) -> Response:
    """The thumbnail (up to 480 px on the long edge)."""
    return _serve(db, key, Media.thumb)
