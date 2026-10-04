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


def test_cannot_register_as_admin(client):
    # SEC-3: public sign-up must not hand out the admin role.
    r = register(client, "sneaky@khojlo.app", role="admin")
    assert r.status_code == 422, r.text
    assert register(client, "sneaky@khojlo.app", role="business_owner").status_code == 201


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
        json={"title": "20% off", "deal_type": "percent_off", "deal_value": 20,
              "start_date": "2026-09-01"},  # a draft: the business isn't verified yet
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


def test_surprise_deals_every_listed_business_shuffled(client):
    register(client, "deck@khojlo.app", role="business_owner")
    token = login(client, "deck@khojlo.app")
    ids = [client.post(f"{PREFIX}/businesses", headers=auth(token),
                       json={"name": f"Place {i}"}).json()["id"] for i in range(15)]
    hidden = ids.pop()
    client.patch(f"{PREFIX}/businesses/{hidden}", headers=auth(token), json={"is_published": False})

    decks = [[b["id"] for b in client.get(f"{PREFIX}/feed/surprise").json()] for _ in range(4)]
    assert all(sorted(d) == sorted(ids) for d in decks)  # all of them, more than the old 12
    assert len({tuple(d) for d in decks}) > 1  # and shuffled


def test_feed_seed_rotates_discovery_rows_only(client):
    register(client, "rotate@khojlo.app", role="business_owner")
    token = login(client, "rotate@khojlo.app")
    for i in range(15):
        client.post(f"{PREFIX}/businesses", headers=auth(token), json={"name": f"Spot {i}"})

    def feed(seed):
        sections = client.get(f"{PREFIX}/feed", params={"seed": seed}).json()["sections"]
        return {s["key"]: [b["id"] for b in s["businesses"]] for s in sections}

    # The same seed gives the same feed, so coming back to Home doesn't reshuffle it.
    assert feed(7) == feed(7)
    feeds = [feed(seed) for seed in range(12)]
    # A new seed (a pull-to-refresh) rotates the featured pick and the explore row...
    assert len({tuple(f["featured"]) for f in feeds}) > 1
    assert len({tuple(f["because_you_like"]) for f in feeds}) > 1
    # ...but Trending stays a ranking.
    assert len({tuple(f["trending"]) for f in feeds}) == 1



def test_feed_greets_by_name_and_counts_this_weeks_businesses(client):
    register(client, "sana@khojlo.app", role="business_owner", full_name="Sana Malik")
    token = login(client, "sana@khojlo.app")
    for i in range(3):
        client.post(f"{PREFIX}/businesses", headers=auth(token), json={"name": f"Spot {i}"})
    signed_in = client.get(f"{PREFIX}/feed", headers=auth(token)).json()
    assert signed_in["greeting"].endswith(", Sana")
    assert signed_in["headline"] == "3 hidden gems\nopened this week"
    assert client.get(f"{PREFIX}/feed").json()["greeting"].endswith(", explorer")


def test_analytics_counts_real_views_per_day(client):
    register(client, "views@khojlo.app", role="business_owner")
    owner = auth(login(client, "views@khojlo.app"))
    bid = client.post(f"{PREFIX}/businesses", headers=owner, json={"name": "Counted"}).json()["id"]
    for _ in range(3):
        client.get(f"{PREFIX}/businesses/{bid}")  # three visitors
    client.get(f"{PREFIX}/businesses/{bid}", params={"track": False})  # owner's editor: not a view
    a = client.get(f"{PREFIX}/businesses/{bid}/analytics", headers=owner).json()
    assert [p["value"] for p in a["weekly_views"]][-1] == 3  # today is the last bar
    assert sum(p["value"] for p in a["weekly_views"][:-1]) == 0  # nothing invented
    assert (a["views_this_week"], a["views_last_week"], a["profile_views"]) == (3, 0, 3)
