"""Special offers and promotional campaigns (SRS FR-10, UC-11; SDD Offer, Algorithm 6)."""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.models.business import BusinessProfile, Offer
from app.models.media import Media
from app.models.notification import Notification
from app.services import promotion_service as ps
from app.services.media_service import delete_orphans
from tests.conftest import TestingSessionLocal, auth, login, register
from tests.test_photos import jpeg, upload

P = "/api/v1"
TODAY = ps.local_today()


def day(offset: int) -> str:
    return (TODAY + timedelta(days=offset)).isoformat()


def make_user(client, email, *, role="customer", name="Test User"):
    register(client, email, role=role, full_name=name)
    return auth(login(client, email))


def verify(business_id: int, verified: bool = True) -> None:
    db = TestingSessionLocal()
    db.get(BusinessProfile, business_id).is_verified = verified
    db.commit()
    db.close()


@pytest.fixture
def owner(client):
    return make_user(client, "owner@khojlo.app", role="business_owner", name="Sara Owner")


@pytest.fixture
def business(client, owner):
    r = client.post(f"{P}/businesses", headers=owner, json={
        "name": "Forno Italiano",
        "services": [{"name": "Margherita pizza", "price": "Rs 1,400"},
                     {"name": "Tiramisu", "price": "Rs 900"}],
    })
    assert r.status_code == 201, r.text
    verify(r.json()["id"])
    return r.json()["id"]


def offer(client, owner, business, **fields):
    body = {"title": "25% off pizza", "deal_type": "percent_off", "deal_value": 25,
            "start_date": day(-1), "is_active": True} | fields
    return client.post(f"{P}/businesses/{business}/offers", headers=owner, json=body)


def campaign(client, owner, business, **fields):
    body = {"name": "Weekend Food Festival", "message": "Special deals all weekend!",
            "start_date": day(-1), "end_date": day(5)} | fields
    return client.post(f"{P}/businesses/{business}/campaigns", headers=owner, json=body)


# ─────────────── special offers (UC-11) ───────────────
@pytest.mark.parametrize("deal, label", [
    ({"deal_type": "percent_off", "deal_value": 20}, "20% OFF"),
    ({"deal_type": "amount_off", "deal_value": 2000}, "Rs 2,000 OFF"),
    ({"deal_type": "bogo"}, "BUY 1 GET 1"),
    ({"deal_type": "free_item", "deal_text": "Coffee"}, "FREE COFFEE"),
    ({"deal_type": "other", "deal_text": "Student deal"}, "Student deal"),
])
def test_deal_labels(client, owner, business, deal, label):
    r = offer(client, owner, business, **({"deal_value": None} | deal))
    assert r.status_code == 201, r.text
    assert (r.json()["deal_label"], r.json()["status"]) == (label, "active")


@pytest.mark.parametrize("fields, message", [
    ({"start_date": day(5), "end_date": day(1)}, "end date"),  # UC-11 "invalid dates"
    ({"deal_value": 150}, "between 1% and 100%"),
    ({"deal_type": "amount_off", "deal_value": None}, "rupees"),
    ({"deal_type": "free_item", "deal_value": None}, "what's free"),
    ({"deal_type": "other", "deal_value": None, "deal_text": "  "}, "short label"),
    ({"end_date": day(-2), "start_date": day(-9)}, "already ended"),
], ids=["dates", "percent", "amount", "free", "other", "ended"])
def test_invalid_offers_are_explained(client, owner, business, fields, message):
    r = offer(client, owner, business, **fields)
    assert r.status_code == 422
    assert message in r.json()["detail"]


def test_statuses_follow_the_switch_and_the_dates(client, owner, business):
    draft = offer(client, owner, business, title="Draft", is_active=False).json()
    scheduled = offer(client, owner, business, title="Soon", start_date=day(3)).json()
    open_ended = offer(client, owner, business, title="Students", end_date=None).json()
    assert (draft["status"], scheduled["status"], open_ended["status"]) == (
        "draft", "scheduled", "active")
    assert open_ended["end_date"] is None

    # An expired draft can still be kept; the owner just can't switch it on.
    old = offer(client, owner, business, title="Old", is_active=False,
                start_date=day(-20), end_date=day(-10)).json()
    assert old["status"] == "expired"


def test_owner_edits_activates_deactivates_and_deletes(client, owner, business):
    o = offer(client, owner, business, is_active=False).json()
    url = f"{P}/businesses/{business}/offers/{o['id']}"
    r = client.patch(url, headers=owner, json={"title": "30% off pizza", "deal_value": 30,
                                               "is_active": True})
    assert (r.json()["title"], r.json()["deal_label"], r.json()["status"]) == (
        "30% off pizza", "30% OFF", "active")
    assert client.patch(url, headers=owner, json={"is_active": False}).json()["status"] == "draft"
    assert client.patch(url, headers=owner, json={"end_date": None}).json()["end_date"] is None

    stranger = make_user(client, "other@khojlo.app", role="business_owner")
    assert client.patch(url, headers=stranger, json={"title": "Mine"}).status_code == 403

    assert client.delete(url, headers=owner).status_code == 204
    assert client.get(f"{P}/businesses/{business}/offers", headers=owner).json() == []
    assert client.patch(url, headers=owner, json={"title": "x"}).status_code == 404


def test_unverified_businesses_keep_offers_as_drafts(client, owner, business):
    verify(business, False)
    r = offer(client, owner, business)
    assert r.status_code == 403 and "verified" in r.json()["detail"]
    draft = offer(client, owner, business, is_active=False)
    assert draft.status_code == 201
    r = client.patch(f"{P}/businesses/{business}/offers/{draft.json()['id']}", headers=owner,
                     json={"is_active": True})
    assert r.status_code == 403


def test_customers_only_see_live_offers(client, owner, business):
    offer(client, owner, business, title="Live")
    offer(client, owner, business, title="Draft", is_active=False)
    offer(client, owner, business, title="Soon", start_date=day(4))
    customer = make_user(client, "c@khojlo.app")

    public = client.get(f"{P}/businesses/{business}/offers", headers=customer).json()
    assert [o["title"] for o in public] == ["Live"]
    detail = client.get(f"{P}/businesses/{business}").json()
    assert [o["title"] for o in detail["offers"]] == ["Live"] and detail["has_offer"]
    mine = client.get(f"{P}/businesses/{business}/offers", headers=owner).json()
    assert [o["title"] for o in mine] == ["Live", "Draft", "Soon"]

    r = client.get(f"{P}/search", params={"has_offer": True})
    assert [b["name"] for b in r.json()["items"]] == ["Forno Italiano"]


# ─────────────── promotional campaigns ───────────────
def test_a_campaign_links_offers_and_becomes_visible(client, owner, business):
    pizza = offer(client, owner, business).json()
    bogo = offer(client, owner, business, title="Buy 1 get 1 tiramisu", deal_type="bogo",
                 deal_value=None).json()
    services = client.get(f"{P}/businesses/{business}").json()["services"]

    r = campaign(client, owner, business, offer_ids=[bogo["id"], pizza["id"]],
                 service_ids=[services[1]["id"]], is_published=True,
                 terms="Dine-in only.")
    assert r.status_code == 201, r.text
    c = r.json()
    assert (c["status"], c["is_visible"]) == ("active", True)
    assert [o["title"] for o in c["offers"]] == ["Buy 1 get 1 tiramisu", "25% off pizza"]
    assert [s["name"] for s in c["services"]] == ["Tiramisu"]

    # Customers find it three ways: the feed banner, the card badge, the details screen.
    feed = client.get(f"{P}/feed").json()
    [banner] = feed["campaigns"]
    assert (banner["name"], banner["business_name"], banner["offer_count"], banner["top_deal"]) \
        == ("Weekend Food Festival", "Forno Italiano", 2, "BUY 1 GET 1")
    card = client.get(f"{P}/search", params={"q": "forno"}).json()["items"][0]
    assert card["active_campaign"] == {"id": c["id"], "name": "Weekend Food Festival"}
    public = client.get(f"{P}/campaigns/{c['id']}").json()
    assert public["business"]["name"] == "Forno Italiano" and public["terms"] == "Dine-in only."


def test_publishing_rules(client, owner, business):
    draft_offer = offer(client, owner, business, is_active=False).json()
    live = offer(client, owner, business, title="Live").json()

    r = campaign(client, owner, business, offer_ids=[draft_offer["id"]], is_published=True)
    assert r.status_code == 422 and "active or scheduled offer" in r.json()["detail"]
    assert campaign(client, owner, business, start_date=day(4), end_date=day(1)).status_code == 422

    first = campaign(client, owner, business, offer_ids=[live["id"]], is_published=True)
    assert first.status_code == 201
    second = campaign(client, owner, business, name="Winter Special", offer_ids=[live["id"]],
                      is_published=True)
    assert second.status_code == 409 and "one campaign at a time" in second.json()["detail"]
    # Drafts are fine alongside it; unpublishing the first frees the slot.
    draft = campaign(client, owner, business, name="Winter Special", offer_ids=[live["id"]])
    assert draft.status_code == 201 and draft.json()["status"] == "draft"
    client.patch(f"{P}/businesses/{business}/campaigns/{first.json()['id']}", headers=owner,
                 json={"is_published": False})
    r = client.patch(f"{P}/businesses/{business}/campaigns/{draft.json()['id']}",
                     headers=owner, json={"is_published": True})
    assert r.status_code == 200 and r.json()["status"] == "active"

    verify(business, False)
    r = campaign(client, owner, business, name="Late", offer_ids=[live["id"]],
                 is_published=True)
    assert r.status_code == 403


def test_offers_from_another_business_cant_be_linked(client, owner, business):
    other_owner = make_user(client, "o2@khojlo.app", role="business_owner")
    other = client.post(f"{P}/businesses", headers=other_owner, json={"name": "Other"}).json()
    verify(other["id"])
    theirs = offer(client, other_owner, other["id"]).json()
    r = campaign(client, owner, business, offer_ids=[theirs["id"]])
    assert r.status_code == 422


def test_campaigns_show_only_live_offers_and_hide_without_any(client, owner, business):
    a = offer(client, owner, business, title="A").json()
    b = offer(client, owner, business, title="B").json()
    c = campaign(client, owner, business, offer_ids=[a["id"], b["id"]],
                 is_published=True).json()
    client.patch(f"{P}/businesses/{business}/offers/{a['id']}", headers=owner,
                 json={"is_active": False})
    public = client.get(f"{P}/campaigns/{c['id']}").json()
    assert [o["title"] for o in public["offers"]] == ["B"]
    owner_view = client.get(f"{P}/campaigns/{c['id']}", headers=owner).json()
    assert [o["title"] for o in owner_view["offers"]] == ["A", "B"]

    client.delete(f"{P}/businesses/{business}/offers/{b['id']}", headers=owner)
    assert client.get(f"{P}/campaigns/{c['id']}").status_code == 404  # nothing left to show
    assert client.get(f"{P}/feed").json()["campaigns"] == []
    card = client.get(f"{P}/businesses/{business}").json()
    assert card["active_campaign"] is None
    assert client.get(f"{P}/campaigns/{c['id']}", headers=owner).json()["is_visible"] is False


def test_scheduled_and_draft_campaigns_stay_private(client, owner, business):
    live = offer(client, owner, business).json()
    soon = campaign(client, owner, business, offer_ids=[live["id"]], start_date=day(2),
                    end_date=day(9), is_published=True).json()
    assert soon["status"] == "scheduled"
    assert client.get(f"{P}/campaigns/{soon['id']}").status_code == 404
    assert client.get(f"{P}/businesses/{business}/campaigns").json() == []
    assert len(client.get(f"{P}/businesses/{business}/campaigns", headers=owner).json()) == 1


def test_editing_keeps_links_and_the_banner_survives_cleanup(client, owner, business):
    live = offer(client, owner, business).json()
    token = owner["Authorization"].split()[1]
    first = upload(client, token, jpeg(color=(200, 50, 50))).json()["key"]
    second = upload(client, token, jpeg(color=(50, 50, 200))).json()["key"]
    c = campaign(client, owner, business, offer_ids=[live["id"]], banner=first).json()
    assert c["banner"]["key"] == first
    url = f"{P}/businesses/{business}/campaigns/{c['id']}"

    # Re-sending the same links must not trip the unique constraint.
    r = client.patch(url, headers=owner, json={"offer_ids": [live["id"]], "name": "Renamed"})
    assert r.status_code == 200 and r.json()["name"] == "Renamed"

    r = client.patch(url, headers=owner, json={"banner": second})
    assert r.json()["banner"]["key"] == second
    db = TestingSessionLocal()
    keys = set(db.scalars(select(Media.key)))
    db.close()
    assert second in keys and first not in keys  # the replaced banner was cleaned up

    db = TestingSessionLocal()
    owner_id = db.get(BusinessProfile, business).owner_id
    delete_orphans(db, owner_id, older_than=timedelta(seconds=-1))
    db.commit()
    assert second in set(db.scalars(select(Media.key)))  # attached banners are kept
    db.close()

    assert client.delete(url, headers=owner).status_code == 204
    assert client.get(f"{P}/businesses/{business}/campaigns", headers=owner).json() == []
    assert client.get(f"{P}/businesses/{business}/offers", headers=owner).json() != []


# ─────────────── notifications ───────────────
def saved_by(client, business):
    fan = make_user(client, "fan@khojlo.app")
    r = client.put(f"{P}/notifications/devices", headers=fan,
                   json={"token": "fan-phone-token", "platform": "android"})
    assert r.status_code == 204, r.text
    assert client.post(f"{P}/businesses/{business}/save", headers=fan, json={}).status_code == 200
    return fan


def test_savers_hear_about_a_campaign_once_if_the_owner_opts_in(client, owner, business, pushes):
    live = offer(client, owner, business).json()  # the offer itself announces itself first
    saved_by(client, business)
    pushes.sent.clear()
    quiet = campaign(client, owner, business, name="Quiet", offer_ids=[live["id"]],
                     is_published=True).json()
    assert pushes.sent == []  # the owner didn't opt in
    client.patch(f"{P}/businesses/{business}/campaigns/{quiet['id']}", headers=owner,
                 json={"is_published": False})

    c = campaign(client, owner, business, offer_ids=[live["id"]], is_published=True,
                 notify_savers=True).json()
    [(tokens, message)] = pushes.sent
    assert tokens == ["fan-phone-token"]
    assert (message.title, message.data["route"]) == (
        "Weekend Food Festival at Forno Italiano", f"/campaign/{c['id']}")
    client.patch(f"{P}/businesses/{business}/campaigns/{c['id']}", headers=owner,
                 json={"name": "Weekend Festival"})
    assert len(pushes.sent) == 1  # never repeated


def test_scheduled_items_announce_themselves_when_they_start(client, owner, business, pushes):
    saved_by(client, business)
    soon = offer(client, owner, business, start_date=day(2)).json()
    campaign(client, owner, business, offer_ids=[soon["id"]], start_date=day(2), end_date=day(6),
             is_published=True, notify_savers=True)
    assert pushes.sent == []

    db = TestingSessionLocal()
    later = datetime.now(timezone.utc) + timedelta(days=2)
    jobs = ps.due_notices(db, later)
    db.commit()
    for job in jobs:
        job()
    assert sorted(m.title for _, m in pushes.sent) == [
        "New offer at Forno Italiano", "Weekend Food Festival at Forno Italiano"]
    assert ps.due_notices(db, later) == []  # each is announced once
    assert db.scalar(select(Notification).where(Notification.route.like("/campaign/%")))
    db.close()


def test_deal_label_and_state_helpers():
    o = Offer(title="x", deal_type="percent_off", deal_value=12.5, deal_text="",
              start_date=TODAY, end_date=None, is_active=True)
    assert ps.deal_label(o) == "12.5% OFF"
    assert ps.offer_state(o, TODAY) is ps.PromoState.active
    o.end_date = TODAY - timedelta(days=1)
    assert ps.offer_state(o, TODAY) is ps.PromoState.expired
