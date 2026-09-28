"""Module 9 — chat and messaging (SRS FR-23–FR-25, UC-13, UC-14, BR-15, BR-16, SEC-5)."""
from datetime import timedelta

import pytest
from sqlalchemy import func, select

from app.models.chat import ConversationReport, Message
from app.models.media import Media
from app.models.user import User
from app.services.media_service import delete_orphans
from tests.conftest import TestingSessionLocal, auth, login, register
from tests.test_photos import jpeg, upload

P = "/api/v1"


def make_user(client, email, *, name="Test User", role="customer"):
    register(client, email, role=role, full_name=name)
    return auth(login(client, email))


def token_of(headers) -> str:
    return headers["Authorization"].removeprefix("Bearer ")


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


def open_chat(client, headers, business_id) -> dict:
    r = client.post(f"{P}/conversations", headers=headers, json={"business_id": business_id})
    assert r.status_code == 200, r.text
    return r.json()


def send(client, headers, conversation_id, body="Do you deliver to G-9?", **extra):
    return client.post(f"{P}/conversations/{conversation_id}/messages", headers=headers,
                       json={"body": body, **extra})


def conversations(client, headers) -> list[dict]:
    r = client.get(f"{P}/conversations", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def unread(client, headers) -> int:
    return client.get(f"{P}/conversations/unread", headers=headers).json()["total"]


def mark_read(client, headers, conversation_id):
    r = client.post(f"{P}/conversations/{conversation_id}/read", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


# ─────────────── UC-13: a customer messages a business ───────────────
def test_customer_messages_a_business_and_the_owner_sees_it(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    assert chat["my_side"] == "customer"
    assert chat["business"]["name"] == "Brew & Bloom"
    assert conversations(client, ali) == []  # listed only once there's a message

    r = send(client, ali, chat["id"], "  Do you deliver to G-9?  ")
    assert r.status_code == 201, r.text
    message = r.json()
    assert message["body"] == "Do you deliver to G-9?"
    assert message["is_mine"] and not message["from_business"]

    [mine] = conversations(client, ali)
    assert mine["unread_count"] == 0  # your own message isn't unread
    assert mine["last_message"]["body"] == "Do you deliver to G-9?"

    [theirs] = conversations(client, owner)
    assert theirs["my_side"] == "business"
    assert theirs["customer"]["name"] == "Ali R."  # first name + last initial
    assert theirs["unread_count"] == 1
    assert not theirs["last_message"]["is_mine"]
    assert unread(client, owner) == 1 and unread(client, ali) == 0


def test_opening_again_reopens_the_same_conversation(client, business, ali):
    first = open_chat(client, ali, business)
    assert open_chat(client, ali, business)["id"] == first["id"]


def test_owners_cant_message_their_own_business(client, business, owner):
    r = client.post(f"{P}/conversations", headers=owner, json={"business_id": business})
    assert r.status_code == 403
    assert "your business" in r.json()["detail"]


def test_unknown_or_unpublished_businesses_cant_be_messaged(client, business, owner, ali):
    assert client.post(f"{P}/conversations", headers=ali,
                       json={"business_id": 999}).status_code == 404
    client.patch(f"{P}/businesses/{business}", headers=owner, json={"is_published": False})
    assert client.post(f"{P}/conversations", headers=ali,
                       json={"business_id": business}).status_code == 404


def test_chat_needs_an_account(client, business):
    assert client.post(f"{P}/conversations", json={"business_id": business}).status_code == 401
    assert client.get(f"{P}/conversations").status_code == 401


# ─────────────── UC-14, FR-25: replies, unread counts and "Seen" ───────────────
def test_owner_replies_and_both_sides_see_read_receipts(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    question = send(client, ali, chat["id"]).json()

    owner_view = client.get(f"{P}/conversations/{chat['id']}", headers=owner).json()
    assert owner_view["my_side"] == "business" and owner_view["unread_count"] == 1
    assert owner_view["business"]["name"] == "Brew & Bloom"

    assert mark_read(client, owner, chat["id"]) == {"last_read_id": question["id"],
                                                    "unread_total": 0}
    # Ali now sees "Seen" under the question.
    ali_view = client.get(f"{P}/conversations/{chat['id']}", headers=ali).json()
    assert ali_view["other_last_read_id"] == question["id"]

    answer = send(client, owner, chat["id"], "Yes, within 5 km.").json()
    assert answer["from_business"] and answer["is_mine"]
    assert unread(client, ali) == 1 and unread(client, owner) == 0
    assert mark_read(client, ali, chat["id"])["unread_total"] == 0
    owner_view = client.get(f"{P}/conversations/{chat['id']}", headers=owner).json()
    assert owner_view["other_last_read_id"] == answer["id"]


def test_marking_read_twice_changes_nothing(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    send(client, ali, chat["id"])
    first = mark_read(client, owner, chat["id"])
    assert mark_read(client, owner, chat["id"]) == first


def test_owner_sees_conversations_for_all_their_businesses(client, business, owner, ali):
    second = client.post(f"{P}/businesses", headers=owner, json={"name": "Zilli Tailors"}).json()
    send(client, ali, open_chat(client, ali, business)["id"], "Coffee?")
    send(client, ali, open_chat(client, ali, second["id"])["id"], "Suits?")
    rows = conversations(client, owner)
    assert [r["business"]["name"] for r in rows] == ["Zilli Tailors", "Brew & Bloom"]  # newest first
    assert unread(client, owner) == 2


# ─────────────── UC-13 exceptions: invalid messages ───────────────
@pytest.mark.parametrize("body, status", [("", 422), ("   ", 422), ("x" * 2001, 422)])
def test_empty_or_too_long_messages_are_refused(client, business, ali, body, status):
    chat = open_chat(client, ali, business)
    r = send(client, ali, chat["id"], body)
    assert r.status_code == status
    assert conversations(client, ali) == []


def test_a_retried_send_is_stored_once(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    first = send(client, ali, chat["id"], client_id="c0ffee00-1111").json()
    again = send(client, ali, chat["id"], client_id="c0ffee00-1111").json()
    assert again["id"] == first["id"] and again["client_id"] == "c0ffee00-1111"
    db = TestingSessionLocal()
    assert db.scalar(select(func.count(Message.id))) == 1
    db.close()
    assert unread(client, owner) == 1


# ─────────────── BR-15, SEC-5: only participants ───────────────
def test_other_people_cant_see_or_use_a_conversation(client, business, ali):
    chat = open_chat(client, ali, business)
    send(client, ali, chat["id"])
    bob = make_user(client, "bob@khojlo.app")
    cid = chat["id"]
    assert client.get(f"{P}/conversations/{cid}", headers=bob).status_code == 404
    assert client.get(f"{P}/conversations/{cid}/messages", headers=bob).status_code == 404
    assert send(client, bob, cid, "Hi").status_code == 404
    assert client.post(f"{P}/conversations/{cid}/read", headers=bob).status_code == 404
    assert client.post(f"{P}/conversations/{cid}/report", headers=bob,
                       json={"reason": "spam"}).status_code == 404
    assert conversations(client, bob) == []


# ─────────────── history ───────────────
def test_history_pages_backwards_and_catches_up(client, business, ali):
    chat = open_chat(client, ali, business)
    ids = [send(client, ali, chat["id"], f"message {i}").json()["id"] for i in range(5)]
    url = f"{P}/conversations/{chat['id']}/messages"

    newest = client.get(url, headers=ali, params={"limit": 2}).json()
    assert [m["id"] for m in newest["items"]] == ids[3:]  # oldest first
    assert newest["has_more"]
    older = client.get(url, headers=ali, params={"limit": 2, "before_id": ids[3]}).json()
    assert [m["id"] for m in older["items"]] == ids[1:3]
    oldest = client.get(url, headers=ali, params={"limit": 2, "before_id": ids[1]}).json()
    assert [m["id"] for m in oldest["items"]] == ids[:1] and not oldest["has_more"]

    caught_up = client.get(url, headers=ali, params={"after_id": ids[2]}).json()
    assert [m["id"] for m in caught_up["items"]] == ids[3:]


# ─────────────── photos ───────────────
def test_photo_messages_are_kept_and_shown(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    key = upload(client, token_of(ali), jpeg()).json()["key"]
    r = send(client, ali, chat["id"], "", photo=key)
    assert r.status_code == 201, r.text
    assert r.json()["photo"]["key"] == key and r.json()["body"] == ""
    assert conversations(client, owner)[0]["last_message"]["photo"]["key"] == key

    # Attached photos are never cleaned up as abandoned uploads.
    db = TestingSessionLocal()
    ali_id = db.scalar(select(User.id).where(User.email == "ali@khojlo.app"))
    delete_orphans(db, ali_id, older_than=timedelta(seconds=-1))
    db.commit()
    assert db.scalar(select(Media).where(Media.key == key)) is not None
    db.close()


def test_you_can_only_attach_your_own_photos(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    owners_photo = upload(client, token_of(owner), jpeg()).json()["key"]
    r = send(client, ali, chat["id"], "Look", photo=owners_photo)
    assert r.status_code == 422
    assert send(client, ali, chat["id"], "", photo="nope").status_code == 422


# ─────────────── reports (Module 8 queue) ───────────────
def test_participants_can_report_a_conversation_once(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    send(client, ali, chat["id"], "Buy followers cheap!!!")
    url = f"{P}/conversations/{chat['id']}/report"
    assert client.post(url, headers=owner, json={"reason": "spam", "note": " ads "}).status_code == 201
    assert client.post(url, headers=owner, json={"reason": "spam"}).status_code == 409
    db = TestingSessionLocal()
    report = db.scalar(select(ConversationReport))
    assert (report.reason.value, report.note, report.status.value) == ("spam", "ads", "open")
    db.close()


# ─────────────── business analytics and the business page ───────────────
def test_dashboard_counts_customer_messages(client, business, ali, owner):
    chat = open_chat(client, ali, business)
    send(client, ali, chat["id"], "One")
    send(client, ali, chat["id"], "Two")
    send(client, owner, chat["id"], "Reply")  # the owner's own messages don't count
    stats = client.get(f"{P}/businesses/{business}/analytics", headers=owner).json()
    assert (stats["messages"], stats["unread_messages"]) == (2, 0)  # replying read them

    send(client, ali, chat["id"], "Three")
    stats = client.get(f"{P}/businesses/{business}/analytics", headers=owner).json()
    assert (stats["messages"], stats["unread_messages"]) == (3, 1)


def test_business_page_says_whether_you_own_it(client, business, owner, ali):
    assert client.get(f"{P}/businesses/{business}", headers=owner).json()["is_owner"] is True
    assert client.get(f"{P}/businesses/{business}", headers=ali).json()["is_owner"] is False
    assert client.get(f"{P}/businesses/{business}").json()["is_owner"] is False


# ─────────────── push to a recipient who isn't in the app ───────────────
def test_message_is_pushed_to_an_offline_recipient(client, business, ali, owner, pushes):
    client.put(f"{P}/notifications/devices", headers=owner,
               json={"token": "owner-phone-token-1", "platform": "android"})
    chat = open_chat(client, ali, business)
    send(client, ali, chat["id"], "Do you deliver to G-9?")
    [(tokens, message)] = pushes.sent
    assert tokens == ["owner-phone-token-1"]
    assert (message.title, message.body) == ("Ali R.", "Do you deliver to G-9?")
    assert message.data == {"route": f"/conversations/{chat['id']}", "kind": "message"}
    assert message.tag == f"conversation-{chat['id']}"

    # Owner replies with a photo; Ali has no device, so nothing more is pushed.
    key = upload(client, token_of(owner), jpeg()).json()["key"]
    send(client, owner, chat["id"], "", photo=key)
    assert len(pushes.sent) == 1


def test_message_notifications_can_be_turned_off(client, business, ali, owner, pushes):
    client.put(f"{P}/notifications/devices", headers=owner,
               json={"token": "owner-phone-token-1", "platform": "android"})
    client.put(f"{P}/notifications/preferences", headers=owner, json={"messages": False})
    send(client, ali, open_chat(client, ali, business)["id"])
    assert pushes.sent == []
