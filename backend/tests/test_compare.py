"""Module 4 — business comparison (SRS UC-5; SDD FR08, Algorithm 3)."""
import pytest

from app.api.deps import get_now
from app.main import app
from tests.factories import F7, FROZEN_NOW, make_world

URL = "/api/v1/compare"


@pytest.fixture
def world(client):
    ids = make_world()
    app.dependency_overrides[get_now] = lambda: FROZEN_NOW
    return ids


def compare(client, ids, **extra):
    params = [("ids", i) for i in ids] + list(extra.items())
    return client.get(URL, params=params)


def test_compares_two_in_the_order_given(client, world):
    r = compare(client, [world["The Reading Room"], world["Brew & Bloom"]])
    assert r.status_code == 200, r.text
    body = r.json()
    assert [i["name"] for i in body["items"]] == ["The Reading Room", "Brew & Bloom"]

    brew, reading = world["Brew & Bloom"], world["The Reading Room"]
    h = body["highlights"]
    assert h["price"] == [reading]  # Rs 350 start beats Rs 450
    assert h["rating"] == [brew]  # 4.8 vs 4.7
    assert h["open_now"] == [brew]  # Reading Room opens at 13:00
    assert h["services"] == [brew]  # 2 vs 1
    assert h["offers"] == [brew]
    assert h["saves"] == [brew]
    assert h["distance"] == []  # no location sent


def test_items_include_services_offers_and_hours(client, world):
    body = compare(client, [world["Brew & Bloom"], world["Forno Italiano"]]).json()
    brew, forno = body["items"]
    assert [s["name"] for s in brew["services"]] == ["Pour over", "Flat white"]
    assert brew["services"][0]["price_amount"] == 650
    assert brew["active_offers"] == ["Free seedling"]
    assert forno["active_offers"] == []  # its only offer has ended
    assert brew["today_hours"] == "08:00–23:00"
    assert forno["is_open_now"] is False


def test_three_way_with_location(client, world):
    ids = [world["Brew & Bloom"], world["Coffee Lab"], world["Forno Italiano"]]
    body = compare(client, ids, lat=F7[0], lng=F7[1]).json()
    assert [i["distance_km"] is not None for i in body["items"]] == [True, True, True]
    assert body["highlights"]["distance"] == [world["Brew & Bloom"]]
    # Coffee Lab has no rupee range, so price falls back to tiers: $ < $$ < $$$
    assert body["highlights"]["price"] == [world["Coffee Lab"]]


def test_rows_where_everyone_ties_are_not_highlighted(client, world):
    body = compare(client, [world["Brew & Bloom"], world["Zilli Tailors"]]).json()
    assert body["highlights"]["open_now"] == []  # both open


@pytest.mark.parametrize(
    "picked, status, message",
    [
        (["Brew & Bloom"], 422, "Pick 2 to 3"),
        (["Brew & Bloom", "Coffee Lab", "Zilli Tailors", "The Reading Room"], 422, "Pick 2 to 3"),
        (["Brew & Bloom", "Brew & Bloom"], 422, "only be compared once"),
        (["Brew & Bloom", "Hidden Draft"], 404, "Business not found"),  # unpublished
    ],
)
def test_invalid_selections(client, world, picked, status, message):
    r = compare(client, [world[name] for name in picked])
    assert r.status_code == status
    assert message in r.json()["detail"]


def test_unknown_business_and_half_a_location(client, world):
    missing = compare(client, [world["Brew & Bloom"], 99999])
    assert missing.status_code == 404 and "99999" in missing.json()["detail"]
    half = compare(client, [world["Brew & Bloom"], world["Coffee Lab"]], lat=33.7)
    assert half.status_code == 422
