"""Crawler de posições da API Olho Vivo.

O crawl:

1. autentica na SPTrans e lê `/Posicao` uma vez;
2. resolve cada linha pelo `boardingCode` público, dentro da cidade;
3. atualiza `LatestPosition` apenas quando a captura é mais nova;
4. grava `PositionHistory` em lote, tolerando falha do histórico;
5. nunca apaga posições quando a fonte falha.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from django.conf import settings
from django.utils import timezone

from apps.catalog.models import City, Line
from apps.integrations.sptrans.client import SPTransClient, VehiclePositionRecord

from .geo import heading_between
from .models import LatestPosition, PositionHistory, TrackingSource

logger = logging.getLogger(__name__)

HISTORY_BATCH_SIZE = 5_000


@dataclass
class CrawlResult:
    city: str = ""
    positions: int = 0
    updated: int = 0
    ignored: int = 0
    history_rows: int = 0
    unresolved_lines: int = 0
    errors: int = 0
    duration_seconds: float = 0.0
    messages: list[str] = field(default_factory=list)

    def as_dict(self) -> dict:
        return {
            "city": self.city,
            "positions": self.positions,
            "updated": self.updated,
            "ignored": self.ignored,
            "history_rows": self.history_rows,
            "unresolved_lines": self.unresolved_lines,
            "errors": self.errors,
            "duration_seconds": round(self.duration_seconds, 3),
        }


def _decimal(value: float) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.000001"))


def _history_enabled() -> bool:
    return bool(getattr(settings, "TRACKING_HISTORY_ENABLED", True))


def _max_capture_age() -> int:
    return int(getattr(settings, "TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS", 600))


def _select_newest(
    records: list[VehiclePositionRecord],
) -> dict[str, VehiclePositionRecord]:
    newest: dict[str, VehiclePositionRecord] = {}
    for record in records:
        current = newest.get(record.vehicle_code)
        if current is None or record.captured_at > current.captured_at:
            newest[record.vehicle_code] = record
    return newest


def crawl_positions(
    *,
    city: City,
    source: TrackingSource,
    client: SPTransClient,
    now: datetime | None = None,
    write_history: bool | None = None,
) -> CrawlResult:
    """Executa um ciclo de ingestão para a cidade."""

    started = time.monotonic()
    moment = now or datetime.now(UTC)
    result = CrawlResult(city=city.slug)

    client.authenticate()
    records = client.positions()
    result.positions = len(records)

    lines = {
        line.boarding_code: line
        for line in Line.objects.filter(city=city, is_active=True).only(
            "id", "boarding_code", "city_id"
        )
    }

    newest = _select_newest(records)
    existing = {
        position.vehicle_code: position
        for position in LatestPosition.objects.filter(city=city)
    }

    should_write_history = (
        _history_enabled() if write_history is None else write_history
    )
    cutoff = moment - timedelta(seconds=_max_capture_age())

    to_write: list[LatestPosition] = []
    history_rows: list[PositionHistory] = []
    unresolved: set[str] = set()

    for vehicle_code, record in newest.items():
        line = lines.get(record.line_code)
        if line is None:
            unresolved.add(record.line_code)
            continue

        previous = existing.get(vehicle_code)
        if previous is not None and record.captured_at <= previous.captured_at:
            result.ignored += 1
            continue

        heading = None
        previous_latitude = None
        previous_longitude = None
        if previous is not None:
            previous_latitude = previous.latitude
            previous_longitude = previous.longitude
            heading = heading_between(
                float(previous.latitude),
                float(previous.longitude),
                record.latitude,
                record.longitude,
            )

        to_write.append(
            LatestPosition(
                city=city,
                line=line,
                source=source,
                vehicle_code=vehicle_code,
                latitude=_decimal(record.latitude),
                longitude=_decimal(record.longitude),
                previous_latitude=previous_latitude,
                previous_longitude=previous_longitude,
                heading=heading,
                direction=record.direction,
                is_accessible=record.is_accessible,
                data_mode="live",
                captured_at=record.captured_at,
                received_at=moment,
                created_at=moment,
                updated_at=moment,
            )
        )

        if should_write_history and record.captured_at >= cutoff:
            history_rows.append(
                PositionHistory(
                    city_id=city.id,
                    line_id=line.id,
                    source_id=source.id,
                    vehicle_code=vehicle_code,
                    latitude=_decimal(record.latitude),
                    longitude=_decimal(record.longitude),
                    direction=record.direction,
                    is_accessible=record.is_accessible,
                    data_mode="live",
                    captured_at=record.captured_at,
                    received_at=moment,
                )
            )

    result.unresolved_lines = len(unresolved)

    if to_write:
        LatestPosition.objects.bulk_create(
            to_write,
            update_conflicts=True,
            unique_fields=["city", "vehicle_code"],
            update_fields=[
                "line",
                "source",
                "latitude",
                "longitude",
                "previous_latitude",
                "previous_longitude",
                "heading",
                "direction",
                "is_accessible",
                "data_mode",
                "captured_at",
                "received_at",
                "updated_at",
            ],
        )
        result.updated = len(to_write)

    if history_rows:
        result.history_rows = _write_history(history_rows, moment, result)

    result.duration_seconds = time.monotonic() - started
    return result


def _write_history(
    rows: list[PositionHistory],
    moment: datetime,
    result: CrawlResult,
) -> int:
    from .partitions import ensure_partitions

    try:
        ensure_partitions(days_ahead=2, now=moment)
    except Exception:  # noqa: BLE001 - histórico nunca derruba o crawl
        logger.exception("Falha ao garantir partições; histórico será ignorado.")
        result.errors += 1
        return 0

    written = 0
    for index in range(0, len(rows), HISTORY_BATCH_SIZE):
        batch = rows[index : index + HISTORY_BATCH_SIZE]
        try:
            PositionHistory.objects.bulk_create(batch, ignore_conflicts=True)
        except Exception:  # noqa: BLE001 - histórico não derruba o crawl
            logger.exception("Falha ao gravar o histórico de posições.")
            result.errors += 1
            break
        written += len(batch)
    return written


def record_source_success(source: TrackingSource) -> None:
    source.last_success_at = timezone.now()
    source.last_error_at = None
    source.last_error_message = ""
    source.save(
        update_fields=[
            "last_success_at",
            "last_error_at",
            "last_error_message",
            "updated_at",
        ]
    )


def record_source_error(source: TrackingSource, error: Exception) -> None:
    source.last_error_at = timezone.now()
    source.last_error_message = str(error)[:2000]
    source.save(update_fields=["last_error_at", "last_error_message", "updated_at"])
