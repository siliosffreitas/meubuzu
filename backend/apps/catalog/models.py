from __future__ import annotations

import uuid

from django.db import models
from django.db.models import Q
from django.utils import timezone


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
    usa a API da cidade (`live`). O `kind` identifica o adaptador usado na
    importação e `config` guarda apenas nomes de variáveis de ambiente, nunca
    segredos.
    """

    class DataMode(models.TextChoices):
        DEMO = "demo", "demonstração"
        LIVE = "live", "produção"

    class Kind(models.TextChoices):
        CSV = "csv", "CSV"
        SPTRANS_API = "sptrans_api", "API Olho Vivo (SPTrans)"
        GTFS = "gtfs", "GTFS"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(City, on_delete=models.CASCADE, related_name="sources")
    slug = models.SlugField("slug", max_length=60)
    name = models.CharField("nome", max_length=120)
    kind = models.CharField(
        "tipo",
        max_length=20,
        choices=Kind.choices,
        default=Kind.CSV,
    )
    data_mode = models.CharField(
        "modo dos dados",
        max_length=8,
        choices=DataMode.choices,
        default=DataMode.DEMO,
    )
    base_url = models.URLField("URL base", blank=True, default="")
    config = models.JSONField("configuração", default=dict, blank=True)
    last_import_at = models.DateTimeField("última importação", null=True, blank=True)
    last_error_at = models.DateTimeField("último erro em", null=True, blank=True)
    last_error_message = models.TextField("último erro", blank=True, default="")
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


class CatalogImportRun(models.Model):
    """Execução da importação de catálogo de uma cidade.

    Guarda apenas metadados e contadores: nenhum payload bruto, token ou
    identificador interno de terceiros é persistido aqui.
    """

    class Status(models.TextChoices):
        RUNNING = "running", "em execução"
        SUCCESS = "success", "sucesso"
        PARTIAL = "partial", "parcial"
        FAILED = "failed", "falha"

    class Trigger(models.TextChoices):
        MANUAL = "manual", "manual"
        SCHEDULE = "schedule", "agendada"
        ADMIN = "admin", "admin"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    city = models.ForeignKey(City, on_delete=models.CASCADE, related_name="import_runs")
    source = models.ForeignKey(
        CatalogSource,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="import_runs",
    )
    trigger = models.CharField(
        "gatilho",
        max_length=16,
        choices=Trigger.choices,
        default=Trigger.MANUAL,
    )
    status = models.CharField(
        "status",
        max_length=16,
        choices=Status.choices,
        default=Status.RUNNING,
    )
    started_at = models.DateTimeField("iniciada em", default=timezone.now)
    finished_at = models.DateTimeField("finalizada em", null=True, blank=True)
    lines_created = models.PositiveIntegerField("linhas criadas", default=0)
    lines_updated = models.PositiveIntegerField("linhas atualizadas", default=0)
    lines_deactivated = models.PositiveIntegerField("linhas desativadas", default=0)
    stops_created = models.PositiveIntegerField("paradas criadas", default=0)
    stops_updated = models.PositiveIntegerField("paradas atualizadas", default=0)
    routes_updated = models.PositiveIntegerField("traçados atualizados", default=0)
    errors = models.PositiveIntegerField("erros", default=0)
    message = models.TextField("mensagem", blank=True, default="")
    created_at = models.DateTimeField("criada em", auto_now_add=True)

    class Meta:
        db_table = "catalog_import_run"
        verbose_name = "execução de importação"
        verbose_name_plural = "execuções de importação"
        ordering = ["-started_at"]
        indexes = [
            models.Index(fields=["city", "-started_at"], name="catalog_import_city_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.city.slug} {self.started_at:%Y-%m-%d %H:%M} ({self.status})"


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

    `code` é o `codigoLinha` (uso interno de importação e busca) e
    `boarding_code` é o `sgLinha`, identificador público da linha. O
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
    boarding_code = models.CharField("sgLinha", max_length=20)
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
            ),
            # O `sgLinha` é a identidade pública da linha: toda linha ativa deve
            # tê-lo preenchido e não pode haver duplicata dentro da cidade.
            models.CheckConstraint(
                condition=Q(is_active=False) | ~Q(boarding_code=""),
                name="catalog_line_active_boarding_code_required",
            ),
            models.UniqueConstraint(
                fields=["city", "boarding_code"],
                condition=Q(is_active=True),
                name="catalog_line_active_city_boarding_uniq",
            ),
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


class LineSourceRef(models.Model):
    """Referência da linha em uma fonte externa, por sentido.

    A API Olho Vivo identifica cada sentido da linha por um `cl` interno. Esse
    código é usado apenas na importação e no crawl de posições: nunca aparece
    nos payloads públicos do MeuBuzu.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    line = models.ForeignKey(
        Line, on_delete=models.CASCADE, related_name="source_refs"
    )
    source = models.ForeignKey(
        CatalogSource,
        on_delete=models.CASCADE,
        related_name="line_refs",
    )
    external_id = models.CharField("id de origem", max_length=64)
    direction = models.PositiveSmallIntegerField("sentido", default=0)
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "catalog_line_source_ref"
        verbose_name = "referência de linha na fonte"
        verbose_name_plural = "referências de linha na fonte"
        ordering = ["line", "direction"]
        constraints = [
            models.UniqueConstraint(
                fields=["source", "external_id"],
                name="catalog_line_ref_source_external_uniq",
            )
        ]
        indexes = [
            models.Index(fields=["line", "direction"], name="catalog_line_ref_dir_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.line.boarding_code} ({self.direction})"


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
