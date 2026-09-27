"""Module 6 — businesses in the visible map area, BR-7 coordinates, and address lookup."""
import pytest

from app.api import geo
from app.api.deps import get_now
from app.main import app
from app.services.geocoding import (
    Geocoder,
    GeocodingError,
    GoogleGeocoder,
    Place,
    parse_result,
)
from tests.conftest import auth, login, register
from tests.factories import F7, FROZEN_NOW, make_world

SEARCH = "/api/v1/search"
# Roughly F-6 / F-7 / Blue Area, Islamabad.
ISLAMABAD_CENTRE = {"north": 33.735, "south": 33.700, "east": 73.085, "west": 73.040}


@pytest.fixture
def world(client):
    ids = make_world()
    app.dependency_overrides[get_now] = lambda: FROZEN_NOW
    return ids


def names(r) -> set[str]:
    assert r.status_code == 200, r.text
    return {b["name"] for b in r.json()["items"]}


# ─────────────── map area (FR-12) ───────────────
def test_map_area_shows_only_businesses_inside_it(client, world):
    inside = names(client.get(SEARCH, params=ISLAMABAD_CENTRE))
    assert inside == {"Brew & Bloom", "The Reading Room", "Forno Italiano", "Coffee Lab"}
    # Abbottabad is outside; Night Owl has no coordinates, so it can't be on a map (BR-7).

    abbottabad = {"north": 34.2, "south": 34.1, "east": 73.3, "west": 73.1}
    assert names(client.get(SEARCH, params=abbottabad)) == {"Zilli Tailors"}


def test_results_carry_coordinates_for_map_pins(client, world):
    r = client.get(SEARCH, params=ISLAMABAD_CENTRE | {"q": "brew"})
    card = r.json()["items"][0]
    assert (card["latitude"], card["longitude"]) == pytest.approx(F7)


def test_map_area_combines_with_keywords_and_filters(client, world):
    params = ISLAMABAD_CENTRE | {"q": "coffee", "category": "cafes", "min_rating": 4.5}
    assert names(client.get(SEARCH, params=params)) == {"Brew & Bloom", "The Reading Room"}


def test_map_can_ask_for_up_to_100_pins(client, world):
    assert client.get(SEARCH, params=ISLAMABAD_CENTRE | {"limit": 100}).status_code == 200
    assert client.get(SEARCH, params=ISLAMABAD_CENTRE | {"limit": 101}).status_code == 422


@pytest.mark.parametrize(
    "params, message",
    [
        ({"north": 33.7, "south": 33.6}, "all four edges"),
        ({"north": 33.6, "south": 33.7, "east": 73.1, "west": 73.0}, "south edge"),
        ({"north": 33.7, "south": 33.6, "east": 73.0, "west": 73.1}, "180°"),
    ],
    ids=["partial", "upside-down", "antimeridian"],
)
def test_bad_map_areas_are_explained(client, world, params, message):
    r = client.get(SEARCH, params=params)
    assert r.status_code == 422
    assert message in r.json()["detail"]


# ─────────────── BR-7: valid coordinates ───────────────
def test_null_island_is_not_a_location(client):
    register(client, "pin-owner@khojlo.app", role="business_owner")
    token = login(client, "pin-owner@khojlo.app")
    r = client.post("/api/v1/businesses", headers=auth(token),
                    json={"name": "Nowhere", "latitude": 0, "longitude": 0})
    assert r.status_code == 422

    biz = client.post("/api/v1/businesses", headers=auth(token),
                      json={"name": "Somewhere", "latitude": 33.72, "longitude": 73.05}).json()
    r = client.patch(f"/api/v1/businesses/{biz['id']}", headers=auth(token),
                     json={"latitude": 0, "longitude": 0})
    assert r.status_code == 422
    assert "isn't valid" in r.json()["detail"]


# ─────────────── address lookup ───────────────
F7_RESULT = {
    "formatted_address": "8J7R+XC, Jinnah Super Market, F-7 Markaz, Islamabad, Pakistan",
    "address_components": [
        {"long_name": "Jinnah Super Market", "types": ["route"]},
        {"long_name": "F-7 Markaz", "types": ["sublocality_level_1", "sublocality"]},
        {"long_name": "Islamabad", "types": ["locality", "political"]},
        {"long_name": "Pakistan", "types": ["country", "political"]},
    ],
    "geometry": {"location": {"lat": 33.7206, "lng": 73.0551}},
}


class FakeGeocoder(Geocoder):
    def __init__(self, fail=False):
        self.fail = fail

    def reverse(self, latitude, longitude):
        if self.fail:
            raise GeocodingError("REQUEST_DENIED: key not authorized")
        if latitude > 80:  # the Arctic: nothing to name
            return None
        return parse_result(F7_RESULT)

    def search(self, query):
        return [parse_result(F7_RESULT)] if "f-7" in query.lower() else []


@pytest.fixture(autouse=True)
def _fresh_rate_limit(monkeypatch):
    monkeypatch.setattr(geo, "limiter", geo._RateLimiter(geo.RATE_LIMIT, geo.RATE_WINDOW_SECONDS))


@pytest.fixture
def user(client):
    register(client, "geo@khojlo.app")
    return auth(login(client, "geo@khojlo.app"))


def use(geocoder):
    app.dependency_overrides[geo.get_geocoder] = lambda: geocoder


def test_google_results_are_tidied_for_local_addresses():
    place = parse_result(F7_RESULT)
    assert place.address == "Jinnah Super Market, F-7 Markaz, Islamabad"  # no plus code/country
    assert (place.area, place.city) == ("F-7 Markaz", "Islamabad")
    assert place.label == "F-7 Markaz, Islamabad"
    assert (place.latitude, place.longitude) == (33.7206, 73.0551)


def test_reverse_lookup(client, user):
    use(FakeGeocoder())
    r = client.get("/api/v1/geo/reverse", params={"lat": 33.72, "lng": 73.05}, headers=user)
    assert r.status_code == 200, r.text
    assert r.json()["label"] == "F-7 Markaz, Islamabad"

    r = client.get("/api/v1/geo/reverse", params={"lat": 85, "lng": 0}, headers=user)
    assert r.status_code == 404


def test_place_search(client, user):
    use(FakeGeocoder())
    r = client.get("/api/v1/geo/search", params={"q": "F-7 Markaz"}, headers=user)
    assert [p["area"] for p in r.json()] == ["F-7 Markaz"]
    assert client.get("/api/v1/geo/search", params={"q": "zzz"}, headers=user).json() == []


def test_lookup_needs_an_account_and_a_configured_key(client, user):
    use(FakeGeocoder())
    assert client.get("/api/v1/geo/reverse", params={"lat": 33.7, "lng": 73.0}).status_code == 401

    use(None)
    r = client.get("/api/v1/geo/reverse", params={"lat": 33.7, "lng": 73.0}, headers=user)
    assert r.status_code == 503


def test_provider_failures_are_reported_without_details(client, user):
    use(FakeGeocoder(fail=True))
    r = client.get("/api/v1/geo/reverse", params={"lat": 33.7, "lng": 73.0}, headers=user)
    assert r.status_code == 502
    assert "REQUEST_DENIED" not in r.json()["detail"]


def test_lookups_are_rate_limited(client, user, monkeypatch):
    use(FakeGeocoder())
    monkeypatch.setattr(geo, "limiter", geo._RateLimiter(limit=2, window=60))
    codes = [client.get("/api/v1/geo/search", params={"q": "f-7"}, headers=user).status_code
             for _ in range(3)]
    assert codes == [200, 200, 429]


class FakeSession:
    def __init__(self, payload):
        self.payload = payload
        self.calls: list[dict] = []

    def get(self, url, params, timeout):
        self.calls.append(params)
        payload = self.payload

        class Response:
            def json(self):
                return payload

        return Response()


def test_google_geocoder_sends_the_key_and_caches():
    session = FakeSession({"status": "OK", "results": [F7_RESULT]})
    g = GoogleGeocoder("server-key", region="pk", session=session)
    first = g.reverse(33.72061, 73.05512)
    second = g.reverse(33.72064, 73.05509)  # same ~11 m cell
    assert first == second and isinstance(first, Place)
    assert len(session.calls) == 1
    assert (session.calls[0]["key"], session.calls[0]["region"]) == ("server-key", "pk")


def test_google_geocoder_errors_and_empty_results():
    assert GoogleGeocoder("k", session=FakeSession({"status": "ZERO_RESULTS"})).reverse(1, 1) is None
    denied = GoogleGeocoder("k", session=FakeSession(
        {"status": "REQUEST_DENIED", "error_message": "API not enabled"}))
    with pytest.raises(GeocodingError, match="REQUEST_DENIED"):
        denied.search("anything")
