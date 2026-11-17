import csv
import tempfile
from decimal import Decimal
from pathlib import Path

from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import CatalogSource, City, Stop
from apps.catalog.services import invalidate_catalog_cache
from apps.catalog.text import normalize_search_text


def make_stop(city: City, code: str, name: str, latitude: str, longitude: str) -> Stop:
    address = f"Endereço da {name}"
    return Stop.objects.create(
        city=city,
        code=code,
        name=name,
        address=address,
        latitude=Decimal(latitude),
        longitude=Decimal(longitude),
        search_text=normalize_search_text(" ".join((code, name, address))),
    )


class StopApiTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        user = make_user()
        access_token, _ = start_session(user)
        self.authenticate(access_token)

        self.city = City.objects.get(slug="teresina")
        self.near = make_stop(self.city, "2362", "T-SANTA FÉ", "-5.165446", "-42.791169")
        self.far = make_stop(self.city, "1848", "BENTINHO", "-5.200000", "-42.800000")
        self.other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        make_stop(self.other_city, "9999", "PARADA ALHEIA", "-5.165500", "-42.791200")

    def test_bbox_returns_only_stops_of_the_city_and_area(self):
        response = self.client.get(
            "/v1/cities/teresina/stops",
            {"bbox": "-42.792,-5.166,-42.790,-5.165"},
        )

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["count"] == 1
        assert [stop["code"] for stop in body["stops"]] == ["2362"]
        assert body["stops"][0]["name"] == "T-SANTA FÉ"
        assert body["stops"][0]["latitude"] == -5.165446
        assert response["X-Catalog-Cache"] == "MISS"

    def test_bbox_is_served_from_cache_and_invalidated_after_import(self):
        url = "/v1/cities/teresina/stops"
        params = {"bbox": "-42.792,-5.166,-42.790,-5.165"}

        first = self.client.get(url, params)
        second = self.client.get(url, params)
        assert first["X-Catalog-Cache"] == "MISS"
        assert second["X-Catalog-Cache"] == "HIT"

        make_stop(self.city, "1111", "NOVA PARADA", "-5.165500", "-42.791300")
        assert self.client.get(url, params)["X-Catalog-Cache"] == "HIT"

        invalidate_catalog_cache("teresina")
        third = self.client.get(url, params)
        assert third["X-Catalog-Cache"] == "MISS"
        assert third.json()["count"] == 2

    def test_invalid_bbox_uses_stable_error_code(self):
        response = self.client.get("/v1/cities/teresina/stops", {"bbox": "-42,-5"})

        self.assert_problem(response, status_code=400, code="invalid_bbox")

    def test_search_ignores_accents_and_matches_code_or_name(self):
        by_name = self.client.get("/v1/cities/teresina/stops", {"q": "santa fe"})
        by_code = self.client.get("/v1/cities/teresina/stops", {"q": "1848"})

        assert [stop["code"] for stop in by_name.json()["stops"]] == ["2362"]
        assert [stop["code"] for stop in by_code.json()["stops"]] == ["1848"]

    def test_find_by_codes_preserves_requested_order(self):
        response = self.client.get(
            "/v1/cities/teresina/stops", {"codes": "1848,2362,1848"}
        )

        assert [stop["code"] for stop in response.json()["stops"]] == [
            "1848",
            "2362",
            "1848",
        ]

    def test_detail_returns_the_stop(self):
        response = self.client.get(f"/v1/cities/teresina/stops/{self.near.id}")

        assert response.status_code == 200, response.content
        assert response.json()["code"] == "2362"

    def test_detail_uses_stable_not_found_error(self):
        response = self.client.get(
            "/v1/cities/teresina/stops/00000000-0000-0000-0000-000000000000"
        )

        self.assert_problem(response, status_code=404, code="stop_not_found")

    def test_inactive_city_is_rejected(self):
        self.other_city.is_active = False
        self.other_city.save(update_fields=["is_active"])

        response = self.client.get("/v1/cities/outra/stops")

        self.assert_problem(response, status_code=409, code="city_inactive")

    def test_requires_authentication(self):
        self.clear_credentials()

        response = self.client.get("/v1/cities/teresina/stops")

        assert response.status_code == 401, response.content


class ImportStopsCommandTests(TestCase):
    def setUp(self):
        cache.clear()
        self.city = City.objects.get(slug="teresina")

    def _write_csv(self, directory: str, rows: list[str]) -> Path:
        path = Path(directory) / "paradas.csv"
        with path.open("w", newline="", encoding="utf-8") as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(
                ["id", "codigo", "denominacao", "endereco", "lat", "long",
                 "created_at", "updated_at"]
            )
            for row in rows:
                writer.writerow(row)
        return path

    def test_imports_stops_idempotently_and_invalidates_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self._write_csv(
                directory,
                [
                    [
                        "1", "2362", "T-SANTA FÉ", "Rua B, Teresina - PI",
                        "-5.165446", "-42.791169", "", "",
                    ],
                    [
                        "2", "1848", "BENTINHO", "Rua Seis, Teresina - PI",
                        "-5.164533", "-42.789342", "", "",
                    ],
                    [
                        "3", "", "SEM CÓDIGO", "",
                        "-5.16", "-42.79", "", "",
                    ],
                ],
            )

            call_command("import_stops", "--city", "teresina", "--path", str(path))

            assert Stop.objects.filter(city=self.city).count() == 2
            source = CatalogSource.objects.get(city=self.city, slug="csv-paradas")
            assert source.data_mode == CatalogSource.DataMode.DEMO
            stop = Stop.objects.get(city=self.city, code="2362")
            assert stop.name == "T-SANTA FÉ"
            assert stop.search_text == "2362 t-santa fe rua b, teresina - pi"
            assert stop.source == source

            call_command("import_stops", "--city", "teresina", "--path", str(path))

            assert Stop.objects.filter(city=self.city).count() == 2
            assert CatalogSource.objects.filter(city=self.city).count() == 1

    def test_dry_run_does_not_write(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self._write_csv(
                directory,
                [["1", "2362", "SANTA FÉ", "", "-5.165446", "-42.791169", "", ""]],
            )

            call_command(
                "import_stops",
                "--city",
                "teresina",
                "--path",
                str(path),
                "--dry-run",
            )

            assert Stop.objects.filter(city=self.city).count() == 0
            assert CatalogSource.objects.filter(city=self.city).count() == 0
