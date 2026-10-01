"""Module 8 — the automatic rules (the design's "Spam" section).

Rules only raise flags for an admin: nothing is hidden automatically (BR-13), and fixing
the content clears the flag.
"""
import pytest
from sqlalchemy import select

from app.models.moderation import FlagStatus, ModerationFlag
from app.services.moderation_rules import scan_text
from tests.conftest import TestingSessionLocal
from tests.moderation_support import P, complete_business, make_admin, make_user


def rules_of(text: str, review: bool = False) -> set[str]:
    return {h.rule for h in scan_text(text, review=review)}


# ─────────────── the text rules ───────────────
@pytest.mark.parametrize("text, expected", [
    ("Loved the chai, great service!", set()),
    ("Unisex salon with a skilled team", set()),  # "sex" inside a word isn't a match
    ("Our method is simple: fresh dough daily", set()),  # nor is "meth" in "method"
    ("Weekend brunch for families", set()),
    ("Pay 50% advance via JazzCash to confirm your order", {"advance_payment"}),
    ("Booking fee through Easypaisa pehle bhejein", {"advance_payment"}),
    ("We accept JazzCash and cards", set()),  # taking payment isn't asking for it upfront
    ("Congratulations, you have won a lucky draw! Call now to claim", {"prize_scam"}),
    ("Yeh banda chutiya hai", {"vulgar_language"}),
    ("Total bastards, never again", {"vulgar_language"}),
    ("VIP escort service available", {"adult_services"}),
    ("Charas available on order", {"prohibited_items"}),
    ("Fake CNIC made in one day", {"prohibited_items"}),
])
def test_listing_text(text, expected):
    assert rules_of(text) == expected


@pytest.mark.parametrize("text, expected", [
    ("Great food, visit www.cheapfollowers.pk for deals", {"link_in_review"}),
    ("Call me on 0300 1234567 for a discount", {"phone_in_review"}),
    ("Order via +92 321-7654321", {"phone_in_review"}),
    ("DM on whatsapp for the menu", {"whatsapp_in_review"}),
    ("The biryani was great, 10/10", set()),
])
def test_review_only_rules(text, expected):
    assert rules_of(text, review=True) == expected
    assert rules_of(text) == set()  # listings may share their own contact details


def test_a_hit_shows_where_it_matched():
    [hit] = scan_text("Nice place. Pay the full amount in advance by JazzCash before we deliver.")
    assert hit.label.value == "scam"
    assert hit.detail == "Asks for payment in advance (JazzCash)"
    assert "in advance by JazzCash before we deliver" in hit.excerpt


# ─────────────── flags from real requests ───────────────
def flags(**where) -> list[ModerationFlag]:
    db = TestingSessionLocal()
    query = select(ModerationFlag)
    for field, value in where.items():
        query = query.where(getattr(ModerationFlag, field) == value)
    rows = list(db.scalars(query.order_by(ModerationFlag.id)))
    db.close()
    return rows


@pytest.fixture
def owner(client):
    return make_user(client, "owner@khojlo.app", role="business_owner")


@pytest.fixture
def business(client, owner):
    return complete_business(client, owner)


def test_a_spam_review_is_flagged_and_stays_visible(client, business):
    ali = make_user(client, "ali@khojlo.app", name="Ali Raza")
    r = client.post(f"{P}/businesses/{business['id']}/reviews", headers=ali,
                    json={"rating": 5, "comment": "Cheap likes at www.likes4u.pk"})
    assert r.status_code == 201
    review_id = r.json()["id"]
    [flag] = flags(target_type="review")
    assert (flag.target_id, flag.rule, flag.status) == (review_id, "link_in_review", FlagStatus.open)
    assert "www.likes4u.pk" in flag.excerpt
    # BR-13: flagged content stays up until an admin decides.
    listed = client.get(f"{P}/businesses/{business['id']}/reviews").json()["items"]
    assert [x["id"] for x in listed] == [review_id]

    # Editing the link out clears the flag.
    client.patch(f"{P}/reviews/{review_id}", headers=ali, json={"comment": "Nice coffee"})
    assert flags(target_type="review")[0].status == FlagStatus.cleared


def test_a_scam_listing_is_flagged(client, owner):
    b = complete_business(client, owner, name="Phone Deals",
                          description="Brand new iPhones. Pay 50% advance on JazzCash, "
                                      "delivery the same day.")
    [flag] = flags(target_type="business", target_id=b["id"])
    assert flag.label.value == "scam" and flag.rule == "advance_payment"


def test_the_same_phone_under_another_owner_is_a_duplicate(client, owner, business):
    # The same owner opening a second branch with one number is fine.
    second = complete_business(client, owner, name="Brew & Bloom G-9", lat=33.69, lng=73.03)
    assert flags(target_type="business", target_id=second["id"]) == []

    rival = make_user(client, "rival@khojlo.app", role="business_owner")
    copy = complete_business(client, rival, name="Brew and Bloom Café", lat=34.0, lng=73.2,
                             phone="0300 1112233")
    rules = {f.rule for f in flags(target_type="business", target_id=copy["id"])}
    assert rules == {"duplicate_phone"}


def test_the_same_name_next_door_under_another_owner_is_a_duplicate(client, business):
    rival = make_user(client, "rival@khojlo.app", role="business_owner")
    copy = complete_business(client, rival, name="Brew & Bloom", phone="0333 9998877",
                             lat=33.7216, lng=73.0528)
    [flag] = flags(target_type="business", target_id=copy["id"])
    assert flag.rule == "duplicate_listing" and "Brew & Bloom" in flag.detail


def test_an_unrealistic_discount_is_flagged(client, owner, business):
    r = client.post(f"{P}/businesses/{business['id']}/offers", headers=owner, json={
        "title": "Mega sale", "deal_type": "percent_off", "deal_value": 95,
        "start_date": "2026-10-01"})
    assert r.status_code == 201, r.text
    [flag] = flags(target_type="offer")
    assert flag.rule == "extreme_discount" and flag.business_id == business["id"]


def test_the_same_message_to_many_businesses_is_flagged(client):
    spammer = make_user(client, "spam@khojlo.app")
    text = "Hello! Grow your sales with our marketing package, call today"
    for i in range(5):
        shop_owner = make_user(client, f"shop{i}@khojlo.app", role="business_owner")
        b = client.post(f"{P}/businesses", headers=shop_owner, json={"name": f"Shop {i}"}).json()
        c = client.post(f"{P}/conversations", headers=spammer, json={"business_id": b["id"]}).json()
        r = client.post(f"{P}/conversations/{c['id']}/messages", headers=spammer,
                        json={"body": text})
        assert r.status_code == 201
    [flag] = flags(target_type="user")
    assert flag.rule == "mass_messaging" and "5 businesses" in flag.detail
    assert flag.excerpt == ""  # the pattern is shown, never the private messages (SEC-5)


def test_dismissed_flags_do_not_come_back_for_the_same_text(client, owner):
    b = complete_business(client, owner, name="Night Pharmacy",
                          description="Open all night. We stock weed killer for gardens too.")
    [flag] = flags(target_type="business", target_id=b["id"])
    admin = make_admin(client)
    r = client.post(f"{P}/admin/flags/{flag.id}/resolve", headers=admin,
                    json={"decision": "dismiss", "note": "Garden product"})
    assert r.status_code == 200 and r.json()["status"] == "dismissed"
    client.patch(f"{P}/businesses/{b['id']}", headers=owner, json={"tagline": "24/7"})
    assert [f.status for f in flags(target_type="business", target_id=b["id"])] == [
        FlagStatus.dismissed]
