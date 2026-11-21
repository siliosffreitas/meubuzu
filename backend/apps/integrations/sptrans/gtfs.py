"""Leitor do GTFS da SPTrans.

O GTFS é usado por dois motivos:

1. `routes.txt` é a lista semente de códigos públicos de linha, porque a API
   Olho Vivo não oferece um endpoint para enumerar todas as linhas.
2. `shapes.txt` é a única fonte dos traçados geográficos, ausentes na API.

Paradas e itinerários **não** são importados do GTFS: o `stop_id` não
corresponde ao `cp` público da API.
"""

from __future__ import annotations

import csv
import logging
from collections import Counter
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from pathlib import Path

from .errors import GtfsError

logger = logging.getLogger(__name__)

BUS_ROUTE_TYPE = 3

ROUTES_FILE = "routes.txt"
TRIPS_FILE = "trips.txt"
SHAPES_FILE = "shapes.txt"

REQUIRED_FILES = (ROUTES_FILE, TRIPS_FILE, SHAPES_FILE)
REQUIRED_HEADERS = {
    ROUTES_FILE: {"route_id", "route_short_name", "route_long_name", "route_type"},
    TRIPS_FILE: {"route_id", "direction_id", "shape_id"},
    SHAPES_FILE: {"shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"},
}


@dataclass(frozen=True, slots=True)
class GtfsRoute:
    route_id: str
    short_name: str
    long_name: str
    route_type: int


@dataclass(slots=True)
class GtfsValidation:
    """Resultado da validação do diretório GTFS."""

    routes: int = 0
    bus_routes: int = 0
    trips: int = 0
    shapes: int = 0
    shape_points: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def is_valid(self) -> bool:
        return not self.errors


def _clean(value: object) -> str:
    return str(value).strip() if value is not None else ""


def _open_csv(path: Path) -> Iterator[dict[str, str]]:
    """Lê um CSV do GTFS tratando BOM e cabeçalhos com espaços."""

    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise GtfsError(f"{path.name} está vazio ou sem cabeçalho.")
        reader.fieldnames = [name.strip() for name in reader.fieldnames]
        for row in reader:
            yield {key.strip(): value for key, value in row.items() if key}


class GtfsFeed:
    """Acesso somente leitura aos arquivos GTFS de um diretório."""

    def __init__(self, directory: str | Path) -> None:
        self.directory = Path(directory)

    # -- Validação -----------------------------------------------------------

    def _require(self, name: str) -> Path:
        path = self.directory / name
        if not path.is_file():
            raise GtfsError(f"Arquivo GTFS ausente: {path}")
        return path

    def validate(self) -> GtfsValidation:
        result = GtfsValidation()
        if not self.directory.is_dir():
            result.errors.append(f"Diretório GTFS inexistente: {self.directory}")
            return result

        for name in REQUIRED_FILES:
            path = self.directory / name
            if not path.is_file():
                result.errors.append(f"Arquivo ausente: {name}")
                continue
            try:
                with path.open(encoding="utf-8-sig", newline="") as handle:
                    header = next(csv.reader(handle), None)
            except OSError as exc:
                result.errors.append(f"Não foi possível ler {name}: {exc}")
                continue
            if not header:
                result.errors.append(f"{name} sem cabeçalho.")
                continue
            missing = REQUIRED_HEADERS[name] - {column.strip() for column in header}
            if missing:
                result.errors.append(
                    f"{name} sem as colunas: {', '.join(sorted(missing))}"
                )

        if result.errors:
            return result

        try:
            routes = self.routes(only_bus=False)
            result.routes = len(routes)
            result.bus_routes = sum(
                1 for route in routes.values() if route.route_type == BUS_ROUTE_TYPE
            )
            shape_map = self.shape_map()
            result.trips = len(shape_map)
            result.shapes = len(set(shape_map.values()))

            needed = set(shape_map.values())
            for _shape_id, points in self.iter_shapes(needed):
                result.shape_points += len(points)
        except GtfsError as exc:
            result.errors.append(str(exc))

        return result

    # -- Rotas ---------------------------------------------------------------

    def routes(self, *, only_bus: bool = True) -> dict[str, GtfsRoute]:
        """Rotas indexadas por `route_id`.

        Por padrão devolve apenas ônibus (`route_type=3`), que é o escopo do
        MeuBuzu.
        """

        path = self._require(ROUTES_FILE)
        routes: dict[str, GtfsRoute] = {}
        for row in _open_csv(path):
            route_id = _clean(row.get("route_id"))
            if not route_id:
                continue
            try:
                route_type = int(_clean(row.get("route_type")) or BUS_ROUTE_TYPE)
            except ValueError:
                route_type = BUS_ROUTE_TYPE
            if only_bus and route_type != BUS_ROUTE_TYPE:
                continue
            routes[route_id] = GtfsRoute(
                route_id=route_id,
                short_name=_clean(row.get("route_short_name")) or route_id,
                long_name=_clean(row.get("route_long_name")),
                route_type=route_type,
            )
        return routes

    def line_codes(self) -> set[str]:
        """Códigos públicos de linha usados como semente da importação."""

        return {route.short_name for route in self.routes().values()}

    # -- Viagens e shapes ----------------------------------------------------

    def shape_map(self) -> dict[tuple[str, int], str]:
        """Mapeia `(route_id, direction_id)` para `shape_id`.

        Quando a mesma combinação aparece em várias viagens, usa o shape mais
        frequente. O GTFS atual tem exatamente um shape por combinação.
        """

        path = self._require(TRIPS_FILE)
        counter: Counter[tuple[str, int, str]] = Counter()
        for row in _open_csv(path):
            route_id = _clean(row.get("route_id"))
            shape_id = _clean(row.get("shape_id"))
            if not route_id or not shape_id:
                continue
            try:
                direction = int(_clean(row.get("direction_id")) or 0)
            except ValueError:
                direction = 0
            counter[(route_id, direction, shape_id)] += 1

        chosen: dict[tuple[str, int], tuple[str, int]] = {}
        for (route_id, direction, shape_id), count in counter.items():
            key = (route_id, direction)
            current = chosen.get(key)
            if current is None or count > current[1]:
                chosen[key] = (shape_id, count)
        return {key: value[0] for key, value in chosen.items()}

    def iter_shapes(
        self, shape_ids: Iterable[str]
    ) -> Iterator[tuple[str, list[tuple[float, float]]]]:
        """Lê `shapes.txt` em streaming, devolvendo apenas os shapes pedidos.

        Os pontos são ordenados por `shape_pt_sequence` e convertidos para
        `(latitude, longitude)`, o mesmo formato do contrato público.
        """

        needed = {shape_id for shape_id in shape_ids if shape_id}
        if not needed:
            return

        path = self._require(SHAPES_FILE)
        collected: dict[str, list[tuple[int, float, float]]] = {}
        skipped = 0

        for row in _open_csv(path):
            shape_id = _clean(row.get("shape_id"))
            if shape_id not in needed:
                continue
            try:
                sequence = int(_clean(row.get("shape_pt_sequence")) or 0)
                latitude = float(_clean(row.get("shape_pt_lat")))
                longitude = float(_clean(row.get("shape_pt_lon")))
            except (TypeError, ValueError):
                skipped += 1
                continue
            if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
                skipped += 1
                continue
            collected.setdefault(shape_id, []).append((sequence, latitude, longitude))

        if skipped:
            logger.warning("Pontos de shape inválidos ignorados: %d", skipped)

        for shape_id in needed:
            points = collected.get(shape_id)
            if not points:
                continue
            points.sort(key=lambda item: item[0])
            yield shape_id, [(latitude, longitude) for _, latitude, longitude in points]

    def shapes(self, shape_ids: Iterable[str]) -> dict[str, list[tuple[float, float]]]:
        """Versão materializada de `iter_shapes`."""

        return dict(self.iter_shapes(shape_ids))


def as_decimal(value: float) -> Decimal:
    """Converte coordenada para `Decimal` com a precisão do modelo."""

    try:
        return Decimal(str(value)).quantize(Decimal("0.000001"))
    except InvalidOperation as exc:  # pragma: no cover - valor já validado
        raise GtfsError(f"Coordenada inválida: {value}") from exc
