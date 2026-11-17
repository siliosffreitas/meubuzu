"""Fontes de posições do rastreamento.

Nesta fase apenas a fonte CSV de demonstração existe. A interface mantém o
mesmo formato que um futuro adaptador da API de Teresina deve devolver, para
que o contrato da API não mude quando o crawler volátil entrar em operação.
"""

from __future__ import annotations

import csv
import logging
import re
from dataclasses import dataclass
from datetime import UTC, datetime, time
from functools import lru_cache
from pathlib import Path
from typing import Protocol

from django.conf import settings

logger = logging.getLogger(__name__)

# Colunas dos arquivos históricos, sem cabeçalho:
# label, codigoLinha, código do ônibus, generatedAt, latitude, longitude, capturedAt
_TIME_PATTERN = re.compile(r"T(\d{2}):(\d{2}):(\d{2})")

CSV_SOURCE = "csv_demo"

FILES_BY_WEEKDAY = {
    0: "positions_2023_06_05.csv",  # segunda
    1: "positions_2023_06_06.csv",  # terça
    2: "positions_2023_06_07.csv",  # quarta
    3: "positions_2023_06_01.csv",  # quinta
    4: "positions_2023_06_02.csv",  # sexta
    5: "positions_2023_06_03.csv",  # sábado
    6: "positions_2023_06_04.csv",  # domingo
}


class PositionSourceUnavailable(Exception):
    """A fonte configurada não conseguiu fornecer posições."""


@dataclass(frozen=True, slots=True)
class VehiclePositionDTO:
    """Posição bruta normalizada, antes da janela e do deslocamento de datas."""

    line_code: str
    vehicle_code: str
    latitude: float
    longitude: float
    captured_at: datetime
    captured_clock: time
    generated_at: datetime | None


class PositionSource(Protocol):
    def fetch(
        self,
        *,
        line_codes: set[str],
        now: datetime,
    ) -> list[VehiclePositionDTO]: ...


def normalize_line_code(value: str) -> str:
    """Normaliza apenas o `codigoLinha` dos CSVs, que não tem zeros à esquerda.

    O `sgLinha` usado na API é preservado exatamente; esta função não deve ser
    aplicada ao parâmetro público `codes`.
    """

    stripped = (value or "").strip()
    return stripped.lstrip("0") or "0"


def _parse_timestamp(raw: str) -> datetime | None:
    value = raw.strip()
    if not value:
        return None
    if value.endswith("Z"):
        value = f"{value[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _clock_from_raw(raw: str) -> time | None:
    """Lê a hora literal do CSV, sem aplicar o offset do timestamp."""

    match = _TIME_PATTERN.search(raw)
    if match is None:
        return None
    try:
        return time(int(match.group(1)), int(match.group(2)), int(match.group(3)))
    except ValueError:
        return None


@lru_cache(maxsize=1)
def _load_index(path: str, mtime_ns: int) -> dict[str, tuple[VehiclePositionDTO, ...]]:
    """Indexa um arquivo por linha, guardando apenas o último arquivo lido."""

    by_line: dict[str, list[VehiclePositionDTO]] = {}
    skipped = 0

    with open(path, encoding="utf-8-sig", newline="") as handle:
        for row in csv.reader(handle):
            if len(row) < 7 or all(not value.strip() for value in row):
                continue

            line_code = normalize_line_code(row[1])
            vehicle_code = row[2].strip()
            captured_raw = row[6].strip()
            clock = _clock_from_raw(captured_raw)
            captured_at = _parse_timestamp(captured_raw)

            try:
                latitude = float(row[4])
                longitude = float(row[5])
            except (TypeError, ValueError):
                skipped += 1
                continue

            if (
                not line_code
                or not vehicle_code
                or clock is None
                or captured_at is None
                or not -90 <= latitude <= 90
                or not -180 <= longitude <= 180
            ):
                skipped += 1
                continue

            generated_at = _parse_timestamp(row[3])
            by_line.setdefault(line_code, []).append(
                VehiclePositionDTO(
                    line_code=line_code,
                    vehicle_code=vehicle_code,
                    latitude=latitude,
                    longitude=longitude,
                    captured_at=captured_at,
                    captured_clock=clock,
                    generated_at=generated_at,
                )
            )

    if skipped:
        logger.warning("Posições ignoradas ao ler %s: %d linhas inválidas.", path, skipped)

    return {code: tuple(rows) for code, rows in by_line.items()}


class CsvDemoPositionSource:
    """Replay dos CSVs históricos, escolhidos pelo dia da semana da cidade."""

    def __init__(self, csv_dir: Path | None = None) -> None:
        self.csv_dir = Path(csv_dir or settings.TRACKING_CSV_DIR)

    def fetch(self, *, line_codes: set[str], now: datetime) -> list[VehiclePositionDTO]:
        file_name = FILES_BY_WEEKDAY.get(now.weekday())
        if file_name is None:
            return []

        path = self.csv_dir / file_name
        if not path.is_file():
            raise PositionSourceUnavailable(f"Arquivo de posições indisponível: {file_name}")

        index = _load_index(str(path), path.stat().st_mtime_ns)
        positions = [row for code in line_codes for row in index.get(code, ())]
        return positions
