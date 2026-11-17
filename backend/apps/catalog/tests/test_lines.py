import uuid
from decimal import Decimal

from django.core.cache import cache

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City, Line, LineAlias, LineStop, Route, Stop
from apps.catalog.services import invalidate_catalog_cache
from apps.catalog.text import normalize_search_text


def make_line(city: City, code: str, name: str, boarding_code: str = "") -> Line:
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
        self.line = make_line(self.city, "0001", "CENTRO - NORTE", boarding_code="1")
        self.line_2 = make_line(self.city, "0002", "NORTE - CENTRO", boarding_code="2")
        self.other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        make_line(self.other_city, "9999", "LINHA ALHEIA")

    def test_search_by_query_matches_code_name_and_boarding_code(self):
        by_code = self.client.get("/v1/cities/teresina/lines", {"q": "0001"})
        by_name = self.client.get("/v1/cities/teresina/lines", {"q": "centro norte"})
        by_boarding = self.client.get("/v1/cities/teresina/lines", {"q": "2"})

        assert by_code.status_code == 200, by_code.content
        assert [line["id"] for line in by_code.json()["lines"]] == [str(self.line.id)]
        assert str(self.line.id) in [line["id"] for line in by_name.json()["lines"]]
        assert str(self.line_2.id) in [line["id"] for line in by_boarding.json()["lines"]]

    def test_search_does_not_return_lines_from_other_cities(self):
        response = self.client.get("/v1/cities/teresina/lines", {"q": "alheia"})

        assert response.status_code == 200, response.content
        assert response.json()["lines"] == []

    def test_search_by_codes_preserves_requested_order(self):
        response = self.client.get(
            "/v1/cities/teresina/lines", {"codes": "0002,0001,0002"}
        )

        assert response.status_code == 200, response.content
        assert [line["code"] for line in response.json()["lines"]] == [
            "0002",
            "0001",
            "0002",
        ]

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

    def test_detail_resolves_uuid_code_and_boarding_code(self):
        for identifier in (
            str(self.line.id),
            "0001",
            "1",
        ):
            with self.subTest(identifier=identifier):
                response = self.client.get(
                    f"/v1/cities/teresina/lines/{identifier}"
                )
                assert response.status_code == 200, response.content
                body = response.json()
                assert body["id"] == str(self.line.id)
                assert body["code"] == "0001"
                assert body["boardingCode"] == "1"
                assert body["origin"] == "Origem"
                assert body["destination"] == "Destino"

    def test_detail_resolves_alias(self):
        LineAlias.objects.create(line=self.line, alias="linha-antiga", kind="legacy")

        response = self.client.get(
            "/v1/cities/teresina/lines/linha-antiga"
        )

        assert response.status_code == 200, response.content
        assert response.json()["id"] == str(self.line.id)

    def test_detail_uses_stable_not_found_error(self):
        response = self.client.get(
            f"/v1/cities/teresina/lines/{uuid.uuid4()}"
        )

        self.assert_problem(response, status_code=404, code="line_not_found")

    def test_ambiguous_alias_returns_conflict(self):
        LineAlias.objects.create(line=self.line, alias="comum")
        LineAlias.objects.create(line=self.line_2, alias="comum")

        response = self.client.get("/v1/cities/teresina/lines/comum")

        self.assert_problem(response, status_code=409, code="ambiguous_line_code")

    def test_line_stops_keep_itinerary_order(self):
        first = make_stop(self.city, "100", "PRIMEIRA")
        second = make_stop(self.city, "200", "SEGUNDA")
        LineStop.objects.create(line=self.line, stop=second, direction=0, sequence=2)
        LineStop.objects.create(line=self.line, stop=first, direction=0, sequence=1)

        response = self.client.get(
            f"/v1/cities/teresina/lines/{self.line.id}/stops"
        )

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["count"] == 2
        assert [stop["code"] for stop in body["stops"]] == ["100", "200"]

    def test_line_route_returns_coordinates_in_order(self):
        Route.objects.create(
            line=self.line,
            direction=0,
            path=[[-5.16, -42.79], [-5.17, -42.80]],
        )

        response = self.client.get(
            f"/v1/cities/teresina/lines/{self.line.id}/route"
        )

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["lineId"] == str(self.line.id)
        assert body["coordinates"] == [[-5.16, -42.79], [-5.17, -42.80]]

    def test_line_without_route_returns_null(self):
        response = self.client.get(
            f"/v1/cities/teresina/lines/{self.line.id}/route"
        )

        assert response.status_code == 200, response.content
        assert response.json() == {"route": None}

    def test_stop_lines_returns_lines_passing_through_stop(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=1)

        response = self.client.get(
            f"/v1/cities/teresina/stops/{stop.id}/lines"
        )

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["count"] == 1
        assert body["lines"][0]["id"] == str(self.line.id)

    def test_stop_lines_resolves_stop_by_code(self):
        stop = make_stop(self.city, "100", "PRIMEIRA")
        LineStop.objects.create(line=self.line, stop=stop, direction=0, sequence=1)

        response = self.client.get("/v1/cities/teresina/stops/100/lines")

        assert response.status_code == 200, response.content
        assert response.json()["lines"][0]["id"] == str(self.line.id)

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
