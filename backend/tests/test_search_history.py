"""Module 4 — recent searches, popular searches and typeahead suggestions."""
import pytest

from app.api.deps import get_now
from app.main import app
from tests.conftest import auth, login, register
from tests.factories import FROZEN_NOW, make_world

P = "/api/v1/search"


@pytest.fixture
def world(client):
    ids = make_world()
    app.dependency_overrides[get_now] = lambda: FROZEN_NOW
    return ids


@pytest.fixture
def token(client):
    register(client, "searcher@khojlo.app")
    return login(client, "searcher@khojlo.app")


def history(client, token) -> list[str]:
    r = client.get(f"{P}/history", headers=auth(token))
    assert r.status_code == 200, r.text
    return [item["query"] for item in r.json()]


def test_history_is_recorded_only_for_submitted_searches(client, world, token):
    client.get(P, params={"q": "coffee"}, headers=auth(token))  # live typing
    assert history(client, token) == []

    client.get(P, params={"q": "coffee", "record": "true"}, headers=auth(token))
    client.get(P, params={"category": "cafes", "record": "true"}, headers=auth(token))
    assert history(client, token) == ["coffee"]  # filter-only browsing isn't a "search"


def test_recent_searches_are_distinct_and_newest_first(client, world, token):
    for q in ("coffee", "pizza", "Coffee"):
        client.get(P, params={"q": q, "record": "true"}, headers=auth(token))
    assert history(client, token) == ["Coffee", "pizza"]


def test_history_is_private_and_can_be_cleared(client, world, token):
    client.get(P, params={"q": "coffee", "record": "true"}, headers=auth(token))

    register(client, "other@khojlo.app")
    other = login(client, "other@khojlo.app")
    assert history(client, other) == []

    assert client.delete(f"{P}/history", headers=auth(token)).status_code == 204
    assert history(client, token) == []


def test_history_requires_login(client, world):
    assert client.get(f"{P}/history").status_code == 401
    assert client.delete(f"{P}/history").status_code == 401


def test_popular_ranks_frequent_searches_that_found_something(client, world, token):
    for q in ("coffee", "coffee", "pizza", "zzzz"):
        client.get(P, params={"q": q, "record": "true"}, headers=auth(token))
    client.get(P, params={"q": "tailor", "record": "true"})  # anonymous searches count too

    popular = client.get(f"{P}/popular").json()
    assert popular[0] == "coffee"
    assert {"pizza", "tailor"} <= set(popular)
    assert "zzzz" not in popular  # no results → not worth suggesting


def test_popular_falls_back_to_categories(client, world):
    assert client.get(f"{P}/popular").json() == ["cafés", "restaurants", "shopping"]


def test_suggestions_offer_categories_businesses_and_services(client, world):
    def suggest(q):
        r = client.get(f"{P}/suggestions", params={"q": q})
        assert r.status_code == 200, r.text
        return [(s["type"], s["label"]) for s in r.json()]

    assert suggest("bre")[0] == ("business", "Brew & Bloom")
    assert suggest("caf")[0] == ("category", "Cafés")
    assert ("service", "Suit stitching") in suggest("suit")
    # word-prefix matching only: "ra" suggests "Ramen", not "Margherita"
    assert suggest("ra") == [("business", "Night Owl Ramen")]
    assert suggest("zz") == []
    assert "Hidden Draft" not in [label for _, label in suggest("hid")]


def test_suggestions_require_text(client, world):
    assert client.get(f"{P}/suggestions", params={"q": ""}).status_code == 422
