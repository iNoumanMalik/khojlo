"""Push notifications and the Notifications list (SRS FR-21, UC-15, BR-14; Module 3)."""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.jobs import trending_digest
from app.models.business import BusinessProfile, Category
from app.models.engagement import BusinessView
from app.models.notification import DeviceToken, Notification
from app.models.user import User
from app.services.promotion_service import local_today
from tests.conftest import TestingSessionLocal, auth, login, register

P = "/api/v1"


def make_user(client, email, *, name="Test User", role="customer", interests=()):
    register(client, email, role=role, full_name=name, interests=list(interests))
    return auth(login(client, email))


def add_device(client, headers, token, platform="android"):
    r = client.put(f"{P}/notifications/devices", headers=headers,
                   json={"token": token, "platform": platform})
    assert r.status_code == 204, r.text


def verify(business_id: int) -> None:
    """What Module 8's admin will do; publishing offers needs it (UC-11)."""
    db = TestingSessionLocal()
    db.get(BusinessProfile, business_id).is_verified = True
    db.commit()
    db.close()


def inbox(client, headers) -> dict:
    r = client.get(f"{P}/notifications", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def device_owners() -> dict[str, str]:
    db = TestingSessionLocal()
    rows = db.execute(select(DeviceToken.token, User.email)
                      .join(User, User.id == DeviceToken.user_id)).all()
    db.close()
    return dict(rows)


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


@pytest.fixture
def cafes():
    db = TestingSessionLocal()
    category = Category(slug="cafes", name="Cafés", tone="emerald")
    db.add(category)
    db.commit()
    category_id = category.id
    db.close()
    return category_id


# ─────────────── devices ───────────────
def test_devices_register_move_between_accounts_and_unregister(client, ali, owner):
    add_device(client, ali, "shared-tablet-token")
    add_device(client, ali, "shared-tablet-token")  # the app registers on every start
    assert device_owners() == {"shared-tablet-token": "ali@khojlo.app"}

    add_device(client, owner, "shared-tablet-token", platform="web")  # someone else signs in
    assert device_owners() == {"shared-tablet-token": "owner@khojlo.app"}

    url = f"{P}/notifications/devices/unregister"
    assert client.post(url, headers=ali, json={"token": "shared-tablet-token"}).status_code == 204
    assert device_owners() == {"shared-tablet-token": "owner@khojlo.app"}  # not Ali's any more
    assert client.post(url, headers=owner, json={"token": "shared-tablet-token"}).status_code == 204
    assert device_owners() == {}


def test_device_registration_is_validated(client, ali):
    bad = client.put(f"{P}/notifications/devices", headers=ali,
                     json={"token": "short", "platform": "android"})
    assert bad.status_code == 422
    assert client.put(f"{P}/notifications/devices",
                      json={"token": "a-long-enough-token", "platform": "web"}).status_code == 401


# ─────────────── triggers ───────────────
def test_owner_is_notified_about_a_new_review(client, business, owner, ali, pushes):
    add_device(client, owner, "owner-phone-token")
    r = client.post(f"{P}/businesses/{business}/reviews", headers=ali,
                    json={"rating": 5, "comment": "Best chai in F-7"})
    assert r.status_code == 201, r.text

    [(tokens, message)] = pushes.sent
    assert tokens == ["owner-phone-token"]
    assert message.title == "New 5★ review for Brew & Bloom"
    assert message.body == "Ali R.: Best chai in F-7"
    route = f"/business/{business}/reviews?name=Brew%20%26%20Bloom"
    assert message.data == {"route": route, "kind": "review"}

    [item] = inbox(client, owner)["items"]
    assert (item["kind"], item["route"], item["is_read"]) == ("review", route, False)
    assert inbox(client, ali)["items"] == []


def test_a_rating_without_a_comment_still_reads_well(client, business, owner, ali):
    client.post(f"{P}/businesses/{business}/reviews", headers=ali, json={"rating": 3})
    assert inbox(client, owner)["items"][0]["body"] == "Ali R. rated you ★★★"


def test_reviewer_is_notified_once_about_the_owners_reply(client, business, owner, ali, pushes):
    add_device(client, ali, "ali-phone-token")
    review_id = client.post(f"{P}/businesses/{business}/reviews", headers=ali,
                            json={"rating": 4, "comment": "Nice"}).json()["id"]
    client.put(f"{P}/reviews/{review_id}/reply", headers=owner, json={"text": "Thank you, Ali!"})
    client.put(f"{P}/reviews/{review_id}/reply", headers=owner, json={"text": "Thanks, Ali!"})

    assert pushes.titles() == ["Brew & Bloom replied to your review"]
    [item] = inbox(client, ali)["items"]
    assert item["kind"] == "review_reply" and item["body"] == "Thank you, Ali!"


def test_people_who_saved_a_business_hear_about_its_new_offers(client, business, owner, ali, pushes):
    bob = make_user(client, "bob@khojlo.app")
    add_device(client, ali, "ali-phone-token")
    add_device(client, bob, "bob-phone-token")
    client.post(f"{P}/businesses/{business}/save", headers=ali, json={})

    verify(business)
    today = local_today().isoformat()
    deal = {"deal_type": "percent_off", "deal_value": 20, "start_date": today}
    client.post(f"{P}/businesses/{business}/offers", headers=owner,
                json={"title": "20% off for first-time visitors", "is_active": True, **deal})
    client.post(f"{P}/businesses/{business}/offers", headers=owner,
                json={"title": "Draft deal", **deal})

    [(tokens, message)] = pushes.sent  # only Ali saved it; drafts aren't announced
    assert tokens == ["ali-phone-token"]
    assert (message.title, message.body) == ("New offer at Brew & Bloom",
                                             "20% off for first-time visitors")
    assert message.data["route"] == f"/business/{business}"
    assert inbox(client, bob)["items"] == []


def test_new_businesses_are_announced_to_interested_users(client, owner, cafes, pushes):
    fan = make_user(client, "fan@khojlo.app", interests=["cafes"])
    other = make_user(client, "other@khojlo.app", interests=["gym"])
    add_device(client, fan, "fan-phone-token")
    add_device(client, other, "other-phone-token")

    r = client.post(f"{P}/businesses", headers=owner,
                    json={"name": "Coffee Lab", "tagline": "Experimental brews",
                          "category_id": cafes})
    assert r.status_code == 201, r.text

    [(tokens, message)] = pushes.sent
    assert tokens == ["fan-phone-token"]
    assert (message.title, message.body) == ("New on Khojlo: Coffee Lab", "Experimental brews")
    assert inbox(client, other)["items"] == [] and inbox(client, owner)["items"] == []


def test_dead_tokens_are_forgotten_after_a_push(client, business, owner, ali, pushes):
    add_device(client, owner, "owner-old-phone")
    add_device(client, owner, "owner-new-phone")
    pushes.invalid = {"owner-old-phone"}
    client.post(f"{P}/businesses/{business}/reviews", headers=ali, json={"rating": 5})
    assert device_owners() == {"owner-new-phone": "owner@khojlo.app"}


# ─────────────── settings (BR-14) ───────────────
def test_settings_default_on_and_turned_off_types_are_skipped(client, business, owner, ali, pushes):
    assert client.get(f"{P}/notifications/preferences", headers=owner).json() == {
        "messages": True, "reviews": True, "offers": True, "new_places": True, "trending": True}
    add_device(client, owner, "owner-phone-token")
    r = client.put(f"{P}/notifications/preferences", headers=owner, json={"reviews": False})
    assert r.json()["reviews"] is False and r.json()["offers"] is True

    client.post(f"{P}/businesses/{business}/reviews", headers=ali, json={"rating": 5})
    assert pushes.sent == [] and inbox(client, owner)["items"] == []


# ─────────────── the Notifications list ───────────────
def test_list_unread_count_and_marking_read(client, business, owner, ali):
    for name in ("bob", "cara", "dan"):
        reviewer = make_user(client, f"{name}@khojlo.app", name=name.title())
        client.post(f"{P}/businesses/{business}/reviews", headers=reviewer, json={"rating": 4})
    page = inbox(client, owner)
    assert (page["total"], page["unread"]) == (3, 3)
    assert [i["body"] for i in page["items"]][0] == "Dan rated you ★★★★"  # newest first

    newest = page["items"][0]["id"]
    r = client.post(f"{P}/notifications/read", headers=owner, json={"ids": [newest]})
    assert r.json() == {"total": 2}
    assert client.post(f"{P}/notifications/read", headers=owner, json={}).json() == {"total": 0}
    assert client.get(f"{P}/notifications/unread-count", headers=owner).json() == {"total": 0}
    assert client.post(f"{P}/notifications/read", headers=ali, json={}).json() == {"total": 0}


# ─────────────── trending digest ───────────────
NOW = datetime(2026, 10, 5, 9, 0, tzinfo=timezone.utc)


def _trending_world(client, cafes):
    """Two cafés (one busier this week), a fan of cafés, a gym fan, and the owner."""
    make_user(client, "owner@khojlo.app", role="business_owner")
    make_user(client, "fan@khojlo.app", interests=["cafes"])
    make_user(client, "gymrat@khojlo.app", interests=["gym"])
    db = TestingSessionLocal()
    owner = db.scalar(select(User).where(User.email == "owner@khojlo.app"))
    owner.interests = ["cafes"]  # owners aren't told about their own business
    quiet = BusinessProfile(owner_id=owner.id, category_id=cafes, name="Quiet Corner",
                            rating=4.9, review_count=40)
    busy = BusinessProfile(owner_id=owner.id, category_id=cafes, name="Busy Beans",
                           tagline="Always a queue", rating=4.1, review_count=5)
    db.add_all([quiet, busy])
    db.flush()
    db.add_all([BusinessView(business_id=busy.id, created_at=NOW - timedelta(days=d))
                for d in (1, 2, 3)])
    db.add(BusinessView(business_id=quiet.id, created_at=NOW - timedelta(days=30)))  # too old
    db.commit()
    db.close()


def test_trending_digest_tells_each_interested_user_once(client, cafes):
    _trending_world(client, cafes)
    db = TestingSessionLocal()
    picks = trending_digest.run(db, now=NOW)
    assert [(u.email, b.name) for u, b in picks] == [("fan@khojlo.app", "Busy Beans")]
    item = db.scalar(select(Notification))
    assert (item.title, item.body) == ("Trending in Cafés",
                                       "Busy Beans is popular this week: Always a queue")

    assert trending_digest.run(db, now=NOW + timedelta(hours=2)) == []  # not twice in a day
    assert len(trending_digest.run(db, now=NOW + timedelta(hours=21))) == 1
    db.close()


def test_trending_dry_run_sends_nothing_and_respects_settings(client, cafes, pushes):
    _trending_world(client, cafes)
    db = TestingSessionLocal()
    assert len(trending_digest.run(db, now=NOW, dry_run=True)) == 1
    assert db.scalar(select(Notification)) is None and pushes.sent == []

    fan = db.scalar(select(User).where(User.email == "fan@khojlo.app"))
    fan.notification_prefs = {"trending": False}
    db.commit()
    assert trending_digest.run(db, now=NOW) == []
    db.close()

