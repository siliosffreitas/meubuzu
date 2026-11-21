"""Regras de consulta das posições de rastreamento.

A fonte pode mudar (CSV de demonstração hoje, banco volátil amanhã), mas o
envelope devolvido ao app é sempre o mesmo: o cliente não escolhe arquivo nem
sabe como as posições foram obtidas.
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.conf import settings
from django.core.cache import cache

from apps.catalog.models import City, Line
from apps.catalog.services import resolve_line_by_boarding_code
from apps.common.exceptions import ApiError

from .geo import heading_between
from .models import LatestPosition, TrackingSource
from .payloads import line_positions_payload, position_payload, positions_payload
from .sources import (
    CSV_SOURCE,
    CsvDemoPositionSource,
    PositionSource,
    PositionSourceUnavailable,
    VehiclePositionDTO,
    normalize_line_code,
)

SPTRANS_SOURCE = TrackingSource.Kind.SPTRANS_API

MAX_TRACKING_LINES = 200

# Versão do envelope em cache: incrementar ao alterar o formato público para
# que payloads com identificadores antigos não sobrevivam a um deploy.
TRACKING_PAYLOAD_VERSION = 2

SOURCE_STATUS_OK = "ok"
SOURCE_STATUS_EMPTY = "no_positions"


def parse_line_codes(raw: str | None) -> list[str]:
    """Lê `?codes=0301,0245`: uma lista de `sgLinha`, sem remover zeros.

    Os vazios e duplicados exatos são descartados sem perder a ordem. Linhas
    diferentes que apontam para o mesmo `sgLinha` são deduplicadas depois da
    resolução no catálogo.
    """

    if not raw:
        raise ApiError(
            "Informe ao menos um sgLinha em codes.",
            code="invalid_codes",
            title="Códigos inválidos",
            status_code=400,
        )

    codes: list[str] = []
    for part in raw.split(","):
        code = part.strip()
        if code and code not in codes:
            codes.append(code)

    if not codes:
        raise ApiError(
            "Informe ao menos um sgLinha em codes.",
            code="invalid_codes",
            title="Códigos inválidos",
            status_code=400,
        )
    if len(codes) > MAX_TRACKING_LINES:
        raise ApiError(
            f"Informe no máximo {MAX_TRACKING_LINES} linhas por consulta.",
            code="invalid_codes",
            title="Códigos inválidos",
            status_code=400,
        )
    return codes


def _demo_enabled() -> bool:
    return bool(getattr(settings, "TRACKING_DEMO_ACCESS_ENABLED", settings.DEBUG))


def _city_timezone(city: City) -> ZoneInfo:
    try:
        return ZoneInfo(city.timezone)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise ApiError(
            "O fuso horário da cidade é inválido.",
            code="city_timezone_invalid",
            title="Fuso inválido",
            status_code=500,
        ) from exc


def require_tracking_access(_user, *, source_kind: str) -> None:
    """Libera o modo demo e o rastreamento live de staging por configuração.

    Billing e entitlements reais não existem ainda. Em produção, apenas fontes
    `live` com a flag de staging desligada continuam bloqueadas.
    """

    if source_kind == CSV_SOURCE and _demo_enabled():
        return
    if source_kind == SPTRANS_SOURCE and getattr(
        settings, "TRACKING_LIVE_ACCESS_ENABLED", False
    ):
        return
    raise ApiError(
        "O rastreamento exige teste ativo ou assinatura.",
        code="subscription_required",
        title="Assinatura necessária",
        status_code=402,
    )


def resolve_source_kind(city: City) -> str:
    """Fonte ativa da cidade, com fallback para a configuração global."""

    source = (
        TrackingSource.objects.filter(city=city, is_active=True).only("kind").first()
    )
    if source is not None:
        return source.kind
    return getattr(settings, "TRACKING_POSITIONS_SOURCE", CSV_SOURCE)


def _get_source(source_kind: str) -> PositionSource:
    if source_kind != CSV_SOURCE:
        raise ApiError(
            "A fonte de posições configurada não está disponível.",
            code="source_unavailable",
            title="Fonte indisponível",
            status_code=503,
        )
    return CsvDemoPositionSource()


def _rebase_position(
    row: VehiclePositionDTO,
    *,
    boarding_code: str,
    now_city: datetime,
    city_tz: ZoneInfo,
    received_at: datetime,
    window_seconds: int,
    stale_after_seconds: int,
) -> dict | None:
    """Ajusta o replay para o dia atual e aplica a janela de 5 minutos.

    A hora lida do CSV é usada literalmente, como no app antigo. Para cruzar a
    meia-noite sem descartar capturas próximas, a data passa a ser ontem quando
    a hora do arquivo é maior que a hora atual da cidade.
    """

    captured_seconds = (
        row.captured_clock.hour * 3600
        + row.captured_clock.minute * 60
        + row.captured_clock.second
    )
    now_seconds = now_city.hour * 3600 + now_city.minute * 60 + now_city.second
    elapsed = (now_seconds - captured_seconds) % 86_400
    if elapsed > window_seconds:
        return None

    captured_date = now_city.date()
    if captured_seconds > now_seconds:
        captured_date -= timedelta(days=1)

    captured_local = datetime.combine(captured_date, row.captured_clock).replace(tzinfo=city_tz)
    captured_at = captured_local.astimezone(UTC)
    shift = captured_at - row.captured_at
    generated_at = row.generated_at + shift if row.generated_at is not None else None

    is_stale = (received_at - captured_at).total_seconds() > stale_after_seconds
    return position_payload(
        boarding_code=boarding_code,
        vehicle_code=row.vehicle_code,
        latitude=row.latitude,
        longitude=row.longitude,
        captured_at=captured_at,
        generated_at=generated_at,
        received_at=received_at,
        heading=None,
        previous_latitude=None,
        previous_longitude=None,
        is_stale=is_stale,
    )


def _positions_for_line(
    line: Line,
    rows: list[VehiclePositionDTO],
    *,
    boarding_code: str,
    requested_code: str,
    source: str,
    data_mode: str,
    now_city: datetime,
    city_tz: ZoneInfo,
    received_at: datetime,
    window_seconds: int,
    stale_after_seconds: int,
) -> dict:
    line_code = normalize_line_code(line.code)
    ordered_rows = sorted(
        (row for row in rows if row.line_code == line_code),
        key=lambda row: row.captured_at,
    )

    # O histórico completo fica disponível mesmo para capturas fora da janela:
    # a posição anterior serve para calcular o rumo da seta no primeiro recebimento.
    history_by_vehicle: dict[str, list[VehiclePositionDTO]] = {}
    for row in ordered_rows:
        history_by_vehicle.setdefault(row.vehicle_code, []).append(row)

    # Apenas capturas dentro da janela podem virar a posição atual.
    latest_by_vehicle: dict[str, tuple[int, dict]] = {}
    for vehicle_code, history in history_by_vehicle.items():
        for index, row in enumerate(history):
            payload = _rebase_position(
                row,
                boarding_code=boarding_code,
                now_city=now_city,
                city_tz=city_tz,
                received_at=received_at,
                window_seconds=window_seconds,
                stale_after_seconds=stale_after_seconds,
            )
            if payload is None:
                continue

            current = latest_by_vehicle.get(vehicle_code)
            if current is None or payload["capturedAt"] > current[1]["capturedAt"]:
                latest_by_vehicle[vehicle_code] = (index, payload)

    positions = []
    for vehicle_code, (index, payload) in latest_by_vehicle.items():
        history = history_by_vehicle[vehicle_code]
        previous = history[index - 1] if index > 0 else None
        if previous is not None:
            payload["previousLatitude"] = previous.latitude
            payload["previousLongitude"] = previous.longitude
            payload["heading"] = heading_between(
                previous.latitude,
                previous.longitude,
                payload["latitude"],
                payload["longitude"],
            )
        positions.append(payload)

    positions.sort(key=lambda item: item["capturedAt"])
    return line_positions_payload(
        boarding_code=boarding_code,
        requested_code=requested_code,
        source=source,
        data_mode=data_mode,
        is_stale=any(position["isStale"] for position in positions),
        source_status=SOURCE_STATUS_OK if positions else SOURCE_STATUS_EMPTY,
        positions=positions,
    )


def _cache_key(city: City, requested: list[str], now: datetime, source_kind: str) -> str:
    ttl = max(int(getattr(settings, "TRACKING_CACHE_TTL_SECONDS", 10)), 1)
    bucket = int(now.timestamp()) // ttl
    # Os zeros à esquerda fazem parte do sgLinha; não os remova da chave.
    codes = [code.strip() for code in requested]
    raw = f"v{TRACKING_PAYLOAD_VERSION}|{city.slug}|{source_kind}|{','.join(codes)}|{bucket}"
    digest = hashlib.sha1(raw.encode()).hexdigest()
    return f"tracking:positions:v{TRACKING_PAYLOAD_VERSION}:{digest}"


def _resolve_requested(
    city: City, requested: list[str], *, strict: bool
) -> tuple[list[tuple[str, Line]], list[str]]:
    resolved: list[tuple[str, Line]] = []
    unresolved: list[str] = []
    seen_boarding_codes: set[str] = set()

    for identifier in requested:
        try:
            line = resolve_line_by_boarding_code(city, identifier)
        except ApiError:
            if strict:
                raise
            unresolved.append(identifier)
            continue
        boarding_code = line.boarding_code.strip()
        if boarding_code in seen_boarding_codes:
            continue
        seen_boarding_codes.add(boarding_code)
        resolved.append((identifier, line))

    return resolved, unresolved


def _live_line_block(
    line: Line,
    positions: list[LatestPosition],
    *,
    requested_code: str,
    now_utc: datetime,
    stale_after_seconds: int,
) -> dict:
    items = []
    for position in positions:
        is_stale = (
            now_utc - position.captured_at
        ).total_seconds() > stale_after_seconds
        items.append(
            position_payload(
                boarding_code=line.boarding_code,
                vehicle_code=position.vehicle_code,
                latitude=float(position.latitude),
                longitude=float(position.longitude),
                captured_at=position.captured_at,
                generated_at=position.generated_at,
                received_at=position.received_at,
                heading=position.heading,
                previous_latitude=(
                    float(position.previous_latitude)
                    if position.previous_latitude is not None
                    else None
                ),
                previous_longitude=(
                    float(position.previous_longitude)
                    if position.previous_longitude is not None
                    else None
                ),
                is_stale=is_stale,
            )
        )

    items.sort(key=lambda item: item["capturedAt"] or "")
    return line_positions_payload(
        boarding_code=line.boarding_code,
        requested_code=requested_code,
        source=SPTRANS_SOURCE,
        data_mode="live",
        is_stale=any(item["isStale"] for item in items),
        source_status=SOURCE_STATUS_OK if items else SOURCE_STATUS_EMPTY,
        positions=items,
    )


def _live_payload(
    city: City,
    resolved: list[tuple[str, Line]],
    unresolved: list[str],
    *,
    now_utc: datetime,
) -> dict:
    """Monta o envelope a partir das últimas posições gravadas pelo crawler."""

    stale_after_seconds = int(getattr(settings, "TRACKING_STALE_AFTER_SECONDS", 120))
    line_ids = [line.id for _, line in resolved]
    rows = (
        LatestPosition.objects.filter(city=city, line_id__in=line_ids).select_related(
            "line"
        )
        if line_ids
        else []
    )

    by_line: dict[object, list[LatestPosition]] = {}
    for row in rows:
        by_line.setdefault(row.line_id, []).append(row)

    blocks = [
        _live_line_block(
            line,
            by_line.get(line.id, []),
            requested_code=identifier,
            now_utc=now_utc,
            stale_after_seconds=stale_after_seconds,
        )
        for identifier, line in resolved
    ]

    return positions_payload(
        city_slug=city.slug,
        generated_at=now_utc,
        source=SPTRANS_SOURCE,
        data_mode="live",
        lines=blocks,
        unresolved_lines=unresolved,
    )


def _demo_payload(
    city: City,
    resolved: list[tuple[str, Line]],
    unresolved: list[str],
    *,
    source_kind: str,
    now_utc: datetime,
    now_city: datetime,
    city_tz: ZoneInfo,
) -> dict:
    source = _get_source(source_kind)
    line_codes = {normalize_line_code(line.code) for _, line in resolved}
    try:
        rows = source.fetch(line_codes=line_codes, now=now_city)
    except PositionSourceUnavailable as exc:
        raise ApiError(
            "A fonte de posições não respondeu.",
            code="source_unavailable",
            title="Fonte indisponível",
            status_code=503,
        ) from exc

    window_seconds = int(getattr(settings, "TRACKING_POSITION_WINDOW_SECONDS", 300))
    stale_after_seconds = int(getattr(settings, "TRACKING_STALE_AFTER_SECONDS", 120))

    line_blocks = [
        _positions_for_line(
            line,
            rows,
            boarding_code=line.boarding_code,
            requested_code=identifier,
            source=source_kind,
            data_mode="demo",
            now_city=now_city,
            city_tz=city_tz,
            received_at=now_utc,
            window_seconds=window_seconds,
            stale_after_seconds=stale_after_seconds,
        )
        for identifier, line in resolved
    ]

    return positions_payload(
        city_slug=city.slug,
        generated_at=now_utc,
        source=source_kind,
        data_mode="demo",
        lines=line_blocks,
        unresolved_lines=unresolved,
    )


def get_positions_payload(
    city: City,
    requested: list[str],
    *,
    user,
    strict: bool = False,
) -> tuple[dict, bool]:
    """Resolve a fonte da cidade, consulta as posições e aplica cache curto."""

    source_kind = resolve_source_kind(city)
    if source_kind == CSV_SOURCE and not settings.DEBUG and not _demo_enabled():
        raise ApiError(
            "A fonte CSV de demonstração não pode ser usada em produção.",
            code="demo_mode_forbidden",
            title="Modo demo proibido",
            status_code=500,
        )

    require_tracking_access(user, source_kind=source_kind)

    city_tz = _city_timezone(city)
    now_utc = datetime.now(UTC)
    now_city = now_utc.astimezone(city_tz)

    resolved, unresolved = _resolve_requested(city, requested, strict=strict)

    cache_key = _cache_key(city, requested, now_utc, source_kind)
    cached = cache.get(cache_key)
    if cached is not None:
        return cached, True

    if source_kind == SPTRANS_SOURCE:
        payload = _live_payload(city, resolved, unresolved, now_utc=now_utc)
    else:
        payload = _demo_payload(
            city,
            resolved,
            unresolved,
            source_kind=source_kind,
            now_utc=now_utc,
            now_city=now_city,
            city_tz=city_tz,
        )

    cache.set(cache_key, payload, getattr(settings, "TRACKING_CACHE_TTL_SECONDS", 10))
    return payload, False
