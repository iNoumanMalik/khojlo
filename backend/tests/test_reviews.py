"""Module 5 — reviews and ratings (SRS FR-6, UC-7, BR-4; SDD Algorithm 7)."""
from datetime import timedelta

import pytest
from sqlalchemy import select

from app.models.business import BusinessProfile
from app.models.media import Media
from app.models.review import ReportReason, Review, ReviewReport
from app.models.user import User
from app.services.media_service import delete_orphans
from app.services.review_service import display_name, ranking_score, refresh_rating
from tests.conftest import TestingSessionLocal, auth, login, register
from tests.test_photos import jpeg, upload

P = "/api/v1"


def make_user(client, email, *, verified=False, name="Test User", role="customer"):
    register(client, email, role=role, full_name=name)
    if verified:
        db = TestingSessionLocal()
        db.scalar(select(User).where(User.email == email)).is_verified = True
        db.commit()
        db.close()
    return auth(login(client, email))


@pytest.fixture
def owner(client):
    return make_user(client, "owner@khojlo.app", role="business_owner", name="Sara Owner")


@pytest.fixture
def business(client, owner):
    r = client.post(f"{P}/businesses", headers=owner, json={"name": "Brew & Bloom"})
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.fixture
def ali(client):
    return make_user(client, "ali@khojlo.app", name="Ali Hassan Raza")


def write(client, headers, business_id, rating=5, comment="Lovely place", **extra):
    return client.post(f"{P}/businesses/{business_id}/reviews", headers=headers,
                       json={"rating": rating, "comment": comment, **extra})


def page(client, business_id, headers=None, **params):
    r = client.get(f"{P}/businesses/{business_id}/reviews", headers=headers or {}, params=params)
    assert r.status_code == 200, r.text
    return r.json()


def stored_business(business_id):
    db = TestingSessionLocal()
    b = db.get(BusinessProfile, business_id)
    db.close()
    return b


# ─────────────── UC-7 normal flow + Algorithm 7 ───────────────
def test_submitting_a_review_stores_it_and_updates_the_rating(client, business, ali):
    r = write(client, ali, business, rating=4, comment="  Great chai, slow service.  ")
    assert r.status_code == 201, r.text
    review = r.json()
    assert (review["rating"], review["comment"]) == (4, "Great chai, slow service.")
    assert review["author"]["name"] == "Ali R."  # first name + last initial
    assert review["is_mine"] and review["updated_at"] is None

    bob = make_user(client, "bob@khojlo.app")
    assert write(client, bob, business, rating=5, comment="").status_code == 201  # rating only

    b = stored_business(business)
    assert (b.rating, b.review_count) == (4.5, 2)
    summary = page(client, business)["summary"]
    assert summary["average"] == 4.5 and summary["count"] == 2
    assert summary["distribution"] == {"1": 0, "2": 0, "3": 0, "4": 1, "5": 1}

    # Search, cards and the business page read the same recalculated numbers.
    card = client.get(f"{P}/businesses/{business}").json()
    assert (card["rating"], card["review_count"]) == (4.5, 2)


def test_br4_one_review_per_business_per_user(client, business, ali):
    assert write(client, ali, business).status_code == 201
    r = write(client, ali, business, rating=1)
    assert r.status_code == 409
    assert "Edit your review" in r.json()["detail"]


@pytest.mark.parametrize("body", [
    {"rating": 0}, {"rating": 6}, {"rating": 4.5}, {"comment": "no rating"},
    {"rating": 5, "comment": "x" * 1001},
    {"rating": 5, "photos": ["a" * 32, "b" * 32, "c" * 32, "d" * 32]},
], ids=["zero", "six", "half", "missing", "too-long", "four-photos"])
def test_invalid_reviews_are_rejected(client, business, ali, body):
    r = client.post(f"{P}/businesses/{business}/reviews", headers=ali, json=body)
    assert r.status_code == 422


def test_owners_cannot_review_their_own_business(client, business, owner):
    r = write(client, owner, business)
    assert r.status_code == 403
    assert "reply" in r.json()["detail"]
    assert page(client, business, owner)["can_review"] is False


def test_reviewing_needs_an_account_and_a_published_business(client, business, ali):
    assert client.post(f"{P}/businesses/{business}/reviews", json={"rating": 5}).status_code == 401
    db = TestingSessionLocal()
    db.get(BusinessProfile, business).is_published = False
    db.commit()
    db.close()
    assert write(client, ali, business).status_code == 404
    assert write(client, ali, 999).status_code == 404


# ─────────────── edit and delete (UC-7 alternative flow) ───────────────
def test_editing_marks_the_review_edited_and_recalculates(client, business, ali):
    review = write(client, ali, business, rating=2).json()
    r = client.patch(f"{P}/reviews/{review['id']}", headers=ali,
                     json={"rating": 5, "comment": "Came back — much better!"})
    assert r.status_code == 200
    assert r.json()["rating"] == 5 and r.json()["updated_at"] is not None
    assert stored_business(business).rating == 5.0

    # A no-op edit doesn't mark it edited again or fail.
    same = client.patch(f"{P}/reviews/{review['id']}", headers=ali, json={"rating": 5})
    assert same.json()["updated_at"] == r.json()["updated_at"]

    bob = make_user(client, "bob@khojlo.app")
    assert client.patch(f"{P}/reviews/{review['id']}", headers=bob,
                        json={"rating": 1}).status_code == 403


def test_deleting_is_soft_and_frees_the_slot(client, business, ali):
    review = write(client, ali, business, rating=1).json()
    assert client.delete(f"{P}/reviews/{review['id']}", headers=ali).status_code == 204
    b = stored_business(business)
    assert (b.rating, b.review_count) == (0.0, 0)
    db = TestingSessionLocal()
    assert db.get(Review, review["id"]).deleted_at is not None  # kept, as in the ER diagram
    db.close()
    assert page(client, business, ali)["can_review"] is True
    assert write(client, ali, business, rating=4).status_code == 201
    assert client.patch(f"{P}/reviews/{review['id']}", headers=ali,
                        json={"rating": 2}).status_code == 404


# ─────────────── listing ───────────────
def test_verified_reviewers_come_first_by_default(client, business):
    plain = make_user(client, "plain@khojlo.app", name="Plain Person")
    write(client, plain, business, rating=5, comment="Plain but helpful")
    verified = make_user(client, "v@khojlo.app", verified=True, name="Vera Verified")
    write(client, verified, business, rating=3, comment="Verified opinion")

    items = page(client, business)["items"]
    assert [i["author"]["name"] for i in items] == ["Vera V.", "Plain P."]
    assert items[0]["author"]["is_verified"] and not items[1]["author"]["is_verified"]
    # The average still counts both equally.
    assert page(client, business)["summary"]["average"] == 4.0

    recent = page(client, business, sort="recent")["items"]
    assert recent[0]["author"]["name"] == "Vera V."
    assert [i["rating"] for i in page(client, business, sort="lowest")["items"]] == [3, 5]
    assert [i["rating"] for i in page(client, business, sort="highest")["items"]] == [5, 3]


def test_star_filter_paging_and_my_review(client, business, ali):
    for n, stars in enumerate([5, 5, 4, 1]):
        write(client, make_user(client, f"u{n}@khojlo.app"), business, rating=stars)
    write(client, ali, business, rating=3, comment="Mine")

    data = page(client, business, ali, stars=[5, 1])
    assert data["total"] == 3 and {i["rating"] for i in data["items"]} == {5, 1}
    assert data["summary"]["count"] == 5  # the summary ignores the filter
    assert data["mine"]["comment"] == "Mine" and data["mine"]["is_mine"]
    assert data["can_review"] is False

    first = page(client, business, limit=2)
    second = page(client, business, limit=2, offset=2)
    assert len(first["items"]) == len(second["items"]) == 2
    assert {i["id"] for i in first["items"]}.isdisjoint(i["id"] for i in second["items"])
    assert client.get(f"{P}/businesses/{business}/reviews", params={"stars": 6}).status_code == 422


def test_hidden_reviews_leave_lists_and_ratings_but_the_author_still_sees_theirs(
        client, business, ali):
    write(client, make_user(client, "good@khojlo.app"), business, rating=5)
    review = write(client, ali, business, rating=1, comment="spammy").json()
    db = TestingSessionLocal()
    r = db.get(Review, review["id"])
    r.is_approved = False  # what Module 8's moderator action will do
    refresh_rating(db, r.business)
    db.commit()
    db.close()

    public = page(client, business)
    assert [i["rating"] for i in public["items"]] == [5]
    assert public["summary"]["count"] == 1 and stored_business(business).rating == 5.0
    mine = page(client, business, ali)["mine"]
    assert mine["is_visible"] is False
    assert client.get(f"{P}/users/me/reviews", headers=ali).json()[0]["is_visible"] is False


def test_my_reviews(client, business, owner, ali):
    other = client.post(f"{P}/businesses", headers=owner, json={"name": "Forno"}).json()["id"]
    write(client, ali, business, rating=4)
    write(client, ali, other, rating=5)
    mine = client.get(f"{P}/users/me/reviews", headers=ali).json()
    assert [m["business"]["name"] for m in mine] == ["Forno", "Brew & Bloom"]  # newest first
    assert client.get(f"{P}/users/me/reviews").status_code == 401


# ─────────────── owner replies ───────────────
def test_owner_replies_publicly(client, business, owner, ali):
    review = write(client, ali, business, rating=3).json()
    assert page(client, business, owner)["summary"]["unreplied"] == 1
    assert page(client, business, ali)["summary"]["unreplied"] is None  # owners only

    r = client.put(f"{P}/reviews/{review['id']}/reply", headers=owner,
                   json={"text": "Thanks — we've added more staff!"})
    assert r.status_code == 200
    assert r.json()["owner_reply"]["text"] == "Thanks — we've added more staff!"
    assert page(client, business)["items"][0]["owner_reply"]["text"].startswith("Thanks")
    assert page(client, business, owner)["summary"]["unreplied"] == 0
    assert page(client, business, owner)["is_owner"] is True

    assert client.put(f"{P}/reviews/{review['id']}/reply", headers=ali,
                      json={"text": "me too"}).status_code == 403
    assert client.put(f"{P}/reviews/{review['id']}/reply", headers=owner,
                      json={"text": ""}).status_code == 422
    r = client.delete(f"{P}/reviews/{review['id']}/reply", headers=owner)
    assert r.json()["owner_reply"] is None


# ─────────────── helpful votes and reports ───────────────
def test_helpful_votes(client, business, ali):
    review = write(client, ali, business).json()
    bob = make_user(client, "bob@khojlo.app")
    url = f"{P}/reviews/{review['id']}/helpful"

    assert client.put(url, headers=bob).json() == {"helpful_count": 1, "voted_helpful": True}
    assert client.put(url, headers=bob).json()["helpful_count"] == 1  # idempotent
    assert page(client, business, bob)["items"][0]["voted_helpful"] is True
    assert client.put(url, headers=ali).status_code == 400  # not your own
    assert client.delete(url, headers=bob).json() == {"helpful_count": 0, "voted_helpful": False}

    carol = make_user(client, "carol@khojlo.app")
    write(client, carol, business, rating=4, comment="Second")
    client.put(f"{P}/reviews/{review['id']}/helpful", headers=carol)
    assert page(client, business, sort="helpful")["items"][0]["id"] == review["id"]


def test_reports_are_stored_for_moderation(client, business, owner, ali):
    review = write(client, ali, business, rating=1, comment="Never been, 1 star").json()
    url = f"{P}/reviews/{review['id']}/report"
    r = client.post(url, headers=owner, json={"reason": "fake", "note": "Not a customer"})
    assert r.status_code == 201
    assert client.post(url, headers=owner, json={"reason": "spam"}).status_code == 409
    assert client.post(url, headers=ali, json={"reason": "spam"}).status_code == 400
    assert client.post(url, headers=owner, json={"reason": "rude"}).status_code in (409, 422)
    assert page(client, business, owner)["items"][0]["reported"] is True

    db = TestingSessionLocal()
    report = db.scalar(select(ReviewReport))
    assert (report.reason, report.note, report.status.value) == (
        ReportReason.fake, "Not a customer", "open")
    db.close()


# ─────────────── photo reviews ───────────────
def test_photo_reviews(client, business, ali):
    token = ali["Authorization"].split()[1]
    keys = [upload(client, token, jpeg(color=(i * 60, 90, 90))).json()["key"] for i in range(3)]
    r = write(client, ali, business, photos=keys[:2])
    assert r.status_code == 201
    review = r.json()
    assert [p["key"] for p in review["photos"]] == keys[:2]
    assert page(client, business, photos=True)["total"] == 1
    assert page(client, business)["summary"]["with_photos"] == 1

    # Someone else's upload can't be attached.
    bob = make_user(client, "bob@khojlo.app")
    bob_key = upload(client, bob["Authorization"].split()[1], jpeg()).json()["key"]
    assert client.patch(f"{P}/reviews/{review['id']}", headers=ali,
                        json={"photos": [bob_key]}).status_code == 422

    # Swapping photos removes the dropped upload; the old cleanup must not eat attached ones.
    r = client.patch(f"{P}/reviews/{review['id']}", headers=ali, json={"photos": [keys[2]]})
    assert [p["key"] for p in r.json()["photos"]] == [keys[2]]
    db = TestingSessionLocal()
    remaining = set(db.scalars(select(Media.key)))
    db.close()
    assert keys[2] in remaining and keys[0] not in remaining

    db = TestingSessionLocal()
    ali_id = db.scalar(select(User.id).where(User.email == "ali@khojlo.app"))
    delete_orphans(db, ali_id, older_than=timedelta(seconds=-1))
    db.commit()
    assert keys[2] in set(db.scalars(select(Media.key)))
    db.close()


# ─────────────── ranking helpers ───────────────
def test_ranking_score_weighs_by_review_count():
    assert ranking_score(4.8, 200) > ranking_score(5.0, 1)
    assert ranking_score(3.0, 50) > ranking_score(0, 0) == -1.0
    assert display_name("Hassan Raza") == "Hassan R."
    assert display_name("Madonna") == "Madonna" and display_name("  ") == "Khojlo user"


def test_rating_sort_uses_the_weighted_score(client, owner):
    ids = {}
    for name in ("One Hit", "Crowd Pleaser"):
        ids[name] = client.post(f"{P}/businesses", headers=owner, json={"name": name}).json()["id"]
    db = TestingSessionLocal()
    db.get(BusinessProfile, ids["One Hit"]).rating = 5.0
    db.get(BusinessProfile, ids["One Hit"]).review_count = 1
    db.get(BusinessProfile, ids["Crowd Pleaser"]).rating = 4.7
    db.get(BusinessProfile, ids["Crowd Pleaser"]).review_count = 120
    db.commit()
    db.close()
    r = client.get(f"{P}/search", params={"sort": "rating"})
    assert [b["name"] for b in r.json()["items"]][:2] == ["Crowd Pleaser", "One Hit"]
