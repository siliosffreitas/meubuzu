"""Executa um ciclo de ingestão de posições da API Olho Vivo."""

from __future__ import annotations

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.catalog.models import City
from apps.common.locks import LockNotAcquired, cache_lock
from apps.integrations.sptrans.client import SPTransClient
from apps.integrations.sptrans.errors import SPTransError
from apps.tracking.crawler import (
    crawl_positions,
    record_source_error,
    record_source_success,
)
from apps.tracking.models import TrackingSource


class Command(BaseCommand):
    help = "Lê /Posicao da SPTrans e atualiza as posições da cidade."

    def add_arguments(self, parser):
        parser.add_argument("--city", default="sao-paulo", help="Slug da cidade.")
        parser.add_argument(
            "--no-history",
            action="store_true",
            help="Não grava o histórico particionado.",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Consulta a API sem gravar posições.",
        )

    def handle(self, *args, **options):
        city = self._city(options["city"])
        source = self._source(city)

        if options["dry_run"]:
            client = SPTransClient()
            client.authenticate()
            records = client.positions()
            self.stdout.write(
                self.style.SUCCESS(
                    f"dry-run: {len(records)} posições recebidas para {city.slug}."
                )
            )
            return

        try:
            with cache_lock(
                key=f"tracking:crawl:{city.slug}",
                timeout=int(getattr(settings, "TRACKING_CRAWL_LOCK_SECONDS", 25)),
            ):
                result = crawl_positions(
                    city=city,
                    source=source,
                    client=SPTransClient(),
                    write_history=False if options["no_history"] else None,
                )
        except LockNotAcquired as exc:
            raise CommandError(
                "Já existe um crawl em andamento para esta cidade."
            ) from exc
        except SPTransError as exc:
            record_source_error(source, exc)
            raise CommandError(f"Falha no crawl da SPTrans: {exc}") from exc

        record_source_success(source)
        self.stdout.write(
            self.style.SUCCESS(
                f"{city.slug}: {result.updated} posições atualizadas "
                f"({result.ignored} ignoradas, {result.history_rows} no histórico, "
                f"{result.unresolved_lines} linhas desconhecidas) em "
                f"{result.duration_seconds:.2f}s."
            )
        )

    def _city(self, slug: str) -> City:
        try:
            return City.objects.get(slug=slug)
        except City.DoesNotExist as exc:
            raise CommandError(f"Cidade não encontrada: {slug}") from exc

    def _source(self, city: City) -> TrackingSource:
        source = TrackingSource.objects.filter(city=city, is_active=True).first()
        if source is None:
            raise CommandError(f"Nenhuma fonte de rastreamento ativa para {city.slug}.")
        if source.kind != TrackingSource.Kind.SPTRANS_API:
            raise CommandError(
                f"A fonte ativa de {city.slug} é {source.kind}, não sptrans_api."
            )
        return source
