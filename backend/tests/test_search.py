"""Module 4 — search & filtering (SRS UC-4, UC-5, FR-3, FR-4, PER-2; SDD FR06/FR07)."""
import time

import pytest

from app.api.deps import get_now
from app.main import app
from tests.factories import F7, FROZEN_NOW, WEDNESDAY_1AM, make_many, make_world

URL = "/api/v1/search"


@pytest.fixture
def world(client):
    ids = make_world()
    app.dependency_overrides[get_now] = lambda: FROZEN_NOW
    return ids


def search(client, params=None):
    r = client.get(URL, params=params or {})
    assert r.status_code == 200, r.text
    return r.json()


def names(result) -> list[str]:
    return [b["name"] for b in result["items"]]


# ─────────────── keywords (FR-3) ───────────────
def test_keyword_matches_names_taglines_descriptions_and_services(client, world):
    result = search(client, {"q": "coffee"})
    assert set(names(result)) == {"Coffee Lab", "The Reading Room", "Brew & Bloom"}
    assert "Hidden Draft" not in names(result)  # unpublished never shows


def test_relevance_ranks_name_matches_first(client, world):
    # name (Coffee Lab) > service + description (Reading Room) > tagline (Brew & Bloom)
    assert names(search(client, {"q": "coffee"})) == [
        "Coffee Lab", "The Reading Room", "Brew & Bloom",
    ]
    # tagline + service (Forno) outranks a passing mention in a description (Night Owl)
    assert names(search(client, {"q": "pizza"})) == ["Forno Italiano", "Night Owl Ramen"]


def test_keywords_ignore_case_and_accents(client, world):
    # "CAFE" matches the "Cafés" category
    result = search(client, {"q": "CAFE"})
    assert set(names(result)) == {"Brew & Bloom", "The Reading Room", "Coffee Lab"}


def test_stopwords_are_ignored(client, world):
    assert names(search(client, {"q": "coffee near me"})) == names(search(client, {"q": "coffee"}))


def test_all_words_must_match(client, world):
    result = search(client, {"q": "unstitched fabric"})
    assert names(result) == ["Zilli Tailors"]
    assert result["relaxed"] is False


def test_falls_back_to_any_word_when_nothing_matches_all(client, world):
    result = search(client, {"q": "pizza fabric"})
    assert result["relaxed"] is True
    assert set(names(result)) == {"Forno Italiano", "Night Owl Ramen", "Zilli Tailors"}


def test_no_match_is_an_empty_result_not_an_error(client, world):
    result = search(client, {"q": "secret"})  # only the unpublished business has it
    assert result["items"] == [] and result["total"] == 0
    assert result["summary"].startswith("No places match")


# ─────────────── filters (FR-4, UC-5) ───────────────
def test_category_filter_accepts_several_categories(client, world):
    assert set(names(search(client, {"category": "cafes"}))) == {
        "Brew & Bloom", "The Reading Room", "Coffee Lab",
    }
    both = search(client, [("category", "cafes"), ("category", "shopping")])
    assert both["total"] == 4


def test_price_tier_filter(client, world):
    assert set(names(search(client, {"price": "$"}))) == {"Zilli Tailors", "Coffee Lab"}


def test_budget_filter_uses_overlapping_pkr_ranges(client, world):
    # starting price within Rs 1,000; places without a range are left out
    assert set(names(search(client, {"max_price": 1000}))) == {
        "Brew & Bloom", "The Reading Room", "Zilli Tailors",
    }
    # something costing Rs 2,000 or more
    assert set(names(search(client, {"min_price": 2000}))) == {"Forno Italiano", "Zilli Tailors"}


def test_rating_filter(client, world):
    assert set(names(search(client, {"min_rating": 4.7}))) == {"Brew & Bloom", "The Reading Room"}


def test_open_now_uses_local_hours_and_skips_unknown(client, world):
    # Wednesday 12:00 in Karachi. Night Owl has no hours, so it isn't "open".
    assert set(names(search(client, {"open_now": "true"}))) == {
        "Brew & Bloom", "Zilli Tailors", "Coffee Lab",
    }


def test_open_now_handles_hours_past_midnight(client, world):
    app.dependency_overrides[get_now] = lambda: WEDNESDAY_1AM
    # only Forno's Tuesday 18:00–02:00 window covers Wednesday 01:00
    assert names(search(client, {"open_now": "true"})) == ["Forno Italiano"]


def test_offer_filter_counts_only_active_offers(client, world):
    assert names(search(client, {"has_offer": "true"})) == ["Brew & Bloom"]


def test_verified_only_filter(client, world):
    result = search(client, {"verified_only": "true"})
    assert result["total"] == 5
    assert "Forno Italiano" not in names(result)


def test_filters_combine(client, world):
    result = search(client, {"q": "coffee", "price": "$$", "open_now": "true"})
    assert names(result) == ["Brew & Bloom"]


# ─────────────── location ───────────────
def test_radius_filter_and_distance_sort(client, world):
    result = search(client, {"lat": F7[0], "lng": F7[1], "radius_km": 3, "sort": "distance"})
    assert names(result) == ["Brew & Bloom", "Coffee Lab", "The Reading Room", "Forno Italiano"]
    distances = [b["distance_km"] for b in result["items"]]
    assert distances == sorted(distances) and distances[0] == 0.0

    close = search(client, {"lat": F7[0], "lng": F7[1], "radius_km": 1})
    assert set(names(close)) == {"Brew & Bloom", "Coffee Lab"}


def test_distance_sort_puts_unplaceable_businesses_last(client, world):
    result = search(client, {"lat": F7[0], "lng": F7[1], "sort": "distance"})
    assert names(result)[-2:] == ["Zilli Tailors", "Night Owl Ramen"]
    assert result["items"][-1]["distance_km"] is None


@pytest.mark.parametrize(
    "params, message",
    [
        ({"lat": 33.7}, "both lat and lng"),
        ({"radius_km": 2}, "needs your location"),
        ({"sort": "distance"}, "needs your location"),
        ({"min_price": 900, "max_price": 100}, "minimum price"),
        ({"price": "$$$$"}, "Unknown price tier"),
    ],
)
def test_invalid_combinations_explain_themselves(client, world, params, message):
    r = client.get(URL, params=params)
    assert r.status_code == 422
    assert message in r.json()["detail"]


def test_out_of_range_values_are_rejected(client, world):
    assert client.get(URL, params={"limit": 0}).status_code == 422
    assert client.get(URL, params={"radius_km": 500, "lat": 1, "lng": 1}).status_code == 422
    assert client.get(URL, params={"min_rating": 6}).status_code == 422


# ─────────────── ordering, paging, payload ───────────────
def test_default_order_puts_new_businesses_first(client, world):
    # no keywords → ties everywhere → new first (Brew 10 days, Zilli 5), then by rating
    assert names(search(client)) == [
        "Brew & Bloom", "Zilli Tailors", "The Reading Room", "Forno Italiano",
        "Coffee Lab", "Night Owl Ramen",
    ]


@pytest.mark.parametrize(
    "sort, expected_first_two",
    [
        ("rating", ["Brew & Bloom", "The Reading Room"]),
        # tier first; within "$", Zilli's Rs 800 start beats Coffee Lab's missing range
        ("price_low", ["Zilli Tailors", "Coffee Lab"]),
        ("price_high", ["Forno Italiano", "Brew & Bloom"]),
        ("newest", ["Zilli Tailors", "Brew & Bloom"]),
        ("popular", ["Brew & Bloom", "Forno Italiano"]),
    ],
)
def test_sort_options(client, world, sort, expected_first_two):
    result = search(client, {"sort": sort})
    assert names(result)[:2] == expected_first_two
    assert result["sort"] == sort


def test_pagination(client, world):
    first = search(client, {"limit": 4})
    rest = search(client, {"limit": 4, "offset": 4})
    assert first["total"] == rest["total"] == 6
    assert len(first["items"]) == 4 and len(rest["items"]) == 2
    assert not set(names(first)) & set(names(rest))


def test_cards_carry_module4_fields(client, world):
    card = search(client, {"q": "bloom"})["items"][0]
    assert card["name"] == "Brew & Bloom"
    assert card["category_slug"] == "cafes"
    assert (card["price_min"], card["price_max"]) == (450, 1500)
    assert card["is_open_now"] is True
    assert card["today_hours"] == "08:00–23:00"
    assert card["has_offer"] is True
    assert card["is_new"] is True

    owl = search(client, {"q": "owl"})["items"][0]
    assert owl["is_open_now"] is None and owl["today_hours"] is None


def test_summary_describes_the_whole_result_set(client, world):
    summary = search(client, {"q": "coffee"})["summary"]
    assert summary.startswith("3 places")
    assert "open now" in summary and "avg ★" in summary


def test_search_stays_fast_with_hundreds_of_businesses(client):
    """PER-2: results within 3 s. Generous bound; typically a fraction of that."""
    make_many(500)
    app.dependency_overrides[get_now] = lambda: FROZEN_NOW
    started = time.perf_counter()
    result = search(client, {"q": "coffee cake", "open_now": "true", "lat": 33.72,
                             "lng": 73.07, "radius_km": 10, "sort": "distance"})
    elapsed = time.perf_counter() - started
    assert result["total"] > 0
    assert elapsed < 3.0, f"search took {elapsed:.2f}s"
