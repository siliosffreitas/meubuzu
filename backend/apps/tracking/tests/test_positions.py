from datetime import UTC, datetime
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services import start_session
from apps.catalog.models import City, Line

TUESDAY_FILE = "positions_2023_06_06.csv"
MONDAY_FILE = "positions_2023_06_05.csv"


def _fixed_datetime(moment: datetime):
    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return moment if tz is None else moment.astimezone(tz)

    return FixedDateTime


def _row(label: str, line: str, bus: str, generated: str, lat: str, lon: str, captured: str):
    return f"{label},{line},{bus},{generated},{lat},{lon},{captured}"


class PositionApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.city = City.objects.get(slug="teresina")
        cls.line = Line.objects.create(
            city=cls.city,
            code="35",
            boarding_code="0301",
            name="Linha 35",
        )
        cls.other_line = Line.objects.create(
            city=cls.city,
            code="47",
            boarding_code="0245",
            name="Linha 47",
        )

    def setUp(self):
        self.tmp = TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

        override = override_settings(
            CACHES={
                "default": {
                    "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
                    "LOCATION": "tracking-tests",
                }
            },
            TRACKING_CSV_DIR=self.tmp.name,
            TRACKING_DEMO_ACCESS_ENABLED=True,
        )
        override.enable()
        self.addCleanup(override.disable)
        cache.clear()

        self.client = APIClient()
        user = User.objects.create_user(email="tracking@exemplo.com")
        user.mark_email_verified()
        access_token, _ = start_session(user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access_token}")

    def write_rows(self, rows: list[str], *, file_name: str = TUESDAY_FILE) -> None:
        (Path(self.tmp.name) / file_name).write_text(
            "\n".join(rows) + "\n",
            encoding="utf-8",
        )

    def get_positions(self, codes: str):
        return self.client.get("/v1/cities/teresina/positions", {"codes": codes})

    def assert_problem(self, response, *, status_code: int, code: str) -> None:
        assert response.status_code == status_code, response.content
        assert response["Content-Type"].startswith("application/problem+json")
        body = response.json()
        assert body["code"] == code, body
        assert body["status"] == status_code

    @patch(
        "apps.tracking.services.datetime",
        _fixed_datetime(datetime(2026, 11, 17, 15, 5, tzinfo=UTC)),
    )
    def test_batch_returns_rebased_positions_for_each_line(self):
        self.write_rows(
            [
                _row(
                    "BUS",
                    "35",
                    "4171",
                    "2023-06-06T12:04:00.000+0000",
                    "-5.10",
                    "-42.80",
                    "2023-06-06T12:04:30.000+0000",
                ),
                _row(
                    "BUS",
                    "35",
                    "4171",
                    "2023-06-06T12:02:00.000+0000",
                    "-5.11",
                    "-42.81",
                    "2023-06-06T12:02:30.000+0000",
                ),
                _row(
                    "BUS",
                    "35",
                    "5093",
                    "2023-06-06T12:02:28.000+0000",
                    "-5.12",
                    "-42.82",
                    "2023-06-06T12:02:58.000+0000",
                ),
                _row(
                    "BUS",
                    "47",
                    "7788",
                    "2023-06-06T11:59:30.000+0000",
                    "-5.13",
                    "-42.83",
                    "2023-06-06T12:00:00.000+0000",
                ),
            ]
        )

        response = self.get_positions("0301,0245")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["city"] == "teresina"
        assert body["source"] == "csv_demo"
        assert body["dataMode"] == "demo"
        assert [block["lineId"] for block in body["lines"]] == [
            str(self.line.id),
            str(self.other_line.id),
        ]
        assert body["unresolvedLines"] == []

        line_35 = body["lines"][0]
        assert line_35["requestedId"] == "0301"
        assert line_35["boardingCode"] == "0301"
        assert line_35["sourceStatus"] == "ok"
        assert line_35["isStale"] is True
        assert [item["vehicleCode"] for item in line_35["positions"]] == ["5093", "4171"]
        assert line_35["positions"][0]["isStale"] is True
        assert line_35["positions"][-1] == {
            "lineId": str(self.line.id),
            "boardingCode": "0301",
            "vehicleCode": "4171",
            "latitude": -5.1,
            "longitude": -42.8,
            "capturedAt": "2026-11-17T15:04:30Z",
            "generatedAt": "2026-11-17T15:04:00Z",
            "receivedAt": "2026-11-17T15:05:00Z",
            "speed": None,
            "heading": None,
            "isStale": False,
        }

        line_47 = body["lines"][1]
        assert line_47["boardingCode"] == "0245"
        assert line_47["positions"][0]["isStale"] is True
        assert line_47["positions"][0]["capturedAt"] == "2026-11-17T15:00:00Z"

    @patch(
        "apps.tracking.services.datetime",
        _fixed_datetime(datetime(2026, 11, 17, 15, 5, tzinfo=UTC)),
    )
    def test_window_excludes_old_future_and_invalid_rows(self):
        self.write_rows(
            [
                _row(
                    "BUS",
                    "35",
                    "ANTIGA",
                    "2023-06-06T11:59:00.000+0000",
                    "-5.10",
                    "-42.80",
                    "2023-06-06T11:59:59.000+0000",
                ),
                _row(
                    "BUS",
                    "35",
                    "FUTURO",
                    "2023-06-06T12:06:00.000+0000",
                    "-5.10",
                    "-42.80",
                    "2023-06-06T12:06:30.000+0000",
                ),
                _row(
                    "BUS",
                    "35",
                    "INVALIDA",
                    "2023-06-06T12:04:00.000+0000",
                    "999",
                    "-42.80",
                    "2023-06-06T12:04:30.000+0000",
                ),
                _row(
                    "BUS",
                    "35",
                    "VALIDA",
                    "2023-06-06T12:04:00.000+0000",
                    "-5.10",
                    "-42.80",
                    "2023-06-06T12:04:30.000+0000",
                ),
            ]
        )

        response = self.get_positions("0301")

        assert response.status_code == 200, response.content
        positions = response.json()["lines"][0]["positions"]
        assert [item["vehicleCode"] for item in positions] == ["VALIDA"]

    @patch(
        "apps.tracking.services.datetime",
        _fixed_datetime(datetime(2026, 11, 16, 15, 5, tzinfo=UTC)),
    )
    def test_weekday_selects_its_own_file(self):
        self.write_rows(
            [
                _row(
                    "BUS",
                    "35",
                    "SEGUNDA",
                    "2023-06-05T12:04:00.000+0000",
                    "-5.10",
                    "-42.80",
                    "2023-06-05T12:04:30.000+0000",
                )
            ],
            file_name=MONDAY_FILE,
        )

        response = self.get_positions("0301")

        assert response.status_code == 200, response.content
        assert [item["vehicleCode"] for item in response.json()["lines"][0]["positions"]] == [
            "SEGUNDA"
        ]

    @patch(
        "apps.tracking.services.datetime",
        _fixed_datetime(datetime(2026, 11, 17, 15, 5, tzinfo=UTC)),
    )
    def test_duplicate_and_unknown_codes_are_handled_without_losing_lines(self):
        self.write_rows([])

        response = self.get_positions("0301,0301,9999")

        assert response.status_code == 200, response.content
        body = response.json()
        assert [block["lineId"] for block in body["lines"]] == [str(self.line.id)]
        assert [block["requestedId"] for block in body["lines"]] == ["0301"]
        assert body["unresolvedLines"] == ["9999"]

    def test_codigo_linha_is_not_accepted_as_sglinha(self):
        self.write_rows([])

        response = self.get_positions("35")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["lines"] == []
        assert body["unresolvedLines"] == ["35"]

    def test_empty_window_returns_empty_positions(self):
        self.write_rows([])

        response = self.get_positions("0301")

        assert response.status_code == 200, response.content
        block = response.json()["lines"][0]
        assert block["sourceStatus"] == "no_positions"
        assert block["positions"] == []
        assert block["isStale"] is False

    def test_missing_file_returns_source_unavailable(self):
        response = self.get_positions("0301")
        self.assert_problem(response, status_code=503, code="source_unavailable")

    def test_single_route_resolves_sglinha(self):
        self.write_rows([])

        response = self.client.get("/v1/cities/teresina/lines/0301/positions")

        assert response.status_code == 200, response.content
        block = response.json()["lines"][0]
        assert block["lineId"] == str(self.line.id)
        assert block["boardingCode"] == "0301"

    def test_single_route_keeps_line_not_found(self):
        self.write_rows([])

        response = self.client.get("/v1/cities/teresina/lines/9999/positions")

        self.assert_problem(response, status_code=404, code="line_not_found")

    def test_missing_codes_returns_invalid_codes(self):
        response = self.client.get("/v1/cities/teresina/positions")
        self.assert_problem(response, status_code=400, code="invalid_codes")

        response = self.get_positions(",".join(str(number) for number in range(201)))
        self.assert_problem(response, status_code=400, code="invalid_codes")

    def test_city_errors_are_preserved(self):
        response = self.client.get(
            "/v1/cities/inexistente/positions", {"codes": "0301"}
        )
        self.assert_problem(response, status_code=404, code="city_not_found")

        self.city.is_active = False
        self.city.save(update_fields=["is_active"])
        response = self.get_positions("0301")
        self.assert_problem(response, status_code=409, code="city_inactive")

    def test_cache_header_reports_hit_on_second_request(self):
        self.write_rows([])

        first = self.get_positions("0301")
        second = self.get_positions("0301")

        assert first.status_code == 200, first.content
        assert second.status_code == 200, second.content
        assert first["X-Tracking-Cache"] == "MISS"
        assert second["X-Tracking-Cache"] == "HIT"

    @override_settings(DEBUG=True, TRACKING_DEMO_ACCESS_ENABLED=False)
    def test_demo_access_disabled_requires_subscription(self):
        response = self.get_positions("0301")
        self.assert_problem(response, status_code=402, code="subscription_required")

    @override_settings(DEBUG=False, TRACKING_DEMO_ACCESS_ENABLED=False)
    def test_csv_source_is_forbidden_in_production(self):
        response = self.get_positions("0301")
        self.assert_problem(response, status_code=500, code="demo_mode_forbidden")
