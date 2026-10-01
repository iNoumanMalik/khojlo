"""Module 8 — automatic business verification (SRS FR-14 / UC-12 as reworded; decision 1).

Businesses list immediately; the system gives the Verified badge once every check passes,
and refers the business to an admin when a report or flag needs a person.
"""
from sqlalchemy import select

from app.models.moderation import ActionKind, ModerationAction
from tests.conftest import TestingSessionLocal
from tests.moderation_support import (
    P,
    business_row,
    complete_business,
    inbox_titles,
    make_admin,
    make_user,
    take_storefront,
    verification,
    verify_email,
)


def checks_of(v: dict) -> dict[str, bool]:
    return {c["key"]: c["passed"] for c in v["checks"]}


def actions(business_id: int) -> list[ActionKind]:
    db = TestingSessionLocal()
    rows = db.scalars(select(ModerationAction.action).where(
        ModerationAction.target_type == "business", ModerationAction.target_id == business_id,
    ).order_by(ModerationAction.id))
    out = list(rows)
    db.close()
    return out


def test_a_complete_business_is_verified_automatically(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    verify_email(client, owner, sent_emails)
    b = complete_business(client, owner)
    assert b["is_verified"] is False  # listed straight away, without the badge (decision 1b)

    v = verification(client, owner, b["id"])
    assert v["status"] == "unverified"
    assert checks_of(v) == {"email": True, "profile": True, "storefront": False, "record": True}

    v = take_storefront(client, owner, b["id"])
    assert v["status"] == "verified" and v["is_verified"] is True
    assert v["storefront"] is not None
    assert all(checks_of(v).values())
    assert client.get(f"{P}/businesses/{b['id']}").json()["is_verified"] is True
    assert "Brew & Bloom is verified" in inbox_titles(client, owner)
    assert actions(b["id"]) == [ActionKind.auto_verify]
    stored = business_row(b["id"])
    assert stored.verified_by_id is None and stored.verified_at is not None


def test_checks_say_what_is_missing(client):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    r = client.post(f"{P}/businesses", headers=owner, json={"name": "Half Done"})
    b = r.json()
    take_storefront(client, owner, b["id"])
    v = verification(client, owner, b["id"])
    assert v["status"] == "unverified"
    by_key = {c["key"]: c for c in v["checks"]}
    assert by_key["email"]["passed"] is False
    assert "a map pin" in by_key["profile"]["hint"] and "a photo" in by_key["profile"]["hint"]
    assert by_key["storefront"]["passed"] is True


def test_verifying_the_email_last_also_verifies(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    b = complete_business(client, owner)
    take_storefront(client, owner, b["id"])
    assert verification(client, owner, b["id"])["status"] == "unverified"
    verify_email(client, owner, sent_emails)
    assert verification(client, owner, b["id"])["status"] == "verified"


def test_an_open_report_refers_the_business_to_an_admin(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    verify_email(client, owner, sent_emails)
    b = complete_business(client, owner)
    customer = make_user(client, "ali@khojlo.app")
    r = client.post(f"{P}/businesses/{b['id']}/report", headers=customer,
                    json={"reason": "fake", "note": "No shop at this address"})
    assert r.status_code == 201, r.text

    v = take_storefront(client, owner, b["id"])
    assert v["status"] == "pending_review" and v["is_verified"] is False
    assert checks_of(v)["record"] is False
    assert f"We’re taking a closer look at Brew & Bloom" in inbox_titles(client, owner)

    admin = make_admin(client)
    queue = client.get(f"{P}/admin/businesses", headers=admin,
                       params={"status": "pending_review"}).json()
    assert [row["id"] for row in queue["items"]] == [b["id"]]
    assert queue["items"][0]["open_reports"] == 1

    r = client.post(f"{P}/admin/businesses/{b['id']}/verification", headers=admin,
                    json={"decision": "approve"})
    assert r.status_code == 200, r.text
    detail = r.json()
    assert detail["verification_status"] == "verified" and detail["verified_by"] == "Asma Admin"
    assert actions(b["id"]) == [ActionKind.refer, ActionKind.approve]


def test_admin_asks_for_more_and_the_owner_answers(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    verify_email(client, owner, sent_emails)
    b = complete_business(client, owner)
    admin = make_admin(client)

    r = client.post(f"{P}/admin/businesses/{b['id']}/verification", headers=admin,
                    json={"decision": "request_info"})
    assert r.status_code == 400  # the owner must be told what's needed
    r = client.post(f"{P}/admin/businesses/{b['id']}/verification", headers=admin,
                    json={"decision": "request_info", "note": "Show the signboard clearly."})
    assert r.status_code == 200
    v = verification(client, owner, b["id"])
    assert v["status"] == "needs_info" and v["note"] == "Show the signboard clearly."
    assert v["can_request_review"] is True

    # Nothing to send without a storefront photo.
    r = client.post(f"{P}/businesses/{b['id']}/verification/review", headers=owner, json={})
    assert r.status_code == 409
    take_storefront(client, owner, b["id"])
    assert verification(client, owner, b["id"])["status"] == "needs_info"  # admin's call now
    r = client.post(f"{P}/businesses/{b['id']}/verification/review", headers=owner,
                    json={"note": "New photo with the sign."})
    assert r.status_code == 200 and r.json()["status"] == "pending_review"
    detail = client.get(f"{P}/admin/businesses/{b['id']}", headers=admin).json()
    assert detail["owner_note"] == "New photo with the sign."


def test_revoking_and_rejecting_need_a_reason_and_notify(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    verify_email(client, owner, sent_emails)
    b = complete_business(client, owner)
    take_storefront(client, owner, b["id"])
    admin = make_admin(client)
    r = client.post(f"{P}/admin/businesses/{b['id']}/verification", headers=admin,
                    json={"decision": "revoke", "note": "The storefront photo is of another shop."})
    assert r.status_code == 200
    assert r.json()["verification_status"] == "rejected" and r.json()["is_verified"] is False
    assert "Brew & Bloom’s Verified badge was removed" in inbox_titles(client, owner)
    # Rejected stays rejected however the owner edits it, until they ask again.
    client.patch(f"{P}/businesses/{b['id']}", headers=owner, json={"tagline": "New tagline"})
    assert verification(client, owner, b["id"])["status"] == "rejected"


def test_changing_the_name_needs_a_new_storefront_photo(client, sent_emails):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    verify_email(client, owner, sent_emails)
    b = complete_business(client, owner)
    take_storefront(client, owner, b["id"])

    # Other edits keep the badge.
    r = client.patch(f"{P}/businesses/{b['id']}", headers=owner, json={"tagline": "Now with brunch"})
    assert r.json()["is_verified"] is True

    r = client.patch(f"{P}/businesses/{b['id']}", headers=owner, json={"name": "Brew & Bloom 2"})
    assert r.status_code == 200
    assert r.json()["is_verified"] is False
    v = verification(client, owner, b["id"])
    assert v["status"] == "unverified" and v["storefront"] is None
    assert "Take a new storefront photo to keep your badge" in inbox_titles(client, owner)

    assert take_storefront(client, owner, b["id"])["status"] == "verified"


def test_only_the_owner_sees_the_checklist(client):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    other = make_user(client, "other@khojlo.app", role="business_owner")
    b = client.post(f"{P}/businesses", headers=owner, json={"name": "Mine"}).json()
    assert client.get(f"{P}/businesses/{b['id']}/verification", headers=other).status_code == 403
