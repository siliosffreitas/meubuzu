"""Importa as paradas do CSV legado para o catálogo de uma cidade.

O CSV fica em `app/assets/paradas.csv` e é usado apenas em staging/demonstração.
A importação é idempotente por (cidade, código) e invalida o cache Redis da
cidade ao final.
"""

from __future__ import annotations

import csv
from decimal import Decimal, InvalidOperation
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.catalog.models import CatalogSource, City, Stop
from apps.catalog.services import invalidate_catalog_cache
from apps.catalog.text import normalize_search_text

DEFAULT_CSV_PATH = Path(settings.BASE_DIR).parent / "app" / "assets" / "paradas.csv"
REQUIRED_COLUMNS = {"id", "codigo", "denominacao", "endereco", "lat", "long"}


class Command(BaseCommand):
    help = "Importa paradas de um CSV para o catálogo da cidade informada."

    def add_arguments(self, parser):
        parser.add_argument("--city", default="teresina", help="slug da cidade")
        parser.add_argument(
            "--path",
            type=Path,
            default=DEFAULT_CSV_PATH,
            help="caminho do CSV de paradas",
        )
        parser.add_argument(
            "--source-slug",
            default="csv-paradas",
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
            help="valida o arquivo sem gravar no banco",
        )

    def handle(self, *args, **options):
        city_slug: str = options["city"]
        csv_path: Path = options["path"]
        dry_run: bool = options["dry_run"]

        city = City.objects.filter(slug=city_slug).first()
        if city is None:
            raise CommandError(f"Cidade '{city_slug}' não encontrada. Rode as migrations.")

        if not csv_path.is_file():
            raise CommandError(f"Arquivo não encontrado: {csv_path}")

        source = None
        if not dry_run:
            source, _ = CatalogSource.objects.get_or_create(
                city=city,
                slug=options["source_slug"],
                defaults={
                    "name": f"CSV de paradas ({city.name})",
                    "data_mode": options["data_mode"],
                },
            )

        stats = {"created": 0, "updated": 0, "skipped": 0}
        with csv_path.open(newline="", encoding="utf-8-sig") as csv_file:
            reader = csv.DictReader(csv_file)
            missing = REQUIRED_COLUMNS.difference(reader.fieldnames or [])
            if missing:
                raise CommandError(
                    "CSV sem as colunas obrigatórias: " + ", ".join(sorted(missing))
                )

            with transaction.atomic():
                for line_number, row in enumerate(reader, start=2):
                    code = (row.get("codigo") or "").strip()
                    if not code:
                        stats["skipped"] += 1
                        continue

                    try:
                        latitude = Decimal((row.get("lat") or "").strip())
                        longitude = Decimal((row.get("long") or "").strip())
                    except InvalidOperation:
                        stats["skipped"] += 1
                        self.stderr.write(
                            f"Linha {line_number}: coordenadas inválidas; ignorada."
                        )
                        continue

                    name = (row.get("denominacao") or "").strip()
                    if not name:
                        stats["skipped"] += 1
                        continue

                    address = (row.get("endereco") or "").strip()
                    values = {
                        "source": source,
                        "external_id": (row.get("id") or "").strip(),
                        "name": name,
                        "address": address,
                        "latitude": latitude,
                        "longitude": longitude,
                        "search_text": normalize_search_text(
                            " ".join((code, name, address))
                        )[:255],
                        "origin_type": Stop.OriginType.IMPORTED,
                        "is_active": True,
                    }

                    if dry_run:
                        stats["created"] += 1
                        continue

                    _, created = Stop.objects.update_or_create(
                        city=city,
                        code=code,
                        defaults=values,
                    )
                    stats["created" if created else "updated"] += 1

                if dry_run:
                    transaction.set_rollback(True)

        if not dry_run:
            invalidate_catalog_cache(city.slug)

        self.stdout.write(
            self.style.SUCCESS(
                f"Paradas de {city.label}: "
                f"{stats['created']} criadas, {stats['updated']} atualizadas, "
                f"{stats['skipped']} ignoradas."
                + (" (dry-run)" if dry_run else "")
            )
        )
