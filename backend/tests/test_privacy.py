"""Privacy consent and account deletion (SRS FR-31, FR-32)."""
from sqlalchemy import func, select

from app.core.privacy import PRIVACY_POLICY_VERSION
from app.models.business import BusinessProfile
from app.models.chat import Conversation, Message
from app.models.engagement import BusinessView
from app.models.media import Media
from app.models.notification import DeviceToken
from app.models.review import Review
from app.models.search import SearchQuery
from app.models.user import User
from tests.conftest import TestingSessionLocal, auth, login, register
from tests.test_chat import open_chat, send
from tests.test_photos import jpeg, upload

P = "/api/v1"


def make_user(client, email, *, name="Test User", role="customer"):
    register(client, email, role=role, full_name=name)
    return auth(login(client, email))


def me(client, headers) -> dict:
    r = client.get(f"{P}/users/me", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def count(model, *where) -> int:
    db = TestingSessionLocal()
    try:
        return db.scalar(select(func.count()).select_from(model).where(*where))
    finally:
        db.close()


def business_row(business_id) -> BusinessProfile:
    db = TestingSessionLocal()
    b = db.get(BusinessProfile, business_id)
    db.close()
    return b


def delete_me(client, headers, password="password123"):
    return client.request("DELETE", f"{P}/users/me", headers=headers, json={"password": password})


# ─────────────── FR-31: consent ───────────────
def test_signing_up_records_consent_to_the_current_policy(client):
    user = me(client, make_user(client, "a@khojlo.app"))
    assert user["needs_privacy_consent"] is False
    assert user["privacy_policy_version"] == PRIVACY_POLICY_VERSION
    assert user["privacy_consent_at"] is not None


def test_signing_up_needs_the_current_policy(client):
    assert register(client, "b@khojlo.app", privacy_policy_version="2020-01-01").status_code == 409
    r = client.post(f"{P}/auth/register", json={
        "full_name": "No Consent", "email": "c@khojlo.app", "password": "password123"})
    assert r.status_code == 422
    assert count(User) == 0


def test_google_sign_ups_are_asked_to_agree(client, monkeypatch):
    monkeypatch.setattr("app.api.auth.verify_google_id_token",
                        lambda _: {"sub": "g-1", "email": "g@khojlo.app", "name": "Gul"})
    tokens = client.post(f"{P}/auth/google", json={"id_token": "x"}).json()
    headers = auth(tokens["access_token"])
    assert me(client, headers)["needs_privacy_consent"] is True
    assert me(client, headers)["has_password"] is False

    url = f"{P}/users/me/privacy-consent"
    assert client.post(url, headers=headers,
                       json={"policy_version": "2020-01-01"}).status_code == 409
    r = client.post(url, headers=headers, json={"policy_version": PRIVACY_POLICY_VERSION})
    assert r.status_code == 200, r.text
    assert r.json()["needs_privacy_consent"] is False


def test_a_new_policy_version_asks_everyone_again(client, monkeypatch):
    headers = make_user(client, "d@khojlo.app")
    monkeypatch.setattr("app.models.user.PRIVACY_POLICY_VERSION", "2099-01-01")
    assert me(client, headers)["needs_privacy_consent"] is True


# ─────────────── FR-32: account deletion ───────────────
def test_deleting_needs_the_password(client):
    headers = make_user(client, "e@khojlo.app")
    assert delete_me(client, headers, password="wrong-password").status_code == 403
    assert client.request("DELETE", f"{P}/users/me", headers=headers, json={}).status_code == 403
    assert count(User) == 1


def test_google_only_accounts_delete_without_a_password(client, monkeypatch):
    monkeypatch.setattr("app.api.auth.verify_google_id_token",
                        lambda _: {"sub": "g-2", "email": "h@khojlo.app"})
    headers = auth(client.post(f"{P}/auth/google", json={"id_token": "x"}).json()["access_token"])
    r = client.request("DELETE", f"{P}/users/me", headers=headers, json={})
    assert r.status_code == 204, r.text
    assert count(User) == 0


def test_deleting_a_customer_removes_their_data_and_fixes_counters(client):
    owner = make_user(client, "owner@khojlo.app", role="business_owner", name="Sara Owner")
    business = client.post(f"{P}/businesses", headers=owner, json={"name": "Brew & Bloom"}).json()
    business_id = business["id"]
    ali = make_user(client, "ali@khojlo.app", name="Ali Raza")
    bob = make_user(client, "bob@khojlo.app", name="Bob")
    ali_token = ali["Authorization"].split()[1]

    # Ali's footprint: a photo, a review, a helpful vote, a save, a view, a chat,
    # a device, a search.
    avatar = upload(client, ali_token, jpeg()).json()["key"]
    assert client.patch(f"{P}/users/me", headers=ali, json={"avatar": avatar}).status_code == 200
    client.post(f"{P}/businesses/{business_id}/reviews", headers=ali, json={"rating": 5})
    bobs = client.post(f"{P}/businesses/{business_id}/reviews", headers=bob,
                       json={"rating": 3}).json()
    assert client.put(f"{P}/reviews/{bobs['id']}/helpful",
                      headers=ali).json()["helpful_count"] == 1
    client.post(f"{P}/businesses/{business_id}/save", headers=ali, json={})
    client.get(f"{P}/businesses/{business_id}", headers=ali)
    chat = open_chat(client, ali, business_id)
    send(client, ali, chat["id"])
    client.put(f"{P}/notifications/devices", headers=ali, json={"token": "ali-device-token", "platform": "web"})
    client.get(f"{P}/search", headers=ali, params={"q": "coffee", "record": True})

    assert count(SearchQuery, SearchQuery.user_id.is_not(None)) == 1
    assert count(Message) == 1 and count(DeviceToken) == 1 and count(BusinessView) == 1
    before = business_row(business_id)
    assert (before.rating, before.review_count, before.save_count) == (4.0, 2, 1)

    assert delete_me(client, ali).status_code == 204

    assert client.get(f"{P}/users/me", headers=ali).status_code == 401
    assert client.post(f"{P}/auth/login", json={
        "email": "ali@khojlo.app", "password": "password123"}).status_code == 401
    assert count(User, User.email == "ali@khojlo.app") == 0
    assert count(Media) == 0
    assert count(Review) == 1
    assert count(Conversation) == 0 and count(Message) == 0
    assert count(DeviceToken) == 0
    assert count(SearchQuery, SearchQuery.user_id.is_not(None)) == 0
    # The owner keeps their view count, without knowing who viewed.
    assert count(BusinessView) == 1 and count(BusinessView, BusinessView.viewer_id.is_not(None)) == 0

    after = business_row(business_id)
    assert (after.rating, after.review_count, after.save_count) == (3.0, 1, 0)
    assert bobs["helpful_count"] == 0
    r = client.get(f"{P}/businesses/{business_id}/reviews", headers=bob).json()
    assert r["items"][0]["helpful_count"] == 0


def test_deleting_an_owner_removes_their_businesses(client):
    owner = make_user(client, "owner@khojlo.app", role="business_owner")
    business_id = client.post(f"{P}/businesses", headers=owner, json={"name": "Forno"}).json()["id"]
    ali = make_user(client, "ali@khojlo.app")
    send(client, ali, open_chat(client, ali, business_id)["id"])
    client.post(f"{P}/businesses/{business_id}/reviews", headers=ali, json={"rating": 4})

    assert delete_me(client, owner).status_code == 204
    assert count(BusinessProfile) == 0
    assert count(Review) == 0 and count(Conversation) == 0
    assert me(client, ali)["email"] == "ali@khojlo.app"
