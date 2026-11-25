import uuid
from decimal import Decimal

from django.core.cache import cache

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City, Line, LineAlias, LineStop, Route, Stop
from apps.catalog.services import invalidate_catalog_cache
from apps.catalog.text import normalize_search_text


def make_line(city: City, code: str, name: str, boarding_code: str) -> Line:
    return Line.objects.create(
        city=city,
        code=code,
        boarding_code=boarding_code,
        name=name,
        origin="Origem",
        destination="Destino",
        search_text=normalize_search_text(" ".join((code, boarding_code, name))),
    )


def make_stop(city: City, code: str, name: str) -> Stop:
    return Stop.objects.create(
        city=city,
        code=code,
        name=name,
        address="Endereço",
        latitude=Decimal("-5.16"),
        longitude=Decimal("-42.79"),
        search_text=normalize_search_text(" ".join((code, name))),
    )


class LineApiTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        cache.clear()
        user = make_user()
        access_token, _ = start_session(user)
        self.authenticate(access_token)

        self.city = City.objects.get(slug="teresina")
        self.line = make_line(self.city, "0001", "CENTRO - NORTE", "1")
        self.line_2 = make_line(self.city, "0002", "NORTE - CENTRO", "2")
        self.other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        make_line(self.other_city, "9999", "LINHA ALHEIA", "9999")

    def test_search_by_query_matches_code_name_and_boarding_code(self):
        by_code = self.client.get("/v1/cities/teresina/lines", {"q": "0001"})
        by_name = self.client.get("/v1/cities/teresina/lines", {"q": "centro norte"})
        by_boarding = self.client.get("/v1/cities/teresina/lines", {"q": "2"})

        assert by_code.status_code == 200, by_code.content
        assert [line["boardingCode"] for line in by_code.json()["lines"]] == ["1"]
        assert "1" in [line["boardingCode"] for line in by_name.json()["lines"]]
        assert "2" in [line["boardingCode"] for line in by_boarding.json()["lines"]]

    def test_payloads_never_expose_database_ids(self):
        response = self.client.get("/v1/cities/teresina/lines", {"q": "0001"})

        assert response.status_code == 200, response.content
        for line in response.json()["lines"]:
            assert "id" not in line
            assert "lineId" not in line
            assert line["boardingCode"]

    def test_search_does_not_return_lines_from_other_cities(self):
        response = self.client.get("/v1/cities/teresina/lines", {"q": "alheia"})

        assert response.status_code == 200, response.content
        assert response.json()["lines"] == []

    def test_search_by_codes_preserves_requested_order(self):
        response = self.client.get(
            "/v1/cities/teresina/lines", {"codes": "2,1,2"}
        )

        assert response.status_code == 200, response.content
        assert [line["boardingCode"] for line in response.json()["lines"]] == [
            "2",
            "1",
            "2",
        ]

    def test_search_by_codes_does_not_accept_internal_code(self):
        response = self.client.get(
            "/v1/cities/teresina/lines", {"codes": "0001"}
        )

        assert response.status_code == 200, response.content
        assert response.json()["lines"] == []

    def test_search_requires_query_or_codes(self):
        response = self.client.get("/v1/cities/teresina/lines")

        self.assert_problem(response, status_code=400, code="invalid_query")

    def test_search_is_cached_and_invalidated_after_import(self):
        url = "/v1/cities/teresina/lines"
        params = {"q": "centro"}

        first = self.client.get(url, params)
        second = self.client.get(url, params)
        assert first["X-Catalog-Cache"] == "MISS"
        assert second["X-Catalog-Cache"] == "HIT"

        invalidate_catalog_cache("teresina")
        assert self.client.get(url, params)["X-Catalog-Cache"] == "MISS"

    def test_detail_resolves_only_boarding_code(self):
        response = self.client.get("/v1/cities/teresina/lines/1")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["boardingCode"] == "1"
        assert body["name"] == "CENTRO - NORTE"
        assert body["origin"] == "Origem"
        assert body["destination"] == "Destino"
        assert "id" not in body
        assert "code" not in body
        assert "lineId" not in body

    def test_detail_does_not_resolve_uuid_internal_code_or_alias(self):
        LineAlias.objects.create(line=self.line, alias="linha-antiga", kind="legacy")

        for identifier in (str(self.line.id), "0001", "linha-antiga", str(uuid.uuid4())):
            with self.subTest(identifier=identifier):
                response = self.client.get(
                    f"/v1/cities/teresina/lines/{identifier}"
                )
                self.assert_problem(response, status_code=404, code="line_not_found")

    def test_detail_uses_stable_not_found_error(self):
        response = self.client.get("/v1/cities/teresina/lines/inexistente")

        self.assert_problem(response, status_code=404, code="line_not_found")

    def test_line_stops_keep_itinerary_order(self):
        first = make_stop(self.city, "100", "PRIMEIRA")
        second = make_stop(self.city, "200", "SEGUNDA")
        LineStop.objects.create(line=self.line, stop=second, direction=0, sequence=2)
        LineStop.objects.create(line=self.line, stop=first, direction=0, sequence=1)

        response = self.client.get("/v1/cities/teresina/lines/1/stops")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["count"] == 2
        assert [stop["code"] for stop in body["stops"]] == ["100", "200"]
        assert all("id" not in stop for stop in body["stops"])

    def test_line_stops_accept_direction_parameter(self):
        first = make_stop(self.city, "100", "PRIMEIRA")
        second = make_stop(self.city, "200", "SEGUNDA")
        LineStop.objects.create(line=self.line, stop=first, direction=0, sequence=1)
        LineStop.objects.create(line=self.line, stop=second, direction=1, sequence=1)

        default = self.client.get("/v1/cities/teresina/lines/1/stops")
        reverse = self.client.get("/v1/cities/teresina/lines/1/stops?direction=1")

        assert [stop["code"] for stop in default.json()["stops"]] == ["100"]
        assert [stop["code"] for stop in reverse.json()["stops"]] == ["200"]

    def test_line_stops_fall_back_to_reverse_direction(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=1, sequence=1)

        response = self.client.get("/v1/cities/teresina/lines/1/stops")

        assert response.status_code == 200, response.content
        assert [item["code"] for item in response.json()["stops"]] == ["100"]

    def test_repeated_stop_in_same_direction_is_allowed(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=1)
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=2)

        response = self.client.get("/v1/cities/teresina/lines/1/stops")

        assert response.status_code == 200, response.content
        assert [item["code"] for item in response.json()["stops"]] == ["100", "100"]

    def test_invalid_direction_is_rejected(self):
        response = self.client.get("/v1/cities/teresina/lines/1/stops?direction=2")

        self.assert_problem(response, status_code=400, code="invalid_direction")

    def test_line_route_falls_back_to_reverse_direction(self):
        Route.objects.create(
            line=self.line,
            direction=1,
            path=[[-5.16, -42.79], [-5.17, -42.80]],
        )

        response = self.client.get("/v1/cities/teresina/lines/1/route")

        assert response.status_code == 200, response.content
        assert response.json()["direction"] == 1

    def test_line_route_returns_coordinates_in_order(self):
        Route.objects.create(
            line=self.line,
            direction=0,
            path=[[-5.16, -42.79], [-5.17, -42.80]],
        )

        response = self.client.get("/v1/cities/teresina/lines/1/route")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["boardingCode"] == "1"
        assert "lineId" not in body
        assert body["coordinates"] == [[-5.16, -42.79], [-5.17, -42.80]]

    def test_line_without_route_returns_null(self):
        response = self.client.get("/v1/cities/teresina/lines/1/route")

        assert response.status_code == 200, response.content
        assert response.json() == {"route": None}

    def test_line_directions_return_labels_from_itinerary_endpoints(self):
        first = make_stop(self.city, "100", "PRIMEIRA")
        second = make_stop(self.city, "200", "SEGUNDA")
        LineStop.objects.create(line=self.line, stop=first, direction=0, sequence=1)
        LineStop.objects.create(line=self.line, stop=second, direction=0, sequence=2)
        LineStop.objects.create(line=self.line, stop=second, direction=1, sequence=1)
        LineStop.objects.create(line=self.line, stop=first, direction=1, sequence=2)
        Route.objects.create(
            line=self.line,
            direction=0,
            path=[[-5.16, -42.79], [-5.17, -42.80]],
        )

        response = self.client.get("/v1/cities/teresina/lines/1/directions")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["boardingCode"] == "1"
        assert body["directions"] == [
            {
                "value": 0,
                "label": "PRIMEIRA → SEGUNDA",
                "hasRoute": True,
                "stopCount": 2,
            },
            {
                "value": 1,
                "label": "SEGUNDA → PRIMEIRA",
                "hasRoute": False,
                "stopCount": 2,
            },
        ]

    def test_line_directions_fall_back_to_line_endpoints_without_stops(self):
        Route.objects.create(
            line=self.line,
            direction=0,
            path=[[-5.16, -42.79], [-5.17, -42.80]],
        )

        response = self.client.get("/v1/cities/teresina/lines/1/directions")

        assert response.status_code == 200, response.content
        assert response.json()["directions"] == [
            {
                "value": 0,
                "label": "Origem → Destino",
                "hasRoute": True,
                "stopCount": 0,
            }
        ]

    def test_line_directions_are_empty_without_itinerary(self):
        response = self.client.get("/v1/cities/teresina/lines/1/directions")

        assert response.status_code == 200, response.content
        assert response.json() == {"boardingCode": "1", "directions": []}

    def test_line_directions_use_stable_not_found_error(self):
        response = self.client.get(
            "/v1/cities/teresina/lines/inexistente/directions"
        )

        self.assert_problem(response, status_code=404, code="line_not_found")

    def test_stop_lines_returns_lines_passing_through_stop(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=1)

        response = self.client.get("/v1/cities/teresina/stops/100/lines")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["count"] == 1
        assert body["lines"][0]["boardingCode"] == "1"
        assert "id" not in body["lines"][0]

    def test_stop_lines_resolves_stop_only_by_code(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=1)

        by_code = self.client.get("/v1/cities/teresina/stops/100/lines")
        by_uuid = self.client.get(
            f"/v1/cities/teresina/stops/{stop.id}/lines"
        )

        assert by_code.status_code == 200, by_code.content
        assert by_code.json()["lines"][0]["boardingCode"] == "1"
        self.assert_problem(by_uuid, status_code=404, code="stop_not_found")

    def test_inactive_city_is_rejected(self):
        self.other_city.is_active = False
        self.other_city.save(update_fields=["is_active"])

        response = self.client.get("/v1/cities/outra/lines", {"q": "alheia"})

        self.assert_problem(response, status_code=409, code="city_inactive")

    def test_unknown_city_is_rejected(self):
        response = self.client.get("/v1/cities/inexistente/lines", {"q": "teste"})

        self.assert_problem(response, status_code=404, code="city_not_found")

    def test_requires_authentication(self):
        self.clear_credentials()

        response = self.client.get("/v1/cities/teresina/lines", {"q": "centro"})

        assert response.status_code == 401, response.content
