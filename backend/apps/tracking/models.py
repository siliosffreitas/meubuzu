"""Modelos de rastreamento: fontes, última posição e histórico.

`LatestPosition` é o caminho crítico do app (uma linha por veículo). O
`PositionHistory` é uma tabela particionada por dia, com retenção de 24 horas,
criada por SQL na migration e mantida por jobs de partição.
"""

from __future__ import annotations

import uuid

from django.db import models


class TrackingSource(models.Model):
    """Fonte de posições ativa de uma cidade.

    Uma cidade tem no máximo uma fonte ativa. O `config` guarda apenas o nome da
    variável de ambiente do token, nunca o valor.
    """

    class Kind(models.TextChoices):
        CSV_DEMO = "csv_demo", "CSV de demonstração"
        SPTRANS_API = "sptrans_api", "API Olho Vivo (SPTrans)"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(
        "catalog.City",
        on_delete=models.CASCADE,
        related_name="tracking_sources",
    )
    kind = models.CharField("tipo", max_length=20, choices=Kind.choices)
    config = models.JSONField("configuração", default=dict, blank=True)
    is_active = models.BooleanField("ativa", default=True)
    last_success_at = models.DateTimeField("último sucesso em", null=True, blank=True)
    last_error_at = models.DateTimeField("último erro em", null=True, blank=True)
    last_error_message = models.TextField("último erro", blank=True, default="")
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "tracking_source"
        verbose_name = "fonte de rastreamento"
        verbose_name_plural = "fontes de rastreamento"
        constraints = [
            models.UniqueConstraint(
                fields=["city"],
                condition=models.Q(is_active=True),
                name="tracking_source_active_city_uniq",
            )
        ]

    def __str__(self) -> str:
        return f"{self.city.slug}: {self.kind}"


class LatestPosition(models.Model):
    """Última posição conhecida de um veículo.

    A identidade do veículo é o prefixo público da fonte, não um ID interno do
    banco. A posição anterior permite calcular o rumo da seta no app.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(
        "catalog.City",
        on_delete=models.CASCADE,
        related_name="latest_positions",
    )
    line = models.ForeignKey(
        "catalog.Line",
        on_delete=models.CASCADE,
        related_name="latest_positions",
        null=True,
        blank=True,
    )
    source = models.ForeignKey(
        TrackingSource,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="latest_positions",
    )
    vehicle_code = models.CharField("veículo", max_length=40)
    latitude = models.DecimalField("latitude", max_digits=9, decimal_places=6)
    longitude = models.DecimalField("longitude", max_digits=9, decimal_places=6)
    previous_latitude = models.DecimalField(
        "latitude anterior", max_digits=9, decimal_places=6, null=True, blank=True
    )
    previous_longitude = models.DecimalField(
        "longitude anterior", max_digits=9, decimal_places=6, null=True, blank=True
    )
    heading = models.FloatField("rumo", null=True, blank=True)
    direction = models.PositiveSmallIntegerField("sentido", default=0)
    is_accessible = models.BooleanField("acessível", default=False)
    data_mode = models.CharField("modo dos dados", max_length=8, default="live")
    captured_at = models.DateTimeField("capturada em")
    generated_at = models.DateTimeField("gerada em", null=True, blank=True)
    received_at = models.DateTimeField("recebida em")
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "tracking_latest_position"
        verbose_name = "última posição"
        verbose_name_plural = "últimas posições"
        ordering = ["-captured_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["city", "vehicle_code"],
                name="tracking_latest_city_vehicle_uniq",
            )
        ]
        indexes = [
            models.Index(fields=["city", "line"], name="tracking_latest_city_line_idx"),
            models.Index(
                fields=["city", "-captured_at"], name="tracking_latest_city_time_idx"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.vehicle_code} ({self.city.slug})"


class PositionHistory(models.Model):
    """Histórico de posições, particionado por dia e retido por 24 horas.

    A tabela é criada por SQL (`migrations.RunSQL`) porque o Django não gera DDL
    de tabela particionada. O model fica `managed = False`: o ORM consulta e
    insere, mas nunca tenta criar ou alterar a tabela.

    A partição é por `captured_at` (UTC), então a unique precisa incluir essa
    coluna — requisito do PostgreSQL para tabelas particionadas.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(
        "catalog.City",
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        related_name="+",
    )
    line = models.ForeignKey(
        "catalog.Line",
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        null=True,
        blank=True,
        related_name="+",
    )
    source = models.ForeignKey(
        TrackingSource,
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        null=True,
        blank=True,
        related_name="+",
    )
    vehicle_code = models.CharField("veículo", max_length=40)
    latitude = models.DecimalField("latitude", max_digits=9, decimal_places=6)
    longitude = models.DecimalField("longitude", max_digits=9, decimal_places=6)
    direction = models.PositiveSmallIntegerField("sentido", default=0)
    is_accessible = models.BooleanField("acessível", default=False)
    data_mode = models.CharField("modo dos dados", max_length=8, default="live")
    captured_at = models.DateTimeField("capturada em")
    received_at = models.DateTimeField("recebida em")

    class Meta:
        managed = False
        db_table = "tracking_position_history"
        verbose_name = "histórico de posição"
        verbose_name_plural = "histórico de posições"
        ordering = ["-captured_at"]

    def __str__(self) -> str:
        return f"{self.vehicle_code} @ {self.captured_at:%Y-%m-%d %H:%M}"
