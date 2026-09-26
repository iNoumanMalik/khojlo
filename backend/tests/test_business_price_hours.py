"""Module 4 additions to business registration: PKR price range, coordinates, hours."""
import pytest

from tests.conftest import auth, login, register

P = "/api/v1"

FULL = {
    "name": "Brew & Bloom",
    "price_level": "$$",
    "price_min": 450,
    "price_max": 1500,
    "latitude": 33.7215,
    "longitude": 73.0527,
    "services": [{"name": "Pour over", "price": "Rs 650", "price_amount": 650}],
    "hours": [
        {"day_of_week": 0, "opens": "08:00", "closes": "23:00"},
        {"day_of_week": 6, "is_closed": True},
    ],
}


@pytest.fixture
def owner(client):
    register(client, "price-owner@khojlo.app", role="business_owner")
    return login(client, "price-owner@khojlo.app")


def create(client, token, payload):
    return client.post(f"{P}/businesses", headers=auth(token), json=payload)


def test_create_with_price_range_location_and_hours(client, owner):
    r = create(client, owner, FULL)
    assert r.status_code == 201, r.text
    body = r.json()
    assert (body["price_min"], body["price_max"]) == (450, 1500)
    assert (body["latitude"], body["longitude"]) == (33.7215, 73.0527)
    assert body["services"][0]["price_amount"] == 650
    assert {h["day_of_week"] for h in body["hours"]} == {0, 6}


@pytest.mark.parametrize(
    "change, message",
    [
        ({"price_min": 2000, "price_max": 100}, "Minimum price"),
        ({"latitude": 33.7, "longitude": None}, "both latitude and longitude"),
        ({"price_level": "$$$$"}, "Input should be"),
        ({"hours": [{"day_of_week": 0, "opens": "9am", "closes": "17:00"}]}, "HH:MM"),
        ({"hours": [{"day_of_week": 1}, {"day_of_week": 1}]}, "only appear once"),
        ({"price_min": -5}, "greater than or equal"),
    ],
)
def test_create_rejects_inconsistent_data(client, owner, change, message):
    r = create(client, owner, {**FULL, **change})
    assert r.status_code == 422
    assert message in r.text


def test_patch_checks_the_merged_price_range(client, owner):
    biz = create(client, owner, FULL).json()
    bad = client.patch(f"{P}/businesses/{biz['id']}", headers=auth(owner), json={"price_min": 5000})
    assert bad.status_code == 422
    assert "Minimum price" in bad.json()["detail"]

    good = client.patch(
        f"{P}/businesses/{biz['id']}", headers=auth(owner),
        json={"price_min": 500, "price_max": None},
    )
    assert good.status_code == 200
    assert (good.json()["price_min"], good.json()["price_max"]) == (500, None)


def test_replace_hours(client, owner):
    biz = create(client, owner, FULL).json()
    url = f"{P}/businesses/{biz['id']}/hours"

    week = [{"day_of_week": d, "opens": "10:00", "closes": "22:00"} for d in range(7)]
    r = client.put(url, headers=auth(owner), json={"hours": week})
    assert r.status_code == 200, r.text
    assert len(r.json()["hours"]) == 7

    cleared = client.put(url, headers=auth(owner), json={"hours": []})
    assert cleared.json()["hours"] == []
    assert cleared.json()["is_open_now"] is None  # unknown, not "closed"


def test_only_the_owner_can_replace_hours(client, owner):
    biz = create(client, owner, FULL).json()
    url = f"{P}/businesses/{biz['id']}/hours"

    register(client, "rival@khojlo.app", role="business_owner")
    rival = login(client, "rival@khojlo.app")
    assert client.put(url, headers=auth(rival), json={"hours": []}).status_code == 403

    register(client, "shopper@khojlo.app")
    shopper = login(client, "shopper@khojlo.app")
    assert client.put(url, headers=auth(shopper), json={"hours": []}).status_code == 403


def test_detail_can_skip_view_tracking(client, owner):
    biz = create(client, owner, FULL).json()
    url = f"{P}/businesses/{biz['id']}"
    assert client.get(url, params={"track": "false"}).json()["view_count"] == 0
    assert client.get(url).json()["view_count"] == 1
