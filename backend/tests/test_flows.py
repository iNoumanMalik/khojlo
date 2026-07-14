from tests.conftest import auth, login, register

PREFIX = "/api/v1"


def test_register_login_me(client):
    r = register(client, "a@khojlo.app")
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "customer"

    # duplicate email rejected
    assert register(client, "a@khojlo.app").status_code == 409

    token = login(client, "a@khojlo.app")
    me = client.get(f"{PREFIX}/users/me", headers=auth(token))
    assert me.status_code == 200
    assert me.json()["email"] == "a@khojlo.app"
    assert me.json()["initials"] == "TU"


def test_short_password_rejected(client):
    r = client.post(
        f"{PREFIX}/auth/register",
        json={"full_name": "X", "email": "x@k.app", "password": "short", "role": "customer"},
    )
    assert r.status_code == 422


def test_interests_update(client):
    register(client, "i@khojlo.app")
    token = login(client, "i@khojlo.app")
    r = client.put(
        f"{PREFIX}/users/me/interests",
        headers=auth(token),
        json={"interests": ["cafes", "gym"]},
    )
    assert r.status_code == 200
    assert r.json()["interests"] == ["cafes", "gym"]


def test_customer_cannot_create_business(client):
    register(client, "c@khojlo.app", role="customer")
    token = login(client, "c@khojlo.app")
    r = client.post(f"{PREFIX}/businesses", headers=auth(token), json={"name": "Nope"})
    assert r.status_code == 403


def test_business_lifecycle_and_feed(client):
    register(client, "owner@khojlo.app", role="business_owner")
    otoken = login(client, "owner@khojlo.app")

    create = client.post(
        f"{PREFIX}/businesses",
        headers=auth(otoken),
        json={
            "name": "Brew & Bloom",
            "tagline": "Specialty coffee",
            "tone": "emerald",
            "latitude": 33.68,
            "longitude": 73.04,
            "services": [{"name": "Pour over", "price": "$$"}],
            "hours": [{"day_of_week": 0, "opens": "08:00", "closes": "20:00"}],
        },
    )
    assert create.status_code == 201, create.text
    biz_id = create.json()["id"]
    assert len(create.json()["services"]) == 1

    # appears in the feed
    feed = client.get(f"{PREFIX}/feed")
    assert feed.status_code == 200
    names = [b["name"] for s in feed.json()["sections"] for b in s["businesses"]]
    assert "Brew & Bloom" in names

    # add an offer
    offer = client.post(
        f"{PREFIX}/businesses/{biz_id}/offers",
        headers=auth(otoken),
        json={"title": "20% off", "status": "Active"},
    )
    assert offer.status_code == 201

    # analytics available to owner
    analytics = client.get(f"{PREFIX}/businesses/{biz_id}/analytics", headers=auth(otoken))
    assert analytics.status_code == 200
    assert len(analytics.json()["weekly_views"]) == 7

    # customer saves it
    register(client, "cust@khojlo.app", role="customer")
    ctoken = login(client, "cust@khojlo.app")
    saved = client.post(
        f"{PREFIX}/businesses/{biz_id}/save", headers=auth(ctoken), json={"list_id": None}
    )
    assert saved.status_code == 200
    assert saved.json()["is_saved"] is True

    lists = client.get(f"{PREFIX}/users/me/saved", headers=auth(ctoken))
    assert lists.status_code == 200
    assert any(b["id"] == biz_id for sl in lists.json() for b in sl["businesses"])

    # unsave
    un = client.delete(f"{PREFIX}/businesses/{biz_id}/save", headers=auth(ctoken))
    assert un.json()["is_saved"] is False


def test_detail_records_view(client):
    register(client, "o2@khojlo.app", role="business_owner")
    t = login(client, "o2@khojlo.app")
    biz = client.post(
        f"{PREFIX}/businesses", headers=auth(t), json={"name": "Viewed Co"}
    ).json()
    before = biz["view_count"]
    detail = client.get(f"{PREFIX}/businesses/{biz['id']}")
    assert detail.status_code == 200
    assert detail.json()["view_count"] == before + 1


def test_refresh_token(client):
    register(client, "r@khojlo.app")
    tokens = client.post(
        f"{PREFIX}/auth/login", json={"email": "r@khojlo.app", "password": "password123"}
    ).json()
    r = client.post(f"{PREFIX}/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200
    assert "access_token" in r.json()
