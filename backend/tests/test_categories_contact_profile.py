"""Specific categories + "Other", business phone numbers, and editing your profile."""
import io

import pytest
from PIL import Image

from app.models.business import Category
from tests.conftest import TestingSessionLocal, auth, login, register

P = "/api/v1"


@pytest.fixture
def cats(client):
    """A small catalogue shaped like the real one (the migration installs the full list)."""
    db = TestingSessionLocal()
    rows = [
        Category(slug="other", name="Other", emoji="✨", group_name="Other", sort_order=99),
        Category(slug="tailors", name="Tailors & Fabric", emoji="🧵", group_name="Shopping",
                 sort_order=21, keywords="tailor, darzi, stitching"),
        Category(slug="cafes", name="Cafés", emoji="☕", group_name="Food & Drink",
                 sort_order=11, keywords="coffee, chai"),
        Category(slug="pets", name="Pets & Vets", emoji="🐾", group_name="Services",
                 sort_order=45),
    ]
    db.add_all(rows)
    db.commit()
    ids = {c.slug: c.id for c in rows}
    db.close()
    return ids


@pytest.fixture
def owner(client):
    register(client, "cat-owner@khojlo.app", role="business_owner")
    return login(client, "cat-owner@khojlo.app")


def create(client, token, **payload):
    return client.post(f"{P}/businesses", headers=auth(token), json=payload)


# ─────────────── categories ───────────────
def test_categories_come_grouped_in_display_order_with_counts(client, cats, owner):
    create(client, owner, name="Zilli Tailors", category_id=cats["tailors"])
    body = client.get(f"{P}/categories").json()

    assert [c["slug"] for c in body] == ["cafes", "tailors", "pets", "other"]
    tailors = body[1]
    assert (tailors["emoji"], tailors["group_name"], tailors["business_count"]) == (
        "🧵", "Shopping", 1)
    assert [c["is_other"] for c in body] == [False, False, False, True]


def test_home_only_offers_categories_that_have_businesses(client, cats, owner):
    create(client, owner, name="Zilli Tailors", category_id=cats["tailors"])
    feed = client.get(f"{P}/feed").json()
    assert [c["slug"] for c in feed["categories"]] == ["tailors"]


def test_other_needs_a_description_that_cards_show(client, cats, owner):
    r = create(client, owner, name="Qalam", category_id=cats["other"])
    assert r.status_code == 422
    assert "what kind of business" in r.json()["detail"]

    r = create(client, owner, name="Qalam", category_id=cats["other"],
               custom_category="  Calligraphy   studio ")
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["custom_category"] == "Calligraphy studio"
    assert body["category_label"] == "Calligraphy studio"
    assert body["category_name"] == "Other"


def test_the_description_is_dropped_for_specific_categories(client, cats, owner):
    body = create(client, owner, name="Brew", category_id=cats["cafes"],
                  custom_category="Coffee place").json()
    assert body["custom_category"] is None and body["category_label"] == "Cafés"

    other = create(client, owner, name="Qalam", category_id=cats["other"],
                   custom_category="Calligraphy studio").json()
    r = client.patch(f"{P}/businesses/{other['id']}", headers=auth(owner),
                     json={"category_id": cats["pets"]})
    assert r.json()["custom_category"] is None and r.json()["category_label"] == "Pets & Vets"


def test_unknown_category_is_rejected(client, cats, owner):
    assert create(client, owner, name="Lost", category_id=9999).status_code == 422


def test_search_matches_other_descriptions_and_category_keywords(client, cats, owner):
    create(client, owner, name="Qalam", category_id=cats["other"],
           custom_category="Calligraphy studio")
    create(client, owner, name="Zilli", category_id=cats["tailors"])

    names = lambda q: [b["name"] for b in client.get(f"{P}/search", params={"q": q}).json()["items"]]
    assert names("calligraphy") == ["Qalam"]
    assert names("darzi") == ["Zilli"]

    labels = [s["label"] for s in client.get(f"{P}/search/suggestions", params={"q": "darz"}).json()]
    assert "Tailors & Fabric" in labels


# ─────────────── phone numbers ───────────────
def test_business_phone_is_tidied_validated_and_clearable(client, cats, owner):
    body = create(client, owner, name="Callable", phone=" 0300   1234567 ").json()
    assert body["phone"] == "0300 1234567"

    for bad in ("call me", "12", "+92 300 1234567 8901 2345"):
        assert create(client, owner, name="Bad", phone=bad).status_code == 422

    r = client.patch(f"{P}/businesses/{body['id']}", headers=auth(owner), json={"phone": ""})
    assert r.json()["phone"] is None


# ─────────────── profile ───────────────
def photo_key(client, token) -> str:
    out = io.BytesIO()
    Image.new("RGB", (400, 400), (90, 60, 140)).save(out, "JPEG")
    r = client.post(f"{P}/media", headers=auth(token),
                    files={"file": ("me.jpg", out.getvalue(), "image/jpeg")})
    return r.json()["key"]


def test_edit_profile_name_phone_and_photo(client):
    register(client, "me@khojlo.app")
    token = login(client, "me@khojlo.app")
    key = photo_key(client, token)

    r = client.patch(f"{P}/users/me", headers=auth(token),
                     json={"full_name": "  Ayesha   Khan ", "phone": "+92 300 1234567",
                           "avatar": key, "avatar_tone": "plum"})
    assert r.status_code == 200, r.text
    me = r.json()
    assert (me["full_name"], me["initials"], me["phone"]) == ("Ayesha Khan", "AK", "+92 300 1234567")
    assert me["avatar"]["key"] == key and me["avatar_tone"] == "plum"
    assert client.get(f"{P}/users/me", headers=auth(token)).json()["avatar"]["key"] == key

    # Replacing or removing the photo deletes the old one; other fields stay put.
    r = client.patch(f"{P}/users/me", headers=auth(token), json={"avatar": None})
    assert r.json()["avatar"] is None and r.json()["phone"] == "+92 300 1234567"
    assert client.get(f"{P}/media/{key}").status_code == 404


def test_profile_rejects_bad_input(client):
    register(client, "me@khojlo.app")
    register(client, "other@khojlo.app")
    token = login(client, "me@khojlo.app")
    theirs = photo_key(client, login(client, "other@khojlo.app"))

    assert client.patch(f"{P}/users/me", headers=auth(token), json={"full_name": "  "}).status_code == 422
    assert client.patch(f"{P}/users/me", headers=auth(token), json={"phone": "abc"}).status_code == 422
    assert client.patch(f"{P}/users/me", headers=auth(token), json={"avatar": theirs}).status_code == 422
