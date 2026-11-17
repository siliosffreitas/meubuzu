from __future__ import annotations

import uuid

from django.db import models


class City(models.Model):
    """Cidade atendida pelo MeuBuzu.

    O `timezone` define o dia da cota de rastreamento e o `import_interval`
    define a cadência da importação do catálogo. O centro é armazenado como
    latitude/longitude para não depender de PostGIS no ORM.
    """

    class ImportInterval(models.TextChoices):
        WEEKLY = "weekly", "semanal"
        MONTHLY = "monthly", "mensal"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField("slug", max_length=60, unique=True)
    name = models.CharField("nome", max_length=120)
    state = models.CharField("UF", max_length=2)
    country = models.CharField("país", max_length=2, default="BR")
    timezone = models.CharField("fuso horário", max_length=64)
    latitude = models.DecimalField("latitude", max_digits=9, decimal_places=6)
    longitude = models.DecimalField("longitude", max_digits=9, decimal_places=6)
    import_interval = models.CharField(
        "intervalo de importação",
        max_length=16,
        choices=ImportInterval.choices,
        default=ImportInterval.WEEKLY,
    )
    is_active = models.BooleanField("ativa", default=True)
    coverage_note = models.TextField("observação de cobertura", blank=True, default="")
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_city"
        verbose_name = "cidade"
        verbose_name_plural = "cidades"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.label

    @property
    def label(self) -> str:
        return f"{self.name} - {self.state}" if self.state else self.name
