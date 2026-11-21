"""Testes da importação de catálogo de São Paulo (API Olho Vivo + GTFS)."""

from __future__ import annotations

from django.core.cache import cache
from django.test import TestCase, override_settings

from apps.catalog.models import (
    CatalogImportRun,
    CatalogSource,
    City,
    Line,
    LineSourceRef,
    LineStop,
    Route,
    Stop,
)
from apps.catalog.payloads import line_payload
from apps.catalog.sptrans_import import import_catalog
from apps.integrations.sptrans.client import LineRecord, StopRecord
from apps.integrations.sptrans.errors import SPTransError
from apps.integrations.sptrans.gtfs import GtfsRoute


def line_record(
    external_id: str, direction: int, code: str = "1012-10"
) -> LineRecord:
    return LineRecord(
        external_id=external_id,
        public_code=code,
        direction=direction,
        origin_label="Term. A",
        destination_label="Jd. B",
        search_terms=(code, code.split("-")[0], code.split("-")[-1]),
    )


STOP_A = StopRecord(
    code="100", name="Terminal A", address="Rua A", latitude=-23.50, longitude=-46.60
)
STOP_B = StopRecord(
    code="200", name="Jardim B", address="Rua B", latitude=-23.60, longitude=-46.70
)


class FakeClient:
    """Cliente da SPTrans em memória, com falha configurável por linha."""

    def __init__(
        self,
        lines: dict[str, list[LineRecord]] | None = None,
        stops: dict[str, list[StopRecord]] | None = None,
        fail_codes: set[str] | None = None,
    ) -> None:
        self.lines = lines or {}
        self.stops = stops or {}
        self.fail_codes = fail_codes or set()
        self.authenticated = False

    def authenticate(self) -> None:
        self.authenticated = True

    def search_lines(self, term: str) -> list[LineRecord]:
        if term in self.fail_codes:
            raise SPTransError(f"falha simulada para {term}")
        return self.lines.get(term, [])

    def stops_for_line(self, external_id: str) -> list[StopRecord]:
        return self.stops.get(external_id, [])


class FakeFeed:
    """GTFS em memória com rotas, shapes e pontos."""

    def __init__(
        self,
        routes: dict[str, GtfsRoute],
        shape_map: dict[tuple[str, int], str],
        shapes: dict[str, list[tuple[float, float]]],
    ) -> None:
        self._routes = routes
        self._shape_map = shape_map
        self._shapes = shapes

    def routes(self) -> dict[str, GtfsRoute]:
        return self._routes

    def shape_map(self) -> dict[tuple[str, int], str]:
        return self._shape_map

    def shapes(self, shape_ids) -> dict[str, list[tuple[float, float]]]:
        wanted = set(shape_ids)
        return {
            shape_id: points
            for shape_id, points in self._shapes.items()
            if shape_id in wanted
        }


def make_feed(
    codes: tuple[str, ...] = ("1012-10",),
    *,
    with_shapes: bool = True,
) -> FakeFeed:
    routes = {
        code: GtfsRoute(
            route_id=code,
            short_name=code,
            long_name="Term. A - Jd. B",
            route_type=3,
        )
        for code in codes
    }
    shape_map: dict[tuple[str, int], str] = {}
    shapes: dict[str, list[tuple[float, float]]] = {}
    if with_shapes:
        for code in codes:
            shape_map[(code, 0)] = f"{code}-0"
            shape_map[(code, 1)] = f"{code}-1"
            shapes[f"{code}-0"] = [
                (-23.50, -46.60),
                (-23.55, -46.65),
                (-23.60, -46.70),
            ]
            shapes[f"{code}-1"] = [
                (-23.60, -46.70),
                (-23.55, -46.65),
                (-23.50, -46.60),
            ]
    return FakeFeed(routes, shape_map, shapes)


def make_client(codes: tuple[str, ...] = ("1012-10",)) -> FakeClient:
    lines: dict[str, list[LineRecord]] = {}
    stops: dict[str, list[StopRecord]] = {}
    for code in codes:
        if code == "1012-10":
            forward_id, reverse_id = "1273", "1274"
        else:
            forward_id, reverse_id = f"{code}-0", f"{code}-1"
        lines[code] = [
            line_record(forward_id, 0, code),
            line_record(reverse_id, 1, code),
        ]
        stops[forward_id] = [STOP_A, STOP_B]
        stops[reverse_id] = [STOP_B, STOP_A]
    return FakeClient(lines=lines, stops=stops)


@override_settings(
    CACHES={
        "default": {
            "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
            "LOCATION": "sptrans-import-tests",
        }
    }
)
class ImportCatalogTests(TestCase):
    def setUp(self):
        cache.clear()
        self.city = City.objects.get(slug="sao-paulo")
        self.source = CatalogSource.objects.create(
            city=self.city,
            slug="sptrans-api",
            name="API Olho Vivo (SPTrans)",
            kind=CatalogSource.Kind.SPTRANS_API,
            data_mode=CatalogSource.DataMode.LIVE,
        )

    def run_import(self, client=None, feed=None, **kwargs):
        return import_catalog(
            city=self.city,
            source=self.source,
            client=client or make_client(),
            feed=feed if feed is not None else make_feed(),
            **kwargs,
        )

    def test_merges_both_directions_into_one_line(self):
        result = self.run_import()

        assert result.errors == 0, result.messages
        line = Line.objects.get(city=self.city, code="1012-10")
        assert line.boarding_code == "1012-10"
        assert line.name == "Term. A - Jd. B"
        assert line.origin == "Term. A"
        assert line.destination == "Jd. B"
        assert line.source == self.source
        assert line.is_active is True

        refs = LineSourceRef.objects.filter(line=line)
        assert set(refs.values_list("external_id", flat=True)) == {"1273", "1274"}
        assert set(refs.values_list("direction", flat=True)) == {0, 1}

    def test_imports_stops_and_itineraries_per_direction(self):
        self.run_import()

        line = Line.objects.get(city=self.city, code="1012-10")
        assert Stop.objects.filter(city=self.city).count() == 2

        forward = LineStop.objects.filter(line=line, direction=0).order_by("sequence")
        reverse = LineStop.objects.filter(line=line, direction=1).order_by("sequence")
        assert [(item.stop.code, item.sequence) for item in forward] == [
            ("100", 1),
            ("200", 2),
        ]
        assert [(item.stop.code, item.sequence) for item in reverse] == [
            ("200", 1),
            ("100", 2),
        ]

    def test_imports_shapes_for_both_directions(self):
        self.run_import()

        line = Line.objects.get(city=self.city, code="1012-10")
        routes = {route.direction: route.path for route in Route.objects.filter(line=line)}
        assert set(routes) == {0, 1}
        assert routes[0][0] == [-23.50, -46.60]
        assert routes[0][-1] == [-23.60, -46.70]
        assert routes[1][0] == [-23.60, -46.70]

    def test_import_is_idempotent(self):
        self.run_import()
        self.run_import()

        assert Line.objects.filter(city=self.city).count() == 1
        assert LineSourceRef.objects.filter(line__city=self.city).count() == 2
        assert Stop.objects.filter(city=self.city).count() == 2
        assert LineStop.objects.filter(line__city=self.city).count() == 4
        assert Route.objects.filter(line__city=self.city).count() == 2

    def test_records_import_run_as_success(self):
        self.run_import()

        run = CatalogImportRun.objects.get(city=self.city)
        assert run.status == CatalogImportRun.Status.SUCCESS
        assert run.lines_created == 1
        assert run.stops_created == 2
        assert run.routes_updated == 2
        assert run.finished_at is not None
        assert self.source.last_import_at is not None
        assert self.source.last_error_at is None

    def test_partial_failure_preserves_previous_catalog(self):
        previous = Line.objects.create(
            city=self.city,
            code="0001",
            boarding_code="0001",
            name="Linha anterior",
        )

        client = make_client(codes=("1012-10", "9000-1"))
        client.fail_codes = {"9000-1"}
        result = self.run_import(client=client, feed=make_feed(("1012-10", "9000-1")))

        assert result.errors == 1
        assert result.lines_created == 1
        # A linha importada com sucesso existe.
        assert Line.objects.filter(city=self.city, code="1012-10").exists()
        assert not Line.objects.filter(city=self.city, code="9000-1").exists()
        # Nenhuma linha anterior foi desativada por causa da falha parcial.
        previous.refresh_from_db()
        assert previous.is_active is True

        run = CatalogImportRun.objects.get(city=self.city)
        assert run.status == CatalogImportRun.Status.PARTIAL
        assert run.errors == 1
        assert self.source.last_error_at is not None

    def test_dry_run_does_not_write(self):
        result = self.run_import(dry_run=True)

        assert result.lines_created == 1
        assert Line.objects.filter(city=self.city).count() == 0
        assert Stop.objects.filter(city=self.city).count() == 0
        assert Route.objects.filter(line__city=self.city).count() == 0
        assert LineSourceRef.objects.filter(line__city=self.city).count() == 0
        assert CatalogImportRun.objects.filter(city=self.city).count() == 0
        assert self.source.last_import_at is None

    def test_deactivates_lines_missing_from_feed(self):
        self.run_import(
            client=make_client(codes=("1012-10", "9000-1")),
            feed=make_feed(("1012-10", "9000-1")),
        )
        assert Line.objects.filter(city=self.city, code="9000-1").exists()

        result = self.run_import(feed=make_feed(("1012-10",)))

        assert result.lines_deactivated == 1
        assert Line.objects.get(city=self.city, code="1012-10").is_active is True
        assert Line.objects.get(city=self.city, code="9000-1").is_active is False

    def test_does_not_touch_other_cities(self):
        teresina = City.objects.get(slug="teresina")
        other = Line.objects.create(
            city=teresina,
            code="35",
            boarding_code="0301",
            name="Linha de Teresina",
        )

        self.run_import()

        other.refresh_from_db()
        assert other.city_id == teresina.id
        assert other.name == "Linha de Teresina"
        assert other.is_active is True
        assert not Line.objects.filter(city=teresina).exclude(id=other.id).exists()

    def test_internal_ids_stay_out_of_public_payload(self):
        self.run_import()

        line = Line.objects.get(city=self.city, code="1012-10")
        payload = line_payload(line)

        assert "1273" not in str(payload)
        assert "1274" not in str(payload)
        assert "cl" not in payload
        assert "externalId" not in payload
        assert "sourceRef" not in payload
        # O identificador interno continua disponível apenas para a importação.
        assert LineSourceRef.objects.filter(external_id="1273").exists()
