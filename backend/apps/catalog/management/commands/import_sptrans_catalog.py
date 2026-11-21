"""Importa o catálogo de São Paulo da API Olho Vivo e dos traçados do GTFS."""

from __future__ import annotations

import logging

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from apps.catalog.models import CatalogImportRun, CatalogSource, City
from apps.catalog.sptrans_import import import_catalog
from apps.common.locks import LockNotAcquired, cache_lock
from apps.integrations.sptrans.client import SPTransClient
from apps.integrations.sptrans.errors import GtfsError, SPTransError
from apps.integrations.sptrans.gtfs import GtfsFeed

logger = logging.getLogger(__name__)

DEFAULT_SOURCE_SLUG = "sptrans-api"


class Command(BaseCommand):
    help = (
        "Importa linhas, paradas, itinerários (API Olho Vivo) e traçados (GTFS) "
        "de uma cidade para o catálogo do MeuBuzu."
    )

    def add_arguments(self, parser):
        parser.add_argument("--city", default="sao-paulo", help="Slug da cidade.")
        parser.add_argument(
            "--source-slug", default=DEFAULT_SOURCE_SLUG, help="Slug da fonte."
        )
        parser.add_argument(
            "--gtfs-dir",
            default=str(settings.SPTRANS_GTFS_DIR),
            help="Diretório com os arquivos do GTFS.",
        )
        parser.add_argument(
            "--dry-run", action="store_true", help="Não grava nada no banco."
        )
        parser.add_argument(
            "--limit", type=int, default=None, help="Limita a quantidade de linhas."
        )
        parser.add_argument(
            "--lines",
            default="",
            help="Lista de códigos públicos separados por vírgula.",
        )
        parser.add_argument(
            "--skip-shapes", action="store_true", help="Não importa traçados."
        )
        parser.add_argument(
            "--shapes-only", action="store_true", help="Importa apenas traçados."
        )
        parser.add_argument(
            "--trigger",
            default=CatalogImportRun.Trigger.MANUAL,
            choices=[choice.value for choice in CatalogImportRun.Trigger],
            help="Gatilho registrado na execução.",
        )

    def handle(self, *args, **options):
        city = self._city(options["city"])
        source = self._source(city, options["source_slug"])
        feed = self._feed(options["gtfs_dir"], options["skip_shapes"] or options["shapes_only"])

        only_lines = {
            code.strip()
            for code in options["lines"].split(",")
            if code.strip()
        } or None

        lock_key = f"catalog:import:{city.slug}"
        try:
            with cache_lock(key=lock_key, timeout=60 * 60 * 4):
                result = import_catalog(
                    city=city,
                    source=source,
                    client=SPTransClient(),
                    feed=feed,
                    trigger=options["trigger"],
                    dry_run=options["dry_run"],
                    limit=options["limit"],
                    only_lines=only_lines,
                    skip_shapes=options["skip_shapes"],
                    shapes_only=options["shapes_only"],
                )
        except LockNotAcquired as exc:
            raise CommandError(
                "Já existe uma importação em andamento para esta cidade."
            ) from exc
        except SPTransError as exc:
            raise CommandError(f"Falha na API da SPTrans: {exc}") from exc

        prefix = "dry-run: " if options["dry_run"] else ""
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}importação concluída em {timezone.now():%Y-%m-%d %H:%M:%S} "
                f"(linhas +{result.lines_created}/~{result.lines_updated}, "
                f"desativadas {result.lines_deactivated}, "
                f"paradas +{result.stops_created}/~{result.stops_updated}, "
                f"traçados {result.routes_updated}, erros {result.errors})"
            )
        )
        for message in result.messages[:20]:
            self.stdout.write(f"  - {message}")

    def _city(self, slug: str) -> City:
        try:
            return City.objects.get(slug=slug)
        except City.DoesNotExist as exc:
            raise CommandError(f"Cidade não encontrada: {slug}") from exc

    def _source(self, city: City, slug: str) -> CatalogSource:
        source, _ = CatalogSource.objects.get_or_create(
            city=city,
            slug=slug,
            defaults={
                "name": "API Olho Vivo (SPTrans)",
                "kind": CatalogSource.Kind.SPTRANS_API,
                "data_mode": CatalogSource.DataMode.LIVE,
                "base_url": settings.SPTRANS_API_BASE_URL,
            },
        )
        changed = False
        if source.kind != CatalogSource.Kind.SPTRANS_API:
            source.kind = CatalogSource.Kind.SPTRANS_API
            changed = True
        if source.data_mode != CatalogSource.DataMode.LIVE:
            source.data_mode = CatalogSource.DataMode.LIVE
            changed = True
        if changed:
            source.save(update_fields=["kind", "data_mode", "updated_at"])
        return source

    def _feed(self, directory: str, shapes_disabled: bool) -> GtfsFeed | None:
        feed = GtfsFeed(directory)
        if not feed.directory.is_dir():
            if shapes_disabled:
                return None
            raise CommandError(
                f"Diretório GTFS não encontrado: {feed.directory}. "
                "Use --skip-shapes para importar apenas o catálogo da API."
            )
        try:
            validation = feed.validate()
        except GtfsError as exc:
            raise CommandError(f"GTFS inválido: {exc}") from exc
        if not validation.is_valid:
            raise CommandError(
                "GTFS inválido: " + "; ".join(validation.errors)
            )
        logger.info(
            "GTFS validado: %d rotas (%d de ônibus), %d shapes, %d pontos.",
            validation.routes,
            validation.bus_routes,
            validation.shapes,
            validation.shape_points,
        )
        return feed
