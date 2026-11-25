"""Testes do crawler de posições da API Olho Vivo."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import patch

from django.test import TestCase, override_settings

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City, Line
from apps.integrations.sptrans.client import VehiclePositionRecord
from apps.tracking.crawler import crawl_positions, record_source_error, record_source_success
from apps.tracking.models import LatestPosition, PositionHistory, TrackingSource

NOW = datetime(2026, 11, 21, 12, 0, tzinfo=UTC)


class FakeClient:
    def __init__(self, records: list[VehiclePositionRecord]) -> None:
        self.records = records
        self.authenticated = False

    def authenticate(self) -> None:
        self.authenticated = True

    def positions(self) -> list[VehiclePositionRecord]:
        return self.records


def position(
    *,
    vehicle: str = "12345",
    line_code: str = "1012-10",
    latitude: float = -23.55,
    longitude: float = -46.63,
    captured_at: datetime = NOW,
    direction: int = 0,
    accessible: bool = True,
) -> VehiclePositionRecord:
    return VehiclePositionRecord(
        line_code=line_code,
        vehicle_code=vehicle,
        latitude=latitude,
        longitude=longitude,
        captured_at=captured_at,
        direction=direction,
        is_accessible=accessible,
    )


@override_settings(
    TRACKING_HISTORY_ENABLED=True,
    TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS=600,
)
class CrawlPositionsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.city = City.objects.get(slug="sao-paulo")
        cls.source = TrackingSource.objects.get(city=cls.city, is_active=True)
        cls.line = Line.objects.create(
            city=cls.city,
            code="1012-10",
            boarding_code="1012-10",
            name="Term. A - Jd. B",
        )

    def crawl(self, records, *, now=NOW, write_history=False):
        return crawl_positions(
            city=self.city,
            source=self.source,
            client=FakeClient(records),
            now=now,
            write_history=write_history,
        )

    def test_writes_latest_position(self):
        result = self.crawl([position()])

        assert result.positions == 1
        assert result.updated == 1
        assert result.errors == 0

        latest = LatestPosition.objects.get(city=self.city, vehicle_code="12345")
        assert latest.line_id == self.line.id
        assert latest.source_id == self.source.id
        assert latest.data_mode == "live"
        assert latest.direction == 0
        assert latest.is_accessible is True
        assert latest.latitude == Decimal("-23.550000")
        assert latest.longitude == Decimal("-46.630000")
        assert latest.previous_latitude is None
        assert latest.heading is None

    def test_keeps_previous_position_and_computes_heading(self):
        self.crawl([position(latitude=-23.55, longitude=-46.63)])

        later = NOW + timedelta(seconds=30)
        self.crawl(
            [position(latitude=-23.56, longitude=-46.64, captured_at=later)],
            now=later,
        )

        latest = LatestPosition.objects.get(city=self.city, vehicle_code="12345")
        assert latest.previous_latitude == Decimal("-23.550000")
        assert latest.previous_longitude == Decimal("-46.630000")
        assert latest.heading is not None
        assert latest.captured_at == later

    def test_ignores_older_capture(self):
        self.crawl([position(captured_at=NOW)])

        result = self.crawl(
            [position(captured_at=NOW - timedelta(seconds=30))],
            now=NOW + timedelta(seconds=30),
        )

        assert result.updated == 0
        assert result.ignored == 1
        latest = LatestPosition.objects.get(city=self.city, vehicle_code="12345")
        assert latest.captured_at == NOW

    def test_counts_unknown_lines_without_writing(self):
        result = self.crawl([position(line_code="9999-99")])

        assert result.unresolved_lines == 1
        assert result.updated == 0
        assert not LatestPosition.objects.filter(city=self.city).exists()

    def test_selects_newest_record_per_vehicle(self):
        older = position(latitude=-23.55, captured_at=NOW - timedelta(seconds=10))
        newer = position(latitude=-23.56, captured_at=NOW)

        result = self.crawl([older, newer])

        assert result.updated == 1
        latest = LatestPosition.objects.get(city=self.city, vehicle_code="12345")
        assert latest.latitude == Decimal("-23.560000")

    def test_writes_history_row(self):
        result = self.crawl([position()], write_history=True)

        assert result.history_rows == 1
        assert PositionHistory.objects.filter(vehicle_code="12345").count() == 1

    def test_skips_history_for_old_capture(self):
        old = position(captured_at=NOW - timedelta(minutes=20))

        result = self.crawl([old], write_history=True)

        assert result.updated == 1
        assert result.history_rows == 0
        assert PositionHistory.objects.filter(vehicle_code="12345").count() == 0

    def test_history_failure_does_not_break_latest_position(self):
        with patch(
            "apps.tracking.partitions.ensure_partitions",
            side_effect=RuntimeError("sem partição"),
        ):
            result = self.crawl([position()], write_history=True)

        assert result.errors == 1
        assert result.history_rows == 0
        assert result.updated == 1
        assert LatestPosition.objects.filter(city=self.city, vehicle_code="12345").exists()


class SourceStatusTests(TestCase):
    def setUp(self):
        self.source = TrackingSource.objects.get(
            city__slug="sao-paulo", is_active=True
        )

    def test_records_success(self):
        record_source_success(self.source)

        self.source.refresh_from_db()
        assert self.source.last_success_at is not None
        assert self.source.last_error_at is None
        assert self.source.last_error_message == ""

    def test_records_error(self):
        record_source_error(self.source, RuntimeError("falha de rede"))

        self.source.refresh_from_db()
        assert self.source.last_error_at is not None
        assert self.source.last_error_message == "falha de rede"
        assert self.source.last_success_at is None


@override_settings(
    TRACKING_LIVE_ACCESS_ENABLED=True,
    TRACKING_STALE_AFTER_SECONDS=120,
    TRACKING_CACHE_TTL_SECONDS=0,
)
class LivePositionsApiTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        self.city = City.objects.get(slug="sao-paulo")
        City.objects.filter(pk=self.city.pk).update(is_active=True)
        self.city.refresh_from_db()
        self.source = TrackingSource.objects.get(city=self.city, is_active=True)
        self.line = Line.objects.create(
            city=self.city,
            code="1012-10",
            boarding_code="1012-10",
            name="Term. A - Jd. B",
        )
        user = make_user()
        access_token, _ = start_session(user)
        self.authenticate(access_token)

    def make_position(self, **overrides) -> LatestPosition:
        moment = datetime.now(UTC)
        values = {
            "city": self.city,
            "line": self.line,
            "source": self.source,
            "vehicle_code": "12345",
            "latitude": Decimal("-23.550000"),
            "longitude": Decimal("-46.630000"),
            "direction": 0,
            "is_accessible": True,
            "data_mode": "live",
            "captured_at": moment,
            "received_at": moment,
        }
        values.update(overrides)
        return LatestPosition.objects.create(**values)

    def get_positions(self, codes: str = "1012-10"):
        return self.client.get("/v1/cities/sao-paulo/positions", {"codes": codes})

    def test_returns_live_positions_from_latest_position(self):
        self.make_position()

        response = self.get_positions()

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["source"] == "sptrans_api"
        assert body["dataMode"] == "live"
        assert body["city"] == "sao-paulo"

        line = body["lines"][0]
        assert line["boardingCode"] == "1012-10"
        assert line["source"] == "sptrans_api"
        assert line["dataMode"] == "live"
        position_payload = line["positions"][0]
        assert position_payload["vehicleCode"] == "12345"
        assert position_payload["latitude"] == -23.55
        assert position_payload["previousLatitude"] is None
        assert position_payload["isStale"] is False

    def test_live_payload_does_not_leak_internal_ids(self):
        self.make_position()

        response = self.get_positions()

        body = response.content.decode()
        assert "1273" not in body
        assert "externalId" not in body

    @override_settings(TRACKING_LIVE_MAX_POSITION_AGE_SECONDS=300)
    def test_drops_positions_older_than_max_age(self):
        moment = datetime.now(UTC)
        self.make_position(
            vehicle_code="ANTIGA",
            captured_at=moment - timedelta(seconds=301),
            received_at=moment,
        )
        self.make_position(
            vehicle_code="RECENTE",
            captured_at=moment - timedelta(seconds=299),
            received_at=moment,
        )

        response = self.get_positions()

        assert response.status_code == 200, response.content
        positions = response.json()["lines"][0]["positions"]
        assert [item["vehicleCode"] for item in positions] == ["RECENTE"]

    @override_settings(TRACKING_LIVE_MAX_POSITION_AGE_SECONDS=300)
    def test_line_with_only_old_positions_returns_empty_block(self):
        moment = datetime.now(UTC)
        self.make_position(
            captured_at=moment - timedelta(seconds=301),
            received_at=moment,
        )

        response = self.get_positions()

        assert response.status_code == 200, response.content
        line = response.json()["lines"][0]
        assert line["positions"] == []
        assert line["sourceStatus"] == "no_positions"
        assert line["isStale"] is False

    def test_empty_line_returns_empty_block(self):
        response = self.get_positions()

        assert response.status_code == 200, response.content
        line = response.json()["lines"][0]
        assert line["positions"] == []
        assert line["sourceStatus"] == "no_positions"

    def test_requires_live_access_flag(self):
        with self.settings(TRACKING_LIVE_ACCESS_ENABLED=False):
            response = self.get_positions()

        self.assert_problem(response, status_code=402, code="subscription_required")
