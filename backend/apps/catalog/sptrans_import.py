"""Importação do catálogo de São Paulo (API Olho Vivo + GTFS).

Regras:

- a API é a fonte de linhas, paradas e itinerários;
- o GTFS fornece os traçados (`shapes.txt`) e a lista semente de linhas;
- os dois sentidos da API viram um único `Line`, com `direction` 0/1;
- os `cl` internos ficam em `LineSourceRef` e nunca vão para a API pública;
- falha parcial preserva o catálogo anterior e é registrada em
  `CatalogImportRun`.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from django.db import transaction
from django.utils import timezone

from apps.integrations.sptrans.client import LineRecord, SPTransClient, StopRecord
from apps.integrations.sptrans.errors import GtfsError, SPTransError
from apps.integrations.sptrans.gtfs import GtfsFeed, GtfsRoute, as_decimal

from .models import (
    CatalogImportRun,
    CatalogSource,
    City,
    Line,
    LineSourceRef,
    LineStop,
    Route,
    Stop,
)
from .services import invalidate_catalog_cache
from .text import normalize_search_text

logger = logging.getLogger(__name__)

SHAPE_BATCH_SIZE = 250


@dataclass
class ImportResult:
    lines_created: int = 0
    lines_updated: int = 0
    lines_deactivated: int = 0
    stops_created: int = 0
    stops_updated: int = 0
    routes_updated: int = 0
    errors: int = 0
    messages: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, int]:
        return {
            "lines_created": self.lines_created,
            "lines_updated": self.lines_updated,
            "lines_deactivated": self.lines_deactivated,
            "stops_created": self.stops_created,
            "stops_updated": self.stops_updated,
            "routes_updated": self.routes_updated,
            "errors": self.errors,
        }


def _chunks(items: list, size: int):
    for index in range(0, len(items), size):
        yield items[index : index + size]


def _line_labels(
    route: GtfsRoute | None, records: list[LineRecord], code: str
) -> tuple[str, str, str]:
    """Nome, origem e destino da linha, priorizando o GTFS."""

    if route is not None and route.long_name:
        parts = [part.strip() for part in route.long_name.split(" - ", 1)]
        if len(parts) == 2 and parts[0] and parts[1]:
            return route.long_name, parts[0], parts[1]
        return route.long_name, "", ""

    for record in records:
        if record.origin_label and record.destination_label:
            return (
                f"{record.origin_label} - {record.destination_label}",
                record.origin_label,
                record.destination_label,
            )
    return code, "", ""


def _distance_squared(point: tuple[float, float], stop: Stop) -> float:
    latitude = float(stop.latitude)
    longitude = float(stop.longitude)
    return (point[0] - latitude) ** 2 + (point[1] - longitude) ** 2


class CatalogImporter:
    """Executa a importação de catálogo de uma cidade."""

    def __init__(
        self,
        *,
        city: City,
        source: CatalogSource,
        client: SPTransClient,
        feed: GtfsFeed | None,
        dry_run: bool = False,
        limit: int | None = None,
        only_lines: set[str] | None = None,
        skip_shapes: bool = False,
        shapes_only: bool = False,
    ) -> None:
        self.city = city
        self.source = source
        self.client = client
        self.feed = feed
        self.dry_run = dry_run
        self.limit = limit
        self.only_lines = only_lines
        self.skip_shapes = skip_shapes
        self.shapes_only = shapes_only
        self.result = ImportResult()

    # -- Orquestração --------------------------------------------------------

    def run(self) -> ImportResult:
        self.client.authenticate()
        routes = self._gtfs_routes()

        imported_codes: set[str] | None = None
        if not self.shapes_only:
            imported_codes = self._import_lines(routes)

        if not self.skip_shapes and self.feed is not None:
            self._import_shapes()

        if (
            imported_codes is not None
            and not self.dry_run
            and self.limit is None
            and self.only_lines is None
            and self.result.errors == 0
        ):
            self._deactivate_missing(imported_codes)

        if not self.dry_run:
            invalidate_catalog_cache(self.city.slug)
        return self.result

    def _gtfs_routes(self) -> dict[str, GtfsRoute]:
        if self.feed is None:
            return {}
        try:
            return self.feed.routes()
        except GtfsError as exc:
            self.result.errors += 1
            self.result.messages.append(str(exc))
            logger.warning("GTFS inválido ao ler rotas: %s", exc)
            return {}

    def _target_codes(self, routes: dict[str, GtfsRoute]) -> list[str]:
        if self.only_lines:
            return sorted(self.only_lines)
        codes = set(routes) or self.client.discover_line_codes()
        ordered = sorted(codes)
        if self.limit is not None:
            ordered = ordered[: self.limit]
        return ordered

    # -- Linhas, paradas e itinerários ---------------------------------------

    def _import_lines(self, routes: dict[str, GtfsRoute]) -> set[str]:
        codes = self._target_codes(routes)
        imported: set[str] = set()

        for code in codes:
            try:
                records = [
                    record
                    for record in self.client.search_lines(code)
                    if record.public_code == code
                ]
            except SPTransError as exc:
                self.result.errors += 1
                self.result.messages.append(f"{code}: {exc}")
                continue

            if not records:
                self.result.errors += 1
                self.result.messages.append(f"{code}: linha não encontrada na API.")
                continue

            try:
                self._upsert_line(code, records, routes.get(code))
                imported.add(code)
            except Exception as exc:  # noqa: BLE001 - erro isolado por linha
                self.result.errors += 1
                self.result.messages.append(f"{code}: {exc}")
                logger.exception("Falha ao importar a linha %s", code)

        return imported

    def _upsert_line(
        self, code: str, records: list[LineRecord], route: GtfsRoute | None
    ) -> None:
        name, origin, destination = _line_labels(route, records, code)
        search_text = normalize_search_text(
            " ".join(part for part in (code, name, origin, destination) if part)
        )

        line = Line.objects.filter(city=self.city, code=code).first()
        created = line is None
        if line is None:
            if self.dry_run:
                self.result.lines_created += 1
                return
            line = Line(city=self.city, code=code, boarding_code=code)
        elif self.dry_run:
            self.result.lines_updated += 1
            return

        line.source = self.source
        line.boarding_code = code
        line.name = name[:200]
        line.origin = origin
        line.destination = destination
        line.search_text = search_text[:400]
        line.is_active = True
        line.source_updated_at = timezone.now()
        if created:
            self.result.lines_created += 1
        else:
            self.result.lines_updated += 1
        line.save()

        for record in records:
            LineSourceRef.objects.update_or_create(
                source=self.source,
                external_id=record.external_id,
                defaults={"line": line, "direction": record.direction},
            )
            self._import_line_stops(line, record)

    def _import_line_stops(self, line: Line, record: LineRecord) -> None:
        stops = self.client.stops_for_line(record.external_id)
        if not stops:
            self.result.messages.append(
                f"{line.boarding_code}: sentido {record.direction} sem paradas."
            )
            return
        if self.dry_run:
            return

        with transaction.atomic():
            stop_models = self._upsert_stops(stops)
            LineStop.objects.filter(line=line, direction=record.direction).delete()
            LineStop.objects.bulk_create(
                [
                    LineStop(
                        line=line,
                        stop=stop_models[stop.code],
                        direction=record.direction,
                        sequence=index,
                    )
                    for index, stop in enumerate(stops, start=1)
                    if stop.code in stop_models
                ]
            )

    def _upsert_stops(self, stops: list[StopRecord]) -> dict[str, Stop]:
        codes = {stop.code for stop in stops}
        existing = set(
            Stop.objects.filter(city=self.city, code__in=codes).values_list(
                "code", flat=True
            )
        )
        now = timezone.now()

        objects = [
            Stop(
                city=self.city,
                source=self.source,
                external_id=stop.code,
                code=stop.code,
                name=stop.name,
                address=stop.address,
                latitude=as_decimal(stop.latitude),
                longitude=as_decimal(stop.longitude),
                search_text=normalize_search_text(
                    " ".join(part for part in (stop.code, stop.name, stop.address) if part)
                )[:255],
                created_at=now,
                updated_at=now,
            )
            for stop in stops
        ]
        Stop.objects.bulk_create(
            objects,
            update_conflicts=True,
            unique_fields=["city", "code"],
            update_fields=[
                "source",
                "external_id",
                "name",
                "address",
                "latitude",
                "longitude",
                "search_text",
                "is_active",
            ],
        )

        self.result.stops_created += len(codes - existing)
        self.result.stops_updated += len(codes & existing)

        return {
            stop.code: stop
            for stop in Stop.objects.filter(city=self.city, code__in=codes)
        }

    # -- Traçados ------------------------------------------------------------

    def _import_shapes(self) -> None:
        assert self.feed is not None
        try:
            shape_map = self.feed.shape_map()
        except GtfsError as exc:
            self.result.errors += 1
            self.result.messages.append(str(exc))
            return

        lines = {
            line.code: line for line in Line.objects.filter(city=self.city)
        }
        targets = [
            (route_id, direction, shape_id)
            for (route_id, direction), shape_id in sorted(shape_map.items())
            if route_id in lines
        ]
        if self.only_lines:
            targets = [item for item in targets if item[0] in self.only_lines]

        for chunk in _chunks(targets, SHAPE_BATCH_SIZE):
            try:
                shapes = self.feed.shapes({shape_id for _, _, shape_id in chunk})
            except GtfsError as exc:
                self.result.errors += 1
                self.result.messages.append(str(exc))
                return

            for route_id, direction, shape_id in chunk:
                points = shapes.get(shape_id)
                if not points:
                    self.result.errors += 1
                    self.result.messages.append(f"{route_id}: shape {shape_id} vazio.")
                    continue
                line = lines[route_id]
                points = self._orient_shape(line, direction, points)
                if self.dry_run:
                    self.result.routes_updated += 1
                    continue
                Route.objects.update_or_create(
                    line=line,
                    direction=direction,
                    defaults={"path": [[round(lat, 6), round(lon, 6)] for lat, lon in points]},
                )
                self.result.routes_updated += 1

    def _orient_shape(
        self, line: Line, direction: int, points: list[tuple[float, float]]
    ) -> list[tuple[float, float]]:
        """Inverte o shape quando ele termina mais perto da primeira parada."""

        first_stop = (
            LineStop.objects.filter(line=line, direction=direction)
            .select_related("stop")
            .order_by("sequence")
            .first()
        )
        if first_stop is None:
            return points
        start_distance = _distance_squared(points[0], first_stop.stop)
        end_distance = _distance_squared(points[-1], first_stop.stop)
        return list(reversed(points)) if end_distance < start_distance else points

    # -- Desativação ---------------------------------------------------------

    def _deactivate_missing(self, imported_codes: set[str]) -> None:
        stale = Line.objects.filter(city=self.city, is_active=True).exclude(
            code__in=imported_codes
        )
        self.result.lines_deactivated = stale.update(is_active=False)


def import_catalog(
    *,
    city: City,
    source: CatalogSource,
    client: SPTransClient,
    feed: GtfsFeed | None,
    trigger: str = CatalogImportRun.Trigger.MANUAL,
    dry_run: bool = False,
    limit: int | None = None,
    only_lines: set[str] | None = None,
    skip_shapes: bool = False,
    shapes_only: bool = False,
) -> ImportResult:
    """Executa a importação e registra a execução em `CatalogImportRun`."""

    run: CatalogImportRun | None = None
    if not dry_run:
        run = CatalogImportRun.objects.create(
            city=city,
            source=source,
            trigger=trigger,
            status=CatalogImportRun.Status.RUNNING,
        )

    importer = CatalogImporter(
        city=city,
        source=source,
        client=client,
        feed=feed,
        dry_run=dry_run,
        limit=limit,
        only_lines=only_lines,
        skip_shapes=skip_shapes,
        shapes_only=shapes_only,
    )

    try:
        result = importer.run()
    except Exception as exc:  # noqa: BLE001 - registra e propaga
        if run is not None:
            run.status = CatalogImportRun.Status.FAILED
            run.finished_at = timezone.now()
            run.message = str(exc)[:2000]
            run.save(update_fields=["status", "finished_at", "message"])
        source.last_error_at = timezone.now()
        source.last_error_message = str(exc)[:2000]
        source.save(update_fields=["last_error_at", "last_error_message", "updated_at"])
        raise

    if run is not None:
        run.status = (
            CatalogImportRun.Status.SUCCESS
            if result.errors == 0
            else CatalogImportRun.Status.PARTIAL
        )
        run.finished_at = timezone.now()
        run.message = "\n".join(result.messages[:50])[:4000]
        for field_name, value in result.as_dict().items():
            setattr(run, field_name, value)
        run.save()

        source.last_import_at = timezone.now()
        source.last_error_at = None if result.errors == 0 else timezone.now()
        source.last_error_message = "" if result.errors == 0 else run.message
        source.save(
            update_fields=[
                "last_import_at",
                "last_error_at",
                "last_error_message",
                "updated_at",
            ]
        )

    return result
