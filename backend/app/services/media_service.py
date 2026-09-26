"""Photo uploads: validate, normalise, resize and store in PostgreSQL.

Every upload is re-encoded, which:
* turns phone photos upright (EXIF orientation) and strips their metadata — including
  any GPS location the camera recorded;
* bounds the size: a large variant for full-width surfaces (feature cards, the business
  page) and a thumbnail for small tiles (list rows, carousels, compare cards);
* writes progressive JPEGs, so big photos appear blurry-first instead of top-down.

Cards crop photos to whatever frame they have (wide banners, squares). To keep the
subject in view, each photo gets a focal point, the centre of its visual detail, which
the app uses to align the crop.
"""
from __future__ import annotations

import io
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from PIL import Image, ImageFilter, ImageOps, UnidentifiedImageError
from sqlalchemy import delete, exists, or_, select
from sqlalchemy.orm import Session

from app.models.media import BusinessPhoto, Media
from app.models.user import User

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
LARGE_EDGE = 1600
THUMB_EDGE = 480
MIN_EDGE = 200
MAX_PIXELS = 50_000_000  # refuse decompression bombs well before they exhaust memory
ACCEPTED_FORMATS = {"JPEG", "MPO", "PNG", "WEBP"}  # MPO: JPEGs from some phone cameras
# An upload that's never attached (an abandoned registration) is removed after this.
ORPHAN_AFTER = timedelta(hours=6)

Image.MAX_IMAGE_PIXELS = MAX_PIXELS


class ImageRejected(ValueError):
    """The upload isn't a usable photo; the message is shown to the user."""


@dataclass(frozen=True)
class ProcessedImage:
    data: bytes
    thumb: bytes
    width: int
    height: int
    focal_x: float
    focal_y: float


def _encode(img: Image.Image, quality: int) -> bytes:
    out = io.BytesIO()
    img.save(out, "JPEG", quality=quality, optimize=True, progressive=True)
    return out.getvalue()


def _flatten(img: Image.Image) -> Image.Image:
    """RGB on white, so transparent PNGs don't turn black as JPEGs."""
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        canvas = Image.new("RGB", rgba.size, (255, 255, 255))
        canvas.paste(rgba, mask=rgba.getchannel("A"))
        return canvas
    return img.convert("RGB")


def focal_point(img: Image.Image) -> tuple[float, float]:
    """Centre of visual detail as fractions of width and height.

    Edges mark detail (a person or a storefront against a plain sky). Their weighted
    centroid is pulled slightly back towards the middle, so one busy corner can't drag
    the crop entirely off the subject.
    """
    w, h = img.size
    scale = 64 / max(w, h)
    small = img.convert("L").resize((max(3, round(w * scale)), max(3, round(h * scale))))
    edges = small.filter(ImageFilter.FIND_EDGES)
    sw, sh = edges.size
    px = edges.load()
    total = sx = sy = 0.0
    for y in range(1, sh - 1):  # FIND_EDGES leaves artefacts on the border
        for x in range(1, sw - 1):
            v = px[x, y]
            if v < 24:  # ignore noise and gentle gradients
                continue
            total += v
            sx += v * (x + 0.5)
            sy += v * (y + 0.5)
    if total == 0:
        return 0.5, 0.5
    cx, cy = sx / total / sw, sy / total / sh
    return round(0.5 + (cx - 0.5) * 0.85, 3), round(0.5 + (cy - 0.5) * 0.85, 3)


def process_image(raw: bytes) -> ProcessedImage:
    if len(raw) > MAX_UPLOAD_BYTES:
        raise ImageRejected("Photos must be 10 MB or smaller.")
    try:
        img = Image.open(io.BytesIO(raw))
        fmt = img.format
        img.load()
    except Image.DecompressionBombError:
        raise ImageRejected("That photo is too large to process.") from None
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError):
        raise ImageRejected("That file isn't a photo we can read. Use JPG, PNG or WebP.") from None
    if fmt not in ACCEPTED_FORMATS:
        raise ImageRejected("That file isn't a photo we can read. Use JPG, PNG or WebP.")

    img = ImageOps.exif_transpose(img)
    if min(img.size) < MIN_EDGE:
        raise ImageRejected(f"That photo is too small. Use one at least {MIN_EDGE} px on each side.")
    img = _flatten(img)

    large = img.copy()
    large.thumbnail((LARGE_EDGE, LARGE_EDGE), Image.Resampling.LANCZOS)
    thumb = img.copy()
    thumb.thumbnail((THUMB_EDGE, THUMB_EDGE), Image.Resampling.LANCZOS)
    fx, fy = focal_point(thumb)
    return ProcessedImage(
        data=_encode(large, 82),
        thumb=_encode(thumb, 78),
        width=large.width,
        height=large.height,
        focal_x=fx,
        focal_y=fy,
    )


def _referenced():
    """SQL condition: the media row is used by a business or as someone's avatar."""
    return or_(
        exists().where(BusinessPhoto.media_id == Media.id),
        exists().where(User.avatar_media_id == Media.id),
    )


def delete_orphans(db: Session, owner_id: int, *, older_than: timedelta = ORPHAN_AFTER) -> int:
    """Remove this user's uploads that were never attached (e.g. an abandoned form)."""
    cutoff = datetime.now(timezone.utc) - older_than
    result = db.execute(
        delete(Media)
        .where(Media.owner_id == owner_id, Media.created_at < cutoff, ~_referenced())
        .execution_options(synchronize_session=False)
    )
    return result.rowcount or 0


def delete_if_unused(db: Session, media_ids: set[int]) -> None:
    """Drop photos that were just removed from a business or profile, if nothing else uses them."""
    if media_ids:
        db.execute(
            delete(Media)
            .where(Media.id.in_(media_ids), ~_referenced())
            .execution_options(synchronize_session=False)
        )


def store_upload(db: Session, owner: User, raw: bytes) -> Media:
    processed = process_image(raw)
    delete_orphans(db, owner.id)
    media = Media(
        key=secrets.token_hex(16),
        owner_id=owner.id,
        content_type="image/jpeg",
        width=processed.width,
        height=processed.height,
        focal_x=processed.focal_x,
        focal_y=processed.focal_y,
        size_bytes=len(processed.data) + len(processed.thumb),
        data=processed.data,
        thumb=processed.thumb,
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return media


class UnknownPhotos(LookupError):
    """Some keys don't exist or belong to someone else."""


def resolve_keys(db: Session, keys: list[str], *, allowed_owner: int,
                 already_attached: set[int] = frozenset()) -> list[Media]:
    """Media rows for `keys`, in order. Each must be the caller's upload or already attached."""
    if not keys:
        return []
    rows = {m.key: m for m in db.scalars(select(Media).where(Media.key.in_(keys)))}
    ordered = []
    for key in keys:
        m = rows.get(key)
        if m is None or (m.owner_id != allowed_owner and m.id not in already_attached):
            raise UnknownPhotos(key)
        ordered.append(m)
    return ordered
