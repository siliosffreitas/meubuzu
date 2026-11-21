"""Valida o diretório do GTFS da SPTrans antes da importação."""

from __future__ import annotations

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.integrations.sptrans.gtfs import GtfsFeed


class Command(BaseCommand):
    help = "Confere arquivos, cabeçalhos e contagens do GTFS da SPTrans."

    def add_arguments(self, parser):
        parser.add_argument(
            "--gtfs-dir",
            default=str(settings.SPTRANS_GTFS_DIR),
            help="Diretório com os arquivos do GTFS.",
        )

    def handle(self, *args, **options):
        feed = GtfsFeed(options["gtfs_dir"])
        validation = feed.validate()

        if not validation.is_valid:
            for error in validation.errors:
                self.stderr.write(self.style.ERROR(f"- {error}"))
            raise CommandError("GTFS inválido.")

        self.stdout.write(
            self.style.SUCCESS(
                f"GTFS válido: {validation.routes} rotas "
                f"({validation.bus_routes} de ônibus), "
                f"{validation.trips} combinações rota+sentido, "
                f"{validation.shapes} shapes, "
                f"{validation.shape_points} pontos."
            )
        )
