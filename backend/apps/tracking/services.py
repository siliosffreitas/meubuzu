"""Regras de consulta das posições de rastreamento.

A fonte pode mudar (CSV de demonstração hoje, banco volátil amanhã), mas o
envelope devolvido ao app é sempre o mesmo: o cliente não escolhe arquivo nem
sabe como as posições foram obtidas.
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from math import atan2, cos, degrees, radians, sin
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.conf import settings
from django.core.cache import cache

from apps.catalog.models import City, Line
from apps.catalog.services import resolve_line_by_boarding_code
from apps.common.exceptions import ApiError

from .payloads import line_positions_payload, position_payload, positions_payload
from .sources import (
    CSV_SOURCE,
    CsvDemoPositionSource,
    PositionSource,
    PositionSourceUnavailable,
    VehiclePositionDTO,
    normalize_line_code,
)

MAX_TRACKING_LINES = 200

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
    """Libera o modo demo por configuração; produção ainda exige trial/pago.

    Billing e entitlements reais não existem ainda. Quando existirem, basta
    substituir esta checagem sem tocar no restante do fluxo de posições.
    """

    if source_kind == CSV_SOURCE and _demo_enabled():
        return
    raise ApiError(
        "O rastreamento exige teste ativo ou assinatura.",
        code="subscription_required",
        title="Assinatura necessária",
        status_code=402,
    )


def _get_source(source_kind: str) -> PositionSource:
    if source_kind != CSV_SOURCE:
        raise ApiError(
            "A fonte de posições configurada não está disponível.",
            code="source_unavailable",
            title="Fonte indisponível",
            status_code=503,
        )
    return CsvDemoPositionSource()


def _heading_between(
    from_latitude: float,
    from_longitude: float,
    to_latitude: float,
    to_longitude: float,
) -> float | None:
    """Rumo de um ponto a outro em graus (0 = norte, 90 = leste).

    O app apenas gira a seta com esse valor; nenhum cálculo de direção é feito
    no cliente. Coordenadas iguais não definem direção.
    """

    if from_latitude == to_latitude and from_longitude == to_longitude:
        return None

    latitude1 = radians(from_latitude)
    latitude2 = radians(to_latitude)
    delta_longitude = radians(to_longitude - from_longitude)

    y = sin(delta_longitude) * cos(latitude2)
    x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(
        delta_longitude
    )
    return (degrees(atan2(y, x)) + 360) % 360


def _rebase_position(
    row: VehiclePositionDTO,
    *,
    line_id: str,
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
        line_id=line_id,
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
    line_id: str,
    boarding_code: str,
    requested_id: str,
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
                line_id=line_id,
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
            payload["heading"] = _heading_between(
                previous.latitude,
                previous.longitude,
                payload["latitude"],
                payload["longitude"],
            )
        positions.append(payload)

    positions.sort(key=lambda item: item["capturedAt"])
    return line_positions_payload(
        line_id=line_id,
        boarding_code=boarding_code,
        requested_id=requested_id,
        source=source,
        data_mode=data_mode,
        is_stale=any(position["isStale"] for position in positions),
        source_status=SOURCE_STATUS_OK if positions else SOURCE_STATUS_EMPTY,
        positions=positions,
    )


def _cache_key(city: City, requested: list[str], now: datetime) -> str:
    ttl = max(int(getattr(settings, "TRACKING_CACHE_TTL_SECONDS", 10)), 1)
    bucket = int(now.timestamp()) // ttl
    # Os zeros à esquerda fazem parte do sgLinha; não os remova da chave.
    codes = [code.strip() for code in requested]
    raw = f"{city.slug}|{','.join(codes)}|{bucket}"
    return f"tracking:positions:{hashlib.sha1(raw.encode()).hexdigest()}"


def get_positions_payload(
    city: City,
    requested: list[str],
    *,
    user,
    strict: bool = False,
) -> tuple[dict, bool]:
    """Resolve linhas, consulta a fonte e devolve o envelope com cache curto."""

    source_kind = getattr(settings, "TRACKING_POSITIONS_SOURCE", CSV_SOURCE)
    if source_kind == CSV_SOURCE and not settings.DEBUG and not _demo_enabled():
        raise ApiError(
            "A fonte CSV de demonstração não pode ser usada em produção.",
            code="demo_mode_forbidden",
            title="Modo demo proibido",
            status_code=500,
        )

    require_tracking_access(user, source_kind=source_kind)
    source = _get_source(source_kind)

    city_tz = _city_timezone(city)
    now_utc = datetime.now(UTC)
    now_city = now_utc.astimezone(city_tz)

    resolved: list[tuple[str, Line]] = []
    unresolved: list[str] = []
    seen_line_ids: set[str] = set()
    for identifier in requested:
        try:
            line = resolve_line_by_boarding_code(city, identifier)
        except ApiError:
            if strict:
                raise
            unresolved.append(identifier)
            continue
        line_pk = str(line.pk)
        if line_pk in seen_line_ids:
            continue
        seen_line_ids.add(line_pk)
        resolved.append((identifier, line))

    cache_key = _cache_key(city, requested, now_utc)
    cached = cache.get(cache_key)
    if cached is not None:
        return cached, True

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
            line_id=str(line.pk),
            boarding_code=line.boarding_code,
            requested_id=identifier,
            source=source_kind,
            data_mode="demo" if source_kind == CSV_SOURCE else "live",
            now_city=now_city,
            city_tz=city_tz,
            received_at=now_utc,
            window_seconds=window_seconds,
            stale_after_seconds=stale_after_seconds,
        )
        for identifier, line in resolved
    ]

    payload = positions_payload(
        city_slug=city.slug,
        generated_at=now_utc,
        source=source_kind,
        data_mode="demo" if source_kind == CSV_SOURCE else "live",
        lines=line_blocks,
        unresolved_lines=unresolved,
    )
    cache.set(cache_key, payload, getattr(settings, "TRACKING_CACHE_TTL_SECONDS", 10))
    return payload, False
