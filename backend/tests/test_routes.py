"""Module 6 — in-app route preview (UC-9 "get directions") through openrouteservice."""
import pytest

from app.api import geo
from app.main import app
from app.services.routing import (
    OrsRouter,
    Route,
    Router,
    RoutingError,
    TravelMode,
    configured_router,
    parse_ors_route,
)
from tests.conftest import auth, login, register

HOME = (33.6938, 73.0652)
F7 = (33.7206, 73.0551)
ROUTE_PARAMS = {"from_lat": HOME[0], "from_lng": HOME[1], "to_lat": F7[0], "to_lng": F7[1]}

ORS_ROUTE = {
    "type": "FeatureCollection",
    "features": [{
        "properties": {"summary": {"distance": 4321.5, "duration": 612.3}},
        "geometry": {"type": "LineString",
                     "coordinates": [[73.0652, 33.6938], [73.06, 33.71], [73.0551, 33.7206]]},
    }],
}


class FakeRouter(Router):
    def __init__(self, fail=False):
        self.fail = fail
        self.calls = []

    def route(self, origin, destination, mode):
        self.calls.append((origin, destination, mode))
        if self.fail:
            raise RoutingError("HTTP 403: Access to this API has been disallowed")
        if destination[0] > 80:  # the Arctic: no roads
            return None
        return Route(distance_m=4321.5, duration_s=612.3 if mode == TravelMode.car else 3500,
                     points=[origin, (33.71, 73.06), destination])


@pytest.fixture(autouse=True)
def _fresh_rate_limit(monkeypatch):
    monkeypatch.setattr(geo, "route_limiter", geo._RateLimiter(30, geo.RATE_WINDOW_SECONDS))


@pytest.fixture
def user(client):
    register(client, "route@khojlo.app")
    return auth(login(client, "route@khojlo.app"))


def use(router):
    app.dependency_overrides[geo.get_router] = lambda: router


def test_route_preview(client, user):
    fake = FakeRouter()
    use(fake)
    r = client.get("/api/v1/geo/route", params=ROUTE_PARAMS, headers=user)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["mode"] == "car"
    assert (body["distance_m"], body["duration_s"]) == (4321.5, 612.3)
    assert body["points"][0] == list(HOME) and body["points"][-1] == list(F7)

    walk = client.get("/api/v1/geo/route", params=ROUTE_PARAMS | {"mode": "walk"}, headers=user)
    assert walk.json()["duration_s"] == 3500
    assert fake.calls[-1][2] == TravelMode.walk


def test_route_errors(client, user):
    use(FakeRouter())
    no_road = client.get("/api/v1/geo/route", params=ROUTE_PARAMS | {"to_lat": 85}, headers=user)
    assert no_road.status_code == 404
    bad_mode = client.get("/api/v1/geo/route", params=ROUTE_PARAMS | {"mode": "fly"}, headers=user)
    assert bad_mode.status_code == 422

    use(FakeRouter(fail=True))
    failed = client.get("/api/v1/geo/route", params=ROUTE_PARAMS, headers=user)
    assert failed.status_code == 502
    assert "disallowed" not in failed.text  # provider details stay in the log


def test_route_needs_an_account_and_a_key(client, user):
    use(FakeRouter())
    assert client.get("/api/v1/geo/route", params=ROUTE_PARAMS).status_code == 401
    use(None)
    assert client.get("/api/v1/geo/route", params=ROUTE_PARAMS, headers=user).status_code == 503


def test_routes_are_rate_limited(client, user, monkeypatch):
    use(FakeRouter())
    monkeypatch.setattr(geo, "route_limiter", geo._RateLimiter(2, 600))
    codes = [client.get("/api/v1/geo/route", params=ROUTE_PARAMS, headers=user).status_code
             for _ in range(3)]
    assert codes == [200, 200, 429]


# ── openrouteservice client ──

class FakeSession:
    def __init__(self, payload, status_code=200):
        self.payload, self.status_code = payload, status_code
        self.calls = []

    def post(self, url, json, headers, timeout):
        self.calls.append({"url": url, "json": json, "headers": headers})
        payload, status_code = self.payload, self.status_code

        class Response:
            def json(self):
                return payload

        Response.status_code = status_code
        return Response()


def test_ors_routes_are_parsed_as_lat_lng():
    route = parse_ors_route(ORS_ROUTE)
    assert route.points == [(33.6938, 73.0652), (33.71, 73.06), (33.7206, 73.0551)]
    assert (route.distance_m, route.duration_s) == (4321.5, 612.3)
    assert parse_ors_route({"features": []}) is None


def test_ors_router_sends_the_key_and_caches():
    session = FakeSession(ORS_ROUTE)
    router = OrsRouter("ors-key", base_url="https://ors.example/", session=session)
    first = router.route(HOME, F7, TravelMode.walk)
    again = router.route((33.69381, 73.06519), F7, TravelMode.walk)  # same ~110 m start
    assert first == again and len(session.calls) == 1
    call = session.calls[0]
    assert call["url"] == "https://ors.example/v2/directions/foot-walking/geojson"
    assert call["headers"] == {"Authorization": "ors-key"}
    assert call["json"] == {"coordinates": [[73.0652, 33.6938], [73.0551, 33.7206]]}

    router.route(HOME, F7, TravelMode.car)
    assert session.calls[1]["url"].endswith("/driving-car/geojson")


def test_ors_no_route_and_failures():
    no_route = FakeSession({"error": {"code": 2010, "message": "Could not find routable point"}},
                           status_code=404)
    assert OrsRouter("k", session=no_route).route(HOME, F7, TravelMode.car) is None

    quota = FakeSession({"error": "Rate limit exceeded"}, status_code=429)
    with pytest.raises(RoutingError, match="HTTP 429"):
        OrsRouter("k", session=quota).route(HOME, F7, TravelMode.car)


def test_router_is_off_without_a_key(monkeypatch):
    from app.core.config import Settings
    from app.services import routing
    monkeypatch.setattr(routing, "_router", None)
    assert configured_router(Settings(OPENROUTESERVICE_API_KEY=None)) is None
    assert isinstance(configured_router(Settings(OPENROUTESERVICE_API_KEY="k")), OrsRouter)
