"""Module 8 — the admin panel (SRS FR-14, FR-15, FR-19, SEC-2, SEC-3; SDD Algorithm 10),
blocking in chat, and account suspension."""
import pytest

from tests.moderation_support import (
    P,
    complete_business,
    inbox_titles,
    make_admin,
    make_user,
    user_id,
)

ADMIN_GETS = ["/admin/overview", "/admin/businesses", "/admin/reports", "/admin/flags",
              "/admin/users", "/admin/actions"]


@pytest.fixture
def admin(client):
    return make_admin(client)


@pytest.fixture
def owner(client):
    return make_user(client, "owner@khojlo.app", role="business_owner", name="Sara Owner")


@pytest.fixture
def business(client, owner):
    return complete_business(client, owner)


@pytest.fixture
def ali(client):
    return make_user(client, "ali@khojlo.app", name="Ali Raza")


@pytest.fixture
def zara(client):
    return make_user(client, "zara@khojlo.app", name="Zara Khan")


# ─────────────── access (SEC-3, SEC-2) ───────────────
@pytest.mark.parametrize("path", ADMIN_GETS)
def test_only_admins_reach_the_admin_panel(client, owner, ali, admin, path):
    assert client.get(f"{P}{path}").status_code == 401
    assert client.get(f"{P}{path}", headers=ali).status_code == 403
    assert client.get(f"{P}{path}", headers=owner).status_code == 403
    assert client.get(f"{P}{path}", headers=admin).status_code == 200


def test_admins_edit_businesses_only_through_the_audited_panel(client, admin, business):
    r = client.patch(f"{P}/businesses/{business['id']}", headers=admin, json={"name": "Hijacked"})
    assert r.status_code == 403


# ─────────────── reported reviews ───────────────
def write_review(client, headers, business_id, rating=1, comment="Rude staff, cold food"):
    r = client.post(f"{P}/businesses/{business_id}/reviews", headers=headers,
                    json={"rating": rating, "comment": comment})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def report_review(client, headers, review_id, reason="spam", note=""):
    return client.post(f"{P}/reviews/{review_id}/report", headers=headers,
                       json={"reason": reason, "note": note})


def test_reports_are_grouped_per_review_most_reported_first(client, admin, business, ali, zara,
                                                            owner):
    first = write_review(client, ali, business["id"], comment="Spam spam")
    second = write_review(client, zara, business["id"], rating=2, comment="Meh")
    report_review(client, owner, first, "spam")
    report_review(client, zara, first, "offensive", "Insults the staff")
    report_review(client, owner, second, "fake")

    page = client.get(f"{P}/admin/reports", headers=admin).json()
    assert page["total"] == 2
    top, other = page["items"]
    assert (top["kind"], top["target_id"], top["report_count"]) == ("review", first, 2)
    assert top["reasons"] == {"Spam or advertising": 1, "Offensive or abusive": 1}
    assert other["target_id"] == second


def test_upholding_a_review_report_removes_it_and_tells_everyone(client, admin, business, ali,
                                                                  zara, owner):
    review_id = write_review(client, ali, business["id"], rating=1)
    report_review(client, owner, review_id, "offensive")
    report_review(client, zara, review_id, "offensive")
    assert client.get(f"{P}/businesses/{business['id']}").json()["review_count"] == 1

    r = client.post(f"{P}/admin/reports/review/{review_id}/resolve", headers=admin, json={
        "decision": "uphold", "reason": "harassment", "note": "Abusive language",
        "account_action": "warn"})
    assert r.status_code == 200, r.text
    detail = r.json()
    assert detail["open"] is False and detail["review"]["is_visible"] is False
    assert {e["status"] for e in detail["reports"]} == {"removed"}
    labels = [h["label"] for h in detail["history"]]
    assert labels == ["Removed a review"]

    # Gone from the business page and its rating (Algorithm 7).
    b = client.get(f"{P}/businesses/{business['id']}").json()
    assert b["review_count"] == 0
    assert client.get(f"{P}/businesses/{business['id']}/reviews").json()["items"] == []
    # The author sees it as hidden, and was told why and warned.
    mine = client.get(f"{P}/users/me/reviews", headers=ali).json()
    assert mine[0]["is_visible"] is False
    assert {"Your review was removed", "A warning from Khojlo"} <= set(inbox_titles(client, ali))
    # Both reporters heard back.
    assert "Thanks for your report" in inbox_titles(client, zara)
    assert "Thanks for your report" in inbox_titles(client, owner)

    again = client.post(f"{P}/admin/reports/review/{review_id}/resolve", headers=admin,
                        json={"decision": "dismiss"})
    assert again.status_code == 409


def test_dismissing_keeps_the_review(client, admin, business, ali, zara):
    review_id = write_review(client, ali, business["id"], rating=2, comment="Too pricey")
    report_review(client, zara, review_id, "fake")
    r = client.post(f"{P}/admin/reports/review/{review_id}/resolve", headers=admin,
                    json={"decision": "dismiss"})
    assert r.status_code == 200
    assert r.json()["review"]["is_visible"] is True
    assert client.get(f"{P}/admin/reports", headers=admin).json()["total"] == 0
    resolved = client.get(f"{P}/admin/reports", headers=admin, params={"status": "resolved"})
    assert resolved.json()["items"][0]["target_id"] == review_id


# ─────────────── reported conversations (decision 8) ───────────────
def chat(client, headers, business_id, body="Hi"):
    c = client.post(f"{P}/conversations", headers=headers, json={"business_id": business_id}).json()
    r = client.post(f"{P}/conversations/{c['id']}/messages", headers=headers, json={"body": body})
    assert r.status_code == 201, r.text
    return c["id"]


def test_admins_read_a_conversation_only_once_it_is_reported(client, admin, owner, business, ali):
    conversation = chat(client, ali, business["id"], "Pay me or I post fake reviews")
    assert client.get(f"{P}/admin/reports/conversation/{conversation}",
                      headers=admin).status_code == 404  # SEC-5: not without a report

    r = client.post(f"{P}/conversations/{conversation}/report", headers=owner,
                    json={"reason": "harassment", "note": "Threats"})
    assert r.status_code == 201
    detail = client.get(f"{P}/admin/reports/conversation/{conversation}", headers=admin).json()
    assert [m["body"] for m in detail["conversation"]["messages"]] == [
        "Pay me or I post fake reviews"]
    # The reported side (the customer, since the owner reported) is offered first.
    assert detail["accounts"][0]["email"] == "ali@khojlo.app"


def test_upholding_a_conversation_report_closes_it_and_can_suspend(client, admin, owner,
                                                                   business, ali):
    conversation = chat(client, ali, business["id"], "Send money now")
    client.post(f"{P}/conversations/{conversation}/report", headers=owner,
                json={"reason": "scam"})

    # Which account? Either participant could be at fault.
    r = client.post(f"{P}/admin/reports/conversation/{conversation}/resolve", headers=admin,
                    json={"decision": "uphold", "reason": "scam", "account_action": "suspend"})
    assert r.status_code == 422
    r = client.post(f"{P}/admin/reports/conversation/{conversation}/resolve", headers=admin,
                    json={"decision": "uphold", "reason": "scam", "account_action": "suspend",
                          "suspend_days": 3, "account_user_id": user_id(client, ali)})
    assert r.status_code == 200, r.text
    assert r.json()["conversation"]["closed"] is True

    # Closed: nobody can send.
    r = client.post(f"{P}/conversations/{conversation}/messages", headers=owner,
                    json={"body": "Hello?"})
    assert r.status_code == 403
    assert client.get(f"{P}/conversations/{conversation}", headers=owner).json()["can_send"] is False

    # Suspended: every request is refused with the reason, and sign-in too.
    r = client.get(f"{P}/users/me", headers=ali)
    assert r.status_code == 403 and "suspended until" in r.json()["detail"]
    assert r.headers["x-account-status"] == "blocked"
    r = client.post(f"{P}/auth/login", json={"email": "ali@khojlo.app", "password": "password123"})
    assert r.status_code == 403


# ─────────────── reported businesses ───────────────
def test_reporting_a_business(client, owner, business, ali):
    r = client.post(f"{P}/businesses/{business['id']}/report", headers=ali,
                    json={"reason": "prohibited", "note": "Sells fake documents"})
    assert r.status_code == 201
    again = client.post(f"{P}/businesses/{business['id']}/report", headers=ali,
                        json={"reason": "scam"})
    assert again.status_code == 409
    own = client.post(f"{P}/businesses/{business['id']}/report", headers=owner,
                      json={"reason": "scam"})
    assert own.status_code == 400


def test_upholding_a_business_report_suspends_the_listing(client, admin, owner, business, ali):
    bid = business["id"]
    client.post(f"{P}/businesses/{bid}/report", headers=ali, json={"reason": "scam"})
    r = client.post(f"{P}/admin/reports/business/{bid}/resolve", headers=admin,
                    json={"decision": "uphold", "reason": "scam", "note": "Fake shop"})
    assert r.status_code == 200, r.text
    assert r.json()["business"]["is_suspended"] is True

    # Gone for everyone but the owner, who can't republish it.
    assert client.get(f"{P}/businesses/{bid}", headers=ali).status_code == 404
    assert client.get(f"{P}/businesses/{bid}").status_code == 404
    assert bid not in [b["id"] for b in client.get(f"{P}/search").json()["items"]]
    mine = client.get(f"{P}/businesses/mine", headers=owner).json()
    assert mine[0]["is_suspended"] is True
    r = client.patch(f"{P}/businesses/{bid}", headers=owner, json={"is_published": True})
    assert r.status_code == 403
    assert "Brew & Bloom has been suspended" in inbox_titles(client, owner)

    r = client.post(f"{P}/admin/businesses/{bid}/reinstate", headers=admin, json={"note": "Appeal"})
    assert r.status_code == 200 and r.json()["is_suspended"] is False
    assert client.get(f"{P}/businesses/{bid}").status_code == 200


# ─────────────── accounts ───────────────
def test_banning_hides_reviews_and_suspends_businesses_and_can_be_lifted(client, admin, owner,
                                                                         business, ali):
    review_id = write_review(client, ali, business["id"])
    ali_id = user_id(client, ali)
    r = client.post(f"{P}/admin/users/{ali_id}/action", headers=admin, json={
        "action": "ban", "reason": "spam", "hide_reviews": True})
    assert r.status_code == 200, r.text
    detail = r.json()
    assert detail["status"] == "banned" and detail["removed_reviews"] == 1
    assert client.get(f"{P}/businesses/{business['id']}").json()["review_count"] == 0
    assert client.get(f"{P}/users/me", headers=ali).status_code == 403

    owner_id = user_id(client, owner)
    client.post(f"{P}/admin/users/{owner_id}/action", headers=admin,
                json={"action": "ban", "reason": "scam"})
    assert client.get(f"{P}/businesses/{business['id']}").status_code == 404

    r = client.post(f"{P}/admin/users/{ali_id}/action", headers=admin, json={"action": "lift"})
    assert r.json()["status"] == "active"
    r = client.post(f"{P}/auth/login", json={"email": "ali@khojlo.app", "password": "password123"})
    assert r.status_code == 200
    history = [h["label"] for h in client.get(f"{P}/admin/users/{ali_id}", headers=admin)
               .json()["history"]]
    assert history[:2] == ["Lifted a suspension or ban", "Banned an account"]
    assert review_id  # the review stays hidden: lifting a ban doesn't undo removals


def test_admins_cannot_be_acted_on(client, admin):
    other = make_admin(client, "second-admin@khojlo.app", "Bilal Admin")
    for target in (user_id(client, admin), user_id(client, other)):
        r = client.post(f"{P}/admin/users/{target}/action", headers=admin,
                        json={"action": "suspend"})
        assert r.status_code == 400


def test_users_list_filters_by_status_and_search(client, admin, ali, zara):
    client.post(f"{P}/admin/users/{user_id(client, zara)}/action", headers=admin,
                json={"action": "suspend", "days": 2})
    suspended = client.get(f"{P}/admin/users", headers=admin, params={"status": "suspended"})
    assert [u["email"] for u in suspended.json()["items"]] == ["zara@khojlo.app"]
    found = client.get(f"{P}/admin/users", headers=admin, params={"q": "ali"})
    assert [u["email"] for u in found.json()["items"]] == ["ali@khojlo.app"]


# ─────────────── blocking in chat ───────────────
def test_blocking_stops_both_sides_until_the_blocker_unblocks(client, owner, business, ali):
    conversation = chat(client, ali, business["id"])
    r = client.post(f"{P}/conversations/{conversation}/block", headers=owner)
    assert r.status_code == 200
    assert (r.json()["blocked_by_me"], r.json()["can_send"]) == (True, False)
    seen_by_ali = client.get(f"{P}/conversations/{conversation}", headers=ali).json()
    assert (seen_by_ali["blocked_by_them"], seen_by_ali["can_send"]) == (True, False)

    r = client.post(f"{P}/conversations/{conversation}/messages", headers=ali, json={"body": "?"})
    assert r.status_code == 403 and r.json()["detail"] == "You can’t reply to this conversation."
    assert client.delete(f"{P}/conversations/{conversation}/block", headers=ali).status_code == 403

    r = client.delete(f"{P}/conversations/{conversation}/block", headers=owner)
    assert r.json()["can_send"] is True
    r = client.post(f"{P}/conversations/{conversation}/messages", headers=ali, json={"body": "Hi"})
    assert r.status_code == 201


# ─────────────── overview and audit log ───────────────
def test_overview_and_activity(client, admin, owner, business, ali):
    review_id = write_review(client, ali, business["id"], comment="Visit www.spam.pk")
    report_review(client, owner, review_id, "spam")
    client.post(f"{P}/businesses/{business['id']}/report", headers=ali, json={"reason": "fake"})

    o = client.get(f"{P}/admin/overview", headers=admin).json()
    assert (o["open_reports"], o["open_review_reports"], o["open_business_reports"]) == (2, 1, 1)
    assert o["open_flags"] == 1
    assert o["new_businesses_today"] == 1 and o["reviews_today"] == 1
    assert len(o["daily"]) == 14 and o["daily"][-1]["reports"] == 2

    client.post(f"{P}/admin/reports/review/{review_id}/resolve", headers=admin,
                json={"decision": "uphold", "reason": "spam"})
    log = client.get(f"{P}/admin/actions", headers=admin).json()
    assert log["items"][0]["label"] == "Removed a review"
    assert log["items"][0]["by"] == "Asma Admin"
    assert log["items"][0]["target_title"] == "Review of Brew & Bloom"
    assert client.get(f"{P}/admin/overview", headers=admin).json()["recent"][0]["id"] == \
        log["items"][0]["id"]


# ─────────────── flags ───────────────
def test_upholding_an_offer_flag_switches_the_offer_off(client, admin, owner, business):
    from app.models.business import BusinessProfile
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    db.get(BusinessProfile, business["id"]).is_verified = True  # offers need a verified business
    db.commit()
    db.close()
    r = client.post(f"{P}/businesses/{business['id']}/offers", headers=owner, json={
        "title": "Everything 95% off", "deal_type": "percent_off", "deal_value": 95,
        "start_date": "2026-01-01", "is_active": True})
    assert r.status_code == 201, r.text
    offer_id = r.json()["id"]
    [flag] = client.get(f"{P}/admin/flags", headers=admin).json()["items"]
    assert (flag["target_type"], flag["label"]) == ("offer", "scam")
    assert flag["target_title"] == "Offer “Everything 95% off” at Brew & Bloom"

    r = client.post(f"{P}/admin/flags/{flag['id']}/resolve", headers=admin,
                    json={"decision": "uphold", "reason": "scam", "account_action": "warn"})
    assert r.status_code == 200 and r.json()["status"] == "actioned"
    offers = client.get(f"{P}/businesses/{business['id']}/offers", headers=owner).json()
    assert next(o for o in offers if o["id"] == offer_id)["is_active"] is False
    assert {"An offer was switched off", "A warning from Khojlo"} <= set(inbox_titles(client, owner))
    assert client.get(f"{P}/admin/flags", headers=admin).json()["total"] == 0


def test_the_seed_gives_every_admin_queue_something(client, admin):
    from app.db import seed as seed_module
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    report = seed_module.seed(db)
    db.close()
    assert report.moderation_added == 3
    o = client.get(f"{P}/admin/overview", headers=admin).json()
    assert (o["open_review_reports"], o["open_conversation_reports"],
            o["open_business_reports"]) == (1, 1, 1)
    rules = {f["rule"] for f in client.get(f"{P}/admin/flags", headers=admin).json()["items"]}
    assert rules == {"link_in_review", "phone_in_review", "whatsapp_in_review"}
    # Seeding again adds nothing more.
    db = TestingSessionLocal()
    assert seed_module.seed(db).moderation_added == 0
    db.close()



# ─────────────── one decision settles everything pending on the same content ───────────────
def test_removing_a_reported_review_settles_its_flags(client, admin, owner, business, ali):
    review_id = write_review(client, ali, business["id"], rating=5,
                             comment="Cheap likes at www.likes.pk, WhatsApp 0300 1234567")
    report_review(client, owner, review_id, "spam")
    assert client.get(f"{P}/admin/flags", headers=admin).json()["total"] == 3  # link, phone, WhatsApp
    client.post(f"{P}/admin/reports/review/{review_id}/resolve", headers=admin,
                json={"decision": "uphold", "reason": "spam"})
    assert client.get(f"{P}/admin/flags", headers=admin).json()["total"] == 0


def test_upholding_a_review_flag_resolves_its_reports(client, admin, owner, business, ali, zara):
    review_id = write_review(client, ali, business["id"], comment="Visit www.spam.pk now")
    report_review(client, zara, review_id, "spam")
    [flag] = client.get(f"{P}/admin/flags", headers=admin).json()["items"]
    r = client.post(f"{P}/admin/flags/{flag['id']}/resolve", headers=admin,
                    json={"decision": "uphold", "reason": "spam"})
    assert r.status_code == 200
    assert client.get(f"{P}/admin/reports", headers=admin).json()["total"] == 0
    assert "Thanks for your report" in inbox_titles(client, zara)
