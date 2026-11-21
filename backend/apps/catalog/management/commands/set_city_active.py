"""Ativa ou desativa uma cidade de forma explícita.

São Paulo é criada inativa. A ativação é sempre um comando consciente, feito
primeiro em staging e em produção apenas depois do gate de lançamento.
"""

from __future__ import annotations

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.models import City
from apps.catalog.services import invalidate_catalog_cache


class Command(BaseCommand):
    help = "Ativa ou desativa uma cidade pelo slug."

    def add_arguments(self, parser):
        parser.add_argument("slug", help="Slug da cidade (ex.: sao-paulo).")
        group = parser.add_mutually_exclusive_group(required=True)
        group.add_argument("--active", action="store_true", help="Ativa a cidade.")
        group.add_argument("--inactive", action="store_true", help="Desativa a cidade.")

    def handle(self, *args, **options):
        slug = options["slug"].strip()
        try:
            city = City.objects.get(slug=slug)
        except City.DoesNotExist as exc:
            raise CommandError(f"Cidade não encontrada: {slug}") from exc

        is_active = bool(options["active"])
        if city.is_active != is_active:
            city.is_active = is_active
            city.save(update_fields=["is_active", "updated_at"])
            invalidate_catalog_cache(city.slug)

        state = "ativa" if city.is_active else "inativa"
        self.stdout.write(self.style.SUCCESS(f"{city.label} agora está {state}."))
