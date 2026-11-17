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


class CatalogSource(models.Model):
    """Fonte da qual o catálogo de uma cidade foi importado.

    O `data_mode` segue D2/RF-016: CSV só existe em staging (`demo`); produção
    usa a API da cidade (`live`).
    """

    class DataMode(models.TextChoices):
        DEMO = "demo", "demonstração"
        LIVE = "live", "produção"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(City, on_delete=models.CASCADE, related_name="sources")
    slug = models.SlugField("slug", max_length=60)
    name = models.CharField("nome", max_length=120)
    data_mode = models.CharField(
        "modo dos dados",
        max_length=8,
        choices=DataMode.choices,
        default=DataMode.DEMO,
    )
    is_active = models.BooleanField("ativa", default=True)
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_source"
        verbose_name = "fonte do catálogo"
        verbose_name_plural = "fontes do catálogo"
        constraints = [
            models.UniqueConstraint(
                fields=["city", "slug"], name="catalog_source_city_slug_uniq"
            )
        ]

    def __str__(self) -> str:
        return self.name


class Stop(models.Model):
    """Parada de ônibus pertencente a uma cidade.

    A localização é guardada em latitude/longitude (como em `City`) para que a
    consulta por bounding box use índices btree comuns, sem exigir GDAL/GEOS no
    ORM. `search_text` é o nome/código/endereço sem acentos, preenchido na
    importação, o que permite busca textual sem extensões do PostgreSQL.
    """

    class OriginType(models.TextChoices):
        IMPORTED = "imported", "importado"
        MANUAL = "manual", "manual"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(City, on_delete=models.CASCADE, related_name="stops")
    source = models.ForeignKey(
        CatalogSource,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="stops",
    )
    external_id = models.CharField("id de origem", max_length=64, blank=True, default="")
    code = models.CharField("código", max_length=20)
    name = models.TextField("nome")
    address = models.TextField("endereço", blank=True, default="")
    latitude = models.DecimalField("latitude", max_digits=9, decimal_places=6)
    longitude = models.DecimalField("longitude", max_digits=9, decimal_places=6)
    search_text = models.CharField("busca", max_length=255, blank=True, default="")
    accessibility = models.JSONField("acessibilidade", null=True, blank=True)
    origin_type = models.CharField(
        "origem",
        max_length=16,
        choices=OriginType.choices,
        default=OriginType.IMPORTED,
    )
    is_active = models.BooleanField("ativa", default=True)
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_stop"
        verbose_name = "parada"
        verbose_name_plural = "paradas"
        ordering = ["code"]
        constraints = [
            models.UniqueConstraint(
                fields=["city", "code"], name="catalog_stop_city_code_uniq"
            )
        ]
        indexes = [
            models.Index(
                fields=["city", "is_active", "latitude", "longitude"],
                name="catalog_stop_bbox_idx",
            ),
            models.Index(fields=["city", "search_text"], name="catalog_stop_search_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.code} - {self.name}"


class Line(models.Model):
    """Linha de ônibus pertencente ao catálogo de uma cidade.

    `code` é o `codigoLinha` e `boarding_code` é o `sgLinha` da fonte. O
    `search_text` mantém ambos normalizados para busca textual sem pg_trgm.
    """

    class OriginType(models.TextChoices):
        IMPORTED = "imported", "importado"
        MANUAL = "manual", "manual"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(City, on_delete=models.CASCADE, related_name="lines")
    source = models.ForeignKey(
        CatalogSource,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="lines",
    )
    external_id = models.CharField("id de origem", max_length=64, blank=True, default="")
    code = models.CharField("codigoLinha", max_length=20)
    boarding_code = models.CharField("sgLinha", max_length=20, blank=True, default="")
    name = models.CharField("nome", max_length=200)
    origin = models.TextField("origem", blank=True, default="")
    destination = models.TextField("destino", blank=True, default="")
    search_text = models.CharField("busca", max_length=400, blank=True, default="")
    origin_type = models.CharField(
        "origem do registro",
        max_length=16,
        choices=OriginType.choices,
        default=OriginType.IMPORTED,
    )
    is_active = models.BooleanField("ativa", default=True)
    source_updated_at = models.DateTimeField("atualizada na origem", null=True, blank=True)
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_line"
        verbose_name = "linha"
        verbose_name_plural = "linhas"
        ordering = ["code"]
        constraints = [
            models.UniqueConstraint(
                fields=["city", "code"], name="catalog_line_city_code_uniq"
            )
        ]
        indexes = [
            models.Index(fields=["city", "is_active"], name="catalog_line_city_active_idx"),
            models.Index(fields=["city", "boarding_code"], name="catalog_line_boarding_idx"),
            models.Index(fields=["city", "search_text"], name="catalog_line_search_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.code} - {self.name}"


class LineAlias(models.Model):
    """Alias local de uma linha (nunca apagado por importações)."""

    class Kind(models.TextChoices):
        CODIGO = "codigo", "codigo"
        SGLINHA = "sglinha", "sgLinha"
        LEGACY = "legacy", "legado"
        LOCAL = "local", "local"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    line = models.ForeignKey(Line, on_delete=models.CASCADE, related_name="aliases")
    alias = models.CharField("alias", max_length=40)
    kind = models.CharField("tipo", max_length=16, choices=Kind.choices, default=Kind.LOCAL)

    class Meta:
        db_table = "catalog_line_alias"
        verbose_name = "alias de linha"
        verbose_name_plural = "aliases de linha"
        constraints = [
            models.UniqueConstraint(fields=["line", "alias"], name="catalog_line_alias_uniq")
        ]
        indexes = [models.Index(fields=["alias"], name="catalog_line_alias_idx")]

    def __str__(self) -> str:
        return self.alias


class LineStop(models.Model):
    """Relaciona uma linha a uma parada, na ordem do itinerário."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    line = models.ForeignKey(Line, on_delete=models.CASCADE, related_name="line_stops")
    stop = models.ForeignKey(Stop, on_delete=models.CASCADE, related_name="line_stops")
    direction = models.PositiveSmallIntegerField("sentido", default=0)
    sequence = models.PositiveIntegerField("ordem", default=0)
    created_at = models.DateTimeField("criada em", auto_now_add=True)

    class Meta:
        db_table = "catalog_line_stop"
        verbose_name = "parada da linha"
        verbose_name_plural = "paradas das linhas"
        ordering = ["direction", "sequence"]
        constraints = [
            models.UniqueConstraint(
                fields=["line", "direction", "sequence"], name="catalog_line_stop_sequence_uniq"
            ),
            models.UniqueConstraint(
                fields=["line", "stop", "direction"], name="catalog_line_stop_pair_uniq"
            ),
        ]
        indexes = [models.Index(fields=["line", "direction"], name="catalog_line_stop_dir_idx")]

    def __str__(self) -> str:
        return f"{self.line.code} -> {self.stop.code}"


class Route(models.Model):
    """Traçado geográfico (LineString) de uma linha.

    O `path` guarda a sequência de coordenadas em ordem. Cada ponto é um par
    `[latitude, longitude]`, o mesmo formato consumido pelo mapa no app.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    line = models.ForeignKey(Line, on_delete=models.CASCADE, related_name="routes")
    direction = models.PositiveSmallIntegerField("sentido", default=0)
    path = models.JSONField("traçado", default=list)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_route"
        verbose_name = "traçado"
        verbose_name_plural = "traçados"
        ordering = ["line", "direction"]
        constraints = [
            models.UniqueConstraint(
                fields=["line", "direction"], name="catalog_route_line_direction_uniq"
            )
        ]

    def __str__(self) -> str:
        return f"{self.line.code} ({self.direction})"
