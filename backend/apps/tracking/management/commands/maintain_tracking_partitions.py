"""Cria partições futuras e expurga o histórico fora da janela de retenção."""

from __future__ import annotations

from django.core.management.base import BaseCommand, CommandError

from apps.tracking.partitions import (
    drop_expired_partitions,
    ensure_partitions,
    retention_hours,
    trim_expired_rows,
)


class Command(BaseCommand):
    help = (
        "Mantém as partições diárias do histórico de posições: cria as futuras, "
        "dropa as expiradas e remove linhas fora da retenção."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--ensure-hours",
            type=int,
            default=48,
            help="Quantas horas à frente garantir partições (default: 48).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Apenas informa o que seria feito, sem alterar o banco.",
        )
        parser.add_argument(
            "--skip-trim",
            action="store_true",
            help="Não remove linhas dentro da partição de fronteira.",
        )

    def handle(self, *args, **options):
        hours = retention_hours()
        days_ahead = max(options["ensure_hours"] // 24, 0)

        if options["dry_run"]:
            self.stdout.write(
                f"dry-run: garantir partições para {days_ahead + 1} dia(s), "
                f"dropa partições encerradas antes de {hours} h atrás"
                + ("" if options["skip_trim"] else " e remove linhas expiradas")
                + "."
            )
            return

        try:
            created = ensure_partitions(days_ahead=days_ahead)
        except RuntimeError as exc:
            raise CommandError(str(exc)) from exc

        dropped = drop_expired_partitions()
        trimmed = 0 if options["skip_trim"] else trim_expired_rows()

        self.stdout.write(
            self.style.SUCCESS(
                f"Partições criadas: {len(created)}; removidas: {len(dropped)}; "
                f"linhas expurgadas: {trimmed}."
            )
        )
