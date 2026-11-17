"""Importa linhas, paradas por linha e traçados dos assets legados.

Os arquivos ficam em `app/assets` e são usados apenas em staging/demonstração
(D2 do PRD). A importação é idempotente por (cidade, código) e invalida o cache
Redis da cidade ao final.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.catalog.models import (
    CatalogSource,
    City,
    Line,
    LineStop,
    Route,
    Stop,
)
from apps.catalog.services import invalidate_catalog_cache
from apps.catalog.text import normalize_search_text

ASSETS_DIR = Path(settings.BASE_DIR).parent / "app" / "assets"
DEFAULT_LINES_CSV = ASSETS_DIR / "lines.csv"
DEFAULT_LINE_STOPS_JSON = ASSETS_DIR / "lines_paradas.json"
DEFAULT_ROUTES_DIR = ASSETS_DIR / "routes"
REQUIRED_COLUMNS = {
    "codigoLinha",
    "nomeLinha",
    "getOrigemIda",
    "destinoIda",
    "sgLinha",
}


class Command(BaseCommand):
    help = "Importa linhas, itinerários e traçados dos assets para o catálogo da cidade."

    def add_arguments(self, parser):
        parser.add_argument("--city", default="teresina", help="slug da cidade")
        parser.add_argument(
            "--lines-path",
            type=Path,
            default=DEFAULT_LINES_CSV,
            help="caminho do CSV de linhas",
        )
        parser.add_argument(
            "--line-stops-path",
            type=Path,
            default=DEFAULT_LINE_STOPS_JSON,
            help="caminho do JSON de paradas por linha",
        )
        parser.add_argument(
            "--routes-dir",
            type=Path,
            default=DEFAULT_ROUTES_DIR,
            help="diretório dos CSVs de traçado",
        )
        parser.add_argument(
            "--source-slug",
            default="csv-linhas",
            help="slug da fonte registrada no catálogo",
        )
        parser.add_argument(
            "--data-mode",
            choices=[CatalogSource.DataMode.DEMO, CatalogSource.DataMode.LIVE],
            default=CatalogSource.DataMode.DEMO,
            help="demo (staging) ou live (produção)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="valida os arquivos sem gravar no banco",
        )

    def handle(self, *args, **options):
        city_slug: str = options["city"]
        dry_run: bool = options["dry_run"]
        lines_path: Path = options["lines_path"]
        line_stops_path: Path = options["line_stops_path"]
        routes_dir: Path = options["routes_dir"]

        city = City.objects.filter(slug=city_slug).first()
        if city is None:
            raise CommandError(f"Cidade '{city_slug}' não encontrada. Rode as migrations.")

        for path in (lines_path, line_stops_path):
            if not path.is_file():
                raise CommandError(f"Arquivo não encontrado: {path}")
        if not routes_dir.is_dir():
            raise CommandError(f"Diretório não encontrado: {routes_dir}")

        source = None
        if not dry_run:
            source, _ = CatalogSource.objects.get_or_create(
                city=city,
                slug=options["source_slug"],
                defaults={
                    "name": f"CSV de linhas ({city.name})",
                    "data_mode": options["data_mode"],
                },
            )

        lines = self._read_lines(lines_path)
        line_stops = self._read_line_stops(line_stops_path)
        stats = {"lines": 0, "line_stops": 0, "routes": 0, "skipped": 0}

        with transaction.atomic():
            by_code: dict[str, Line] = {}
            by_boarding_code: dict[str, Line] = {}

            for row in lines:
                code = row["code"]
                values = {
                    "source": source,
                    "boarding_code": row["boarding_code"],
                    "name": row["name"],
                    "origin": row["origin"],
                    "destination": row["destination"],
                    "search_text": normalize_search_text(
                        " ".join(
                            (
                                code,
                                row["boarding_code"],
                                row["name"],
                                row["origin"],
                                row["destination"],
                            )
                        )
                    )[:400],
                    "origin_type": Line.OriginType.IMPORTED,
                    "is_active": True,
                }

                if dry_run:
                    stats["lines"] += 1
                    continue

                line, _ = Line.objects.update_or_create(
                    city=city,
                    code=code,
                    defaults=values,
                )
                by_code[code] = line
                if row["boarding_code"]:
                    by_boarding_code[row["boarding_code"]] = line
                stats["lines"] += 1

            if not dry_run:
                self._import_line_stops(
                    city, line_stops, by_code, by_boarding_code, stats
                )
                self._import_routes(city, routes_dir, by_code, by_boarding_code, stats)

            if dry_run:
                known = {row["code"] for row in lines}
                known.update(
                    row["boarding_code"] for row in lines if row["boarding_code"]
                )
                stats["line_stops"] = sum(
                    len(stop_codes)
                    for identifier, stop_codes in line_stops.items()
                    if identifier in known
                )
                stats["routes"] = sum(
                    1
                    for route_path in routes_dir.glob("*.csv")
                    if route_path.stem in known
                )
                transaction.set_rollback(True)

        if not dry_run:
            invalidate_catalog_cache(city.slug)

        self.stdout.write(
            self.style.SUCCESS(
                f"Catálogo de {city.label}: "
                f"{stats['lines']} linhas, {stats['line_stops']} paradas de linha, "
                f"{stats['routes']} traçados, {stats['skipped']} ignorados."
                + (" (dry-run)" if dry_run else "")
            )
        )

    def _read_lines(self, path: Path) -> list[dict[str, str]]:
        with path.open(newline="", encoding="utf-8-sig") as csv_file:
            reader = csv.DictReader(csv_file)
            missing = REQUIRED_COLUMNS.difference(reader.fieldnames or [])
            if missing:
                raise CommandError(
                    "CSV sem as colunas obrigatórias: " + ", ".join(sorted(missing))
                )

            rows = []
            for line_number, row in enumerate(reader, start=2):
                code = (row.get("codigoLinha") or "").strip()
                name = (row.get("nomeLinha") or "").strip()
                if not code or not name:
                    self.stderr.write(f"Linha {line_number}: código ou nome vazio; ignorada.")
                    continue
                rows.append(
                    {
                        "code": code,
                        "boarding_code": (row.get("sgLinha") or "").strip(),
                        "name": name,
                        "origin": (row.get("getOrigemIda") or "").strip(),
                        "destination": (row.get("destinoIda") or "").strip(),
                    }
                )
        return rows

    def _read_line_stops(self, path: Path) -> dict[str, list[str]]:
        with path.open(encoding="utf-8-sig") as json_file:
            decoded = json.load(json_file)
        if not isinstance(decoded, dict):
            raise CommandError(f"JSON inválido em {path}: esperado objeto no raiz.")

        result: dict[str, list[str]] = {}
        for key, value in decoded.items():
            if not isinstance(value, str):
                continue
            stop_codes: list[str] = []
            seen: set[str] = set()
            for stop_code in value.split(","):
                normalized = stop_code.strip()
                if normalized and normalized not in seen:
                    seen.add(normalized)
                    stop_codes.append(normalized)
            result[key.strip()] = stop_codes
        return result

    def _resolve_line(
        self,
        identifier: str,
        by_code: dict[str, Line],
        by_boarding_code: dict[str, Line],
    ) -> Line | None:
        return by_boarding_code.get(identifier) or by_code.get(identifier)

    def _import_line_stops(
        self,
        city: City,
        line_stops: dict[str, list[str]],
        by_code: dict[str, Line],
        by_boarding_code: dict[str, Line],
        stats: dict[str, int],
    ) -> None:
        stops_by_code = {stop.code: stop for stop in Stop.objects.filter(city=city)}
        line_ids = set()

        for identifier, stop_codes in line_stops.items():
            line = self._resolve_line(identifier, by_code, by_boarding_code)
            if line is None:
                stats["skipped"] += 1
                self.stderr.write(f"Linha '{identifier}' sem cadastro; itinerário ignorado.")
                continue

            relations = []
            for sequence, stop_code in enumerate(stop_codes, start=1):
                stop = stops_by_code.get(stop_code)
                if stop is None:
                    stats["skipped"] += 1
                    continue
                relations.append(
                    LineStop(
                        line=line,
                        stop=stop,
                        direction=0,
                        sequence=sequence,
                    )
                )

            LineStop.objects.filter(line=line, direction=0).delete()
            LineStop.objects.bulk_create(relations)
            line_ids.add(line.id)
            stats["line_stops"] += len(relations)

    def _import_routes(
        self,
        city: City,
        routes_dir: Path,
        by_code: dict[str, Line],
        by_boarding_code: dict[str, Line],
        stats: dict[str, int],
    ) -> None:
        for route_path in sorted(routes_dir.glob("*.csv")):
            line = self._resolve_line(route_path.stem, by_code, by_boarding_code)
            if line is None:
                stats["skipped"] += 1
                self.stderr.write(
                    f"Traçado '{route_path.stem}' sem linha cadastrada; ignorado."
                )
                continue

            coordinates = []
            with route_path.open(newline="", encoding="utf-8-sig") as csv_file:
                for row_number, row in enumerate(csv.reader(csv_file), start=1):
                    if len(row) < 2:
                        continue
                    try:
                        latitude = float(row[0].strip())
                        longitude = float(row[1].strip())
                    except ValueError:
                        stats["skipped"] += 1
                        self.stderr.write(
                            f"{route_path.name}:{row_number}: coordenada inválida; ignorada."
                        )
                        continue
                    coordinates.append([latitude, longitude])

            if not coordinates:
                stats["skipped"] += 1
                continue

            Route.objects.update_or_create(
                line=line,
                direction=0,
                defaults={"path": coordinates},
            )
            stats["routes"] += 1
