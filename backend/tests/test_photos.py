"""Photo uploads, business galleries (cover + more) and automatic cropping hints."""
import io
from datetime import datetime, timedelta, timezone

import pytest
from PIL import Image, ImageDraw

from app.models.media import Media
from tests.conftest import TestingSessionLocal, auth, login, register

P = "/api/v1"


def jpeg(width=800, height=600, color=(200, 120, 60), exif=None, fmt="JPEG") -> bytes:
    img = Image.new("RGBA" if fmt == "PNG" else "RGB", (width, height), color)
    out = io.BytesIO()
    kwargs = {"exif": exif} if exif is not None else {}
    img.save(out, fmt, **kwargs)
    return out.getvalue()


def upload(client, token, data: bytes, name="photo.jpg"):
    return client.post(f"{P}/media", headers=auth(token),
                       files={"file": (name, data, "application/octet-stream")})


def served(client, url: str) -> Image.Image:
    r = client.get(url)
    assert r.status_code == 200
    assert r.headers["content-type"] == "image/jpeg"
    return Image.open(io.BytesIO(r.content))


@pytest.fixture
def owner(client):
    register(client, "photo-owner@khojlo.app", role="business_owner")
    return login(client, "photo-owner@khojlo.app")


@pytest.fixture
def rival(client):
    register(client, "photo-rival@khojlo.app", role="business_owner")
    return login(client, "photo-rival@khojlo.app")


def keys(client, token, n):
    return [upload(client, token, jpeg(color=(40 * i, 90, 160))).json()["key"] for i in range(n)]


# ─────────────── uploads ───────────────
def test_upload_makes_a_large_photo_and_a_thumbnail(client, owner):
    r = upload(client, owner, jpeg(3000, 2000))
    assert r.status_code == 201, r.text
    body = r.json()
    assert len(body["key"]) == 32
    assert (body["width"], body["height"]) == (1600, 1067)
    assert body["url"] == f"{P}/media/{body['key']}"
    assert body["thumb_url"] == f"{body['url']}/thumb"

    assert served(client, body["url"]).size == (1600, 1067)
    assert served(client, body["thumb_url"]).size == (480, 320)
    assert "immutable" in client.get(body["url"]).headers["cache-control"]


def test_sideways_phone_photos_are_turned_upright_and_lose_their_metadata(client, owner):
    exif = Image.Exif()
    exif[0x0112] = 6  # orientation: rotate 90° clockwise to display
    exif[0x010F] = "PhoneMaker"  # camera make, stands in for GPS & friends
    body = upload(client, owner, jpeg(800, 400, exif=exif)).json()

    assert (body["width"], body["height"]) == (400, 800)
    stored = served(client, body["url"])
    assert stored.size == (400, 800)
    assert dict(stored.getexif()) == {}


def test_transparent_png_becomes_a_jpeg_on_white(client, owner):
    body = upload(client, owner, jpeg(400, 400, color=(0, 0, 0, 0), fmt="PNG"), "logo.png").json()
    assert served(client, body["url"]).getpixel((200, 200)) == (255, 255, 255)


@pytest.mark.parametrize(
    "data, status, message",
    [
        (b"definitely not a photo", 422, "isn't a photo"),
        (jpeg(120, 120), 422, "too small"),
        (b"0" * (10 * 1024 * 1024 + 1), 413, "10 MB"),
    ],
    ids=["not-an-image", "too-small", "too-big"],
)
def test_bad_uploads_are_explained(client, owner, data, status, message):
    r = upload(client, owner, data)
    assert r.status_code == status
    assert message in r.json()["detail"]


def test_uploading_needs_an_account(client):
    assert client.post(f"{P}/media", files={"file": ("a.jpg", jpeg(), "image/jpeg")}).status_code == 401


def test_unknown_photo_is_404(client):
    assert client.get(f"{P}/media/{'0' * 32}").status_code == 404
    assert client.get(f"{P}/media/not-a-key").status_code == 422


def test_focal_point_follows_the_subject(client, owner):
    img = Image.new("RGB", (900, 600), (235, 235, 235))
    ImageDraw.Draw(img).rectangle((650, 380, 820, 540), fill=(20, 30, 40))
    out = io.BytesIO()
    img.save(out, "JPEG")
    body = upload(client, owner, out.getvalue()).json()
    assert body["focal_x"] > 0.6 and body["focal_y"] > 0.6

    plain = upload(client, owner, jpeg()).json()
    assert (plain["focal_x"], plain["focal_y"]) == (0.5, 0.5)


def test_abandoned_uploads_are_cleaned_up(client, owner):
    old, attached = keys(client, owner, 2)
    client.post(f"{P}/businesses", headers=auth(owner), json={"name": "Keeps", "photos": [attached]})
    db = TestingSessionLocal()
    for m in db.query(Media).all():
        m.created_at = datetime.now(timezone.utc) - timedelta(hours=7)
    db.commit()
    db.close()

    upload(client, owner, jpeg())  # any new upload sweeps the uploader's old orphans
    assert client.get(f"{P}/media/{old}").status_code == 404
    assert client.get(f"{P}/media/{attached}").status_code == 200


# ─────────────── business galleries ───────────────
def test_create_with_photos_puts_the_first_on_every_card(client, owner):
    k1, k2 = keys(client, owner, 2)
    r = client.post(f"{P}/businesses", headers=auth(owner),
                    json={"name": "Gallery Café", "photos": [k1, k2]})
    assert r.status_code == 201, r.text
    detail = r.json()
    assert [p["key"] for p in detail["photos"]] == [k1, k2]
    assert detail["cover"]["key"] == k1

    card = client.get(f"{P}/businesses/mine", headers=auth(owner)).json()[0]
    assert card["cover"]["thumb_url"].endswith(f"/{k1}/thumb")
    found = client.get(f"{P}/search", params={"q": "gallery"}).json()["items"][0]
    assert found["cover"]["key"] == k1


def test_reorder_and_remove_photos(client, owner):
    k1, k2, k3 = keys(client, owner, 3)
    biz = client.post(f"{P}/businesses", headers=auth(owner),
                      json={"name": "Shuffle", "photos": [k1, k2]}).json()

    r = client.put(f"{P}/businesses/{biz['id']}/photos", headers=auth(owner),
                   json={"photos": [k3, k2]})
    assert r.status_code == 200, r.text
    assert [p["key"] for p in r.json()["photos"]] == [k3, k2]
    assert r.json()["cover"]["key"] == k3
    assert client.get(f"{P}/media/{k1}").status_code == 404  # removed photos are deleted

    r = client.put(f"{P}/businesses/{biz['id']}/photos", headers=auth(owner), json={"photos": []})
    assert r.json()["photos"] == [] and r.json()["cover"] is None


@pytest.mark.parametrize("problem", ["someone_elses", "unknown", "too_many", "duplicate"])
def test_gallery_rejects_bad_photo_lists(client, owner, rival, problem):
    biz = client.post(f"{P}/businesses", headers=auth(owner), json={"name": "Strict"}).json()
    photos = {
        "someone_elses": keys(client, rival, 1),
        "unknown": ["f" * 32],
        "too_many": keys(client, owner, 11),
        "duplicate": keys(client, owner, 1) * 2,
    }[problem]
    r = client.put(f"{P}/businesses/{biz['id']}/photos", headers=auth(owner),
                   json={"photos": photos})
    assert r.status_code == 422


def test_only_the_owner_can_change_the_gallery(client, owner, rival):
    biz = client.post(f"{P}/businesses", headers=auth(owner), json={"name": "Mine"}).json()
    r = client.put(f"{P}/businesses/{biz['id']}/photos", headers=auth(rival),
                   json={"photos": keys(client, rival, 1)})
    assert r.status_code == 403


def test_deleting_a_business_deletes_its_photos(client, owner):
    (k1,) = keys(client, owner, 1)
    biz = client.post(f"{P}/businesses", headers=auth(owner),
                      json={"name": "Short-lived", "photos": [k1]}).json()
    assert client.delete(f"{P}/businesses/{biz['id']}", headers=auth(owner)).status_code == 204
    assert client.get(f"{P}/media/{k1}").status_code == 404


def test_businesses_without_photos_have_no_cover(client, owner):
    client.post(f"{P}/businesses", headers=auth(owner), json={"name": "Plain"})
    card = client.get(f"{P}/businesses/mine", headers=auth(owner)).json()[0]
    assert card["cover"] is None
