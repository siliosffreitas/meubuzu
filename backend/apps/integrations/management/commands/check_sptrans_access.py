"""Verifica o acesso à API Olho Vivo com o token configurado.

O comando autentica, busca uma linha de exemplo e lê `/Posicao`, informando
contagens e duração. O token nunca é impresso.
"""

from __future__ import annotations

import time

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.integrations.sptrans.client import SPTransClient
from apps.integrations.sptrans.errors import SPTransError
from apps.integrations.sptrans.gtfs import GtfsFeed


class Command(BaseCommand):
    help = "Testa autenticação e endpoints básicos da API Olho Vivo."

    def add_arguments(self, parser):
        parser.add_argument(
            "--line",
            default="",
            help="Código público de linha para o teste (ex.: 1012-10).",
        )

    def handle(self, *args, **options):
        if not settings.SPTRANS_API_TOKEN:
            raise CommandError(
                "SPTRANS_API_TOKEN não configurado. Defina o token no .env."
            )

        client = SPTransClient()
        started = time.monotonic()
        try:
            client.authenticate()
        except SPTransError as exc:
            raise CommandError(f"Autenticação falhou: {exc}") from exc
        auth_seconds = time.monotonic() - started

        line_code = options["line"] or self._sample_line()
        lines = []
        if line_code:
            try:
                lines = client.search_lines(line_code)
            except SPTransError as exc:
                raise CommandError(f"Busca de linha falhou: {exc}") from exc

        try:
            positions = client.positions()
        except SPTransError as exc:
            raise CommandError(f"Leitura de posições falhou: {exc}") from exc

        elapsed = time.monotonic() - started
        self.stdout.write(
            self.style.SUCCESS(
                f"Autenticação OK em {auth_seconds:.2f}s; "
                f"{len(lines)} registro(s) para {line_code or '(sem linha)'}; "
                f"{len(positions)} posição(ões); total {elapsed:.2f}s."
            )
        )
        for record in lines[:4]:
            self.stdout.write(
                f"  - {record.public_code} sentido={record.direction} "
                f"origem={record.origin_label or '-'} destino={record.destination_label or '-'}"
            )

    def _sample_line(self) -> str:
        feed = GtfsFeed(settings.SPTRANS_GTFS_DIR)
        if not feed.directory.is_dir():
            return ""
        try:
            codes = sorted(feed.line_codes())
        except Exception:  # noqa: BLE001 - amostra é opcional
            return ""
        return codes[0] if codes else ""
