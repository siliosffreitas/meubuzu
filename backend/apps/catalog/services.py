from __future__ import annotations

import hashlib
import json
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.core.cache import cache
from django.db import models

from apps.common.exceptions import ApiError

from .models import City, Line, Route, Stop
from .payloads import line_payload, route_payload, stop_payload
from .text import normalize_search_text


def get_active_city(slug: str) -> City:
    """Resolve uma cidade ativa ou levanta o erro estável da API.

    Usado por todos os endpoints escopados por cidade para que nenhuma rota de
    catálogo/rastreamento funcione sem uma cidade válida.
    """

    try:
        city = City.objects.get(slug=slug)
    except City.DoesNotExist as exc:
        raise ApiError(
            "Cidade não encontrada.",
            code="city_not_found",
            title="Cidade não encontrada",
            status_code=404,
        ) from exc

    if not city.is_active:
        raise ApiError(
            "Esta cidade não está disponível.",
            code="city_inactive",
            title="Cidade indisponível",
            status_code=409,
        )

    return city


# --- Catálogo de paradas em cache ------------------------------------------

CATALOG_CACHE_TTL_SECONDS = getattr(settings, "CATALOG_CACHE_TTL_SECONDS", 300)
MAX_BBOX_AREA = Decimal("1.0")
MAX_BBOX_SPAN = Decimal("2.0")
MAX_CODES = 200


def _bbox_error(detail: str) -> ApiError:
    return ApiError(
        detail,
        code="invalid_bbox",
        title="Área inválida",
        status_code=400,
    )


def parse_bbox(raw: str) -> tuple[Decimal, Decimal, Decimal, Decimal]:
    """Converte `minLon,minLat,maxLon,maxLat` e valida a área consultada."""

    parts = [part.strip() for part in raw.split(",")]
    if len(parts) != 4:
        raise _bbox_error("Informe bbox=minLon,minLat,maxLon,maxLat.")

    try:
        min_lon, min_lat, max_lon, max_lat = (Decimal(part) for part in parts)
    except InvalidOperation as exc:
        raise _bbox_error("As coordenadas do bbox devem ser números.") from exc

    if not (
        Decimal("-180") <= min_lon <= Decimal("180")
        and Decimal("-180") <= max_lon <= Decimal("180")
        and Decimal("-90") <= min_lat <= Decimal("90")
        and Decimal("-90") <= max_lat <= Decimal("90")
    ):
        raise _bbox_error("Coordenadas fora do intervalo permitido.")

    if min_lon > max_lon or min_lat > max_lat:
        raise _bbox_error("Os limites mínimos devem ser menores que os máximos.")

    lon_span = max_lon - min_lon
    lat_span = max_lat - min_lat
    if lon_span > MAX_BBOX_SPAN or lat_span > MAX_BBOX_SPAN:
        raise _bbox_error("A área consultada é grande demais.")
    if lon_span * lat_span > MAX_BBOX_AREA:
        raise _bbox_error("A área consultada é grande demais.")

    return min_lon, min_lat, max_lon, max_lat


def _version_key(city_slug: str) -> str:
    return f"catalog:stops:version:{city_slug}"


def catalog_version(city_slug: str) -> int:
    """Versão do cache da cidade, usada para invalidar sem varrer chaves."""

    key = _version_key(city_slug)
    version = cache.get(key)
    if version is None:
        version = 1
        cache.set(key, version, None)
    return version


def invalidate_catalog_cache(city_slug: str) -> None:
    """Descarta o catálogo em cache da cidade após uma importação."""

    key = _version_key(city_slug)
    try:
        cache.incr(key)
    except ValueError:
        cache.set(key, catalog_version(city_slug) + 1, None)


def _cache_key(city_slug: str, params: dict) -> str:
    raw = json.dumps(
        {"city": city_slug, "version": catalog_version(city_slug), "params": params},
        sort_keys=True,
        ensure_ascii=False,
    )
    return "catalog:stops:" + hashlib.sha1(raw.encode("utf-8")).hexdigest()


def cached_stops(
    city_slug: str,
    *,
    bbox: tuple[Decimal, Decimal, Decimal, Decimal] | None = None,
    query: str | None = None,
    codes: list[str] | None = None,
    limit: int = 500,
) -> tuple[list[dict], bool]:
    """Consulta paradas ativas de uma cidade, servindo do Redis quando possível.

    Retorna `(payloads, cache_hit)`. O cache é versionado por cidade para que a
    importação invalide todas as consultas antigas de uma só vez.
    """

    params: dict = {"limit": limit}
    if bbox is not None:
        params["bbox"] = [str(value) for value in bbox]
    if query:
        params["query"] = normalize_search_text(query)
    if codes:
        params["codes"] = codes

    cache_key = _cache_key(city_slug, params)
    cached = cache.get(cache_key)
    if cached is not None:
        return cached, True

    stops = Stop.objects.filter(city__slug=city_slug, is_active=True).select_related(
        "source"
    )
    if bbox is not None:
        min_lon, min_lat, max_lon, max_lat = bbox
        stops = stops.filter(
            latitude__gte=min_lat,
            latitude__lte=max_lat,
            longitude__gte=min_lon,
            longitude__lte=max_lon,
        )
    if query:
        stops = stops.filter(search_text__contains=normalize_search_text(query))
    if codes:
        stops = stops.filter(code__in=codes)

    if codes:
        # A ordem informada pelo app (findByCodes) deve ser preservada.
        by_code = {stop.code: stop for stop in stops}
        ordered = [by_code[code] for code in codes if code in by_code]
        payloads = [stop_payload(stop) for stop in ordered[:limit]]
    else:
        payloads = [stop_payload(stop) for stop in stops[:limit]]

    cache.set(cache_key, payloads, CATALOG_CACHE_TTL_SECONDS)
    return payloads, False


# --- Catálogo de linhas em cache -------------------------------------------


def _lines_cache_key(city_slug: str, params: dict) -> str:
    raw = json.dumps(
        {"city": city_slug, "version": catalog_version(city_slug), "params": params},
        sort_keys=True,
        ensure_ascii=False,
    )
    return "catalog:lines:" + hashlib.sha1(raw.encode("utf-8")).hexdigest()


def cached_lines(
    city_slug: str,
    *,
    query: str | None = None,
    codes: list[str] | None = None,
    limit: int = 100,
) -> tuple[list[dict], bool]:
    """Consulta linhas ativas de uma cidade, servindo do cache Redis.

    `query` usa o `search_text` normalizado e `codes` preserva a ordem recebida,
    como esperado pelo `findByCodes` do app.
    """

    params: dict = {"limit": limit}
    if query:
        params["query"] = normalize_search_text(query)
    if codes:
        params["codes"] = codes

    cache_key = _lines_cache_key(city_slug, params)
    cached = cache.get(cache_key)
    if cached is not None:
        return cached, True

    lines = Line.objects.filter(city__slug=city_slug, is_active=True).select_related(
        "source"
    )
    if query:
        # Cada token precisa aparecer no texto normalizado, o que aproxima a
        # busca tolerante a espaços/hífens esperada pelo app sem pg_trgm.
        for token in normalize_search_text(query).split():
            lines = lines.filter(search_text__contains=token)
    if codes:
        lines = lines.filter(code__in=codes) | lines.filter(
            boarding_code__in=codes
        )
        lines = lines.distinct()

    if codes:
        by_code: dict[str, Line] = {}
        for line in lines:
            by_code.setdefault(line.code, line)
            if line.boarding_code:
                by_code.setdefault(line.boarding_code, line)
        ordered = [by_code[code] for code in codes if code in by_code]
        selected = ordered[:limit]
    else:
        selected = list(lines[:limit])

    payloads = [line_payload(line) for line in selected]
    cache.set(cache_key, payloads, CATALOG_CACHE_TTL_SECONDS)
    return payloads, False


def resolve_line(city: City, identifier: str) -> Line:
    """Resolve uma linha por UUID, `codigoLinha`, `sgLinha` ou alias.

    Códigos ambíguos retornam `409 ambiguous_line_code`, conforme RF-006.
    """

    from uuid import UUID

    normalized = (identifier or "").strip()
    matches: list[Line] = []

    try:
        uuid_value = UUID(normalized)
    except (ValueError, AttributeError):
        uuid_value = None

    if uuid_value is not None:
        match = Line.objects.filter(
            city=city, pk=uuid_value, is_active=True
        ).select_related("source").first()
        if match is not None:
            return match

    text = normalize_search_text(normalized)
    if text:
        matches = list(
            Line.objects.filter(city=city, is_active=True)
            .select_related("source")
            .filter(
                models.Q(code__iexact=normalized)
                | models.Q(boarding_code__iexact=normalized)
                | models.Q(aliases__alias__iexact=normalized)
            )
            .distinct()
        )

    if not matches:
        raise ApiError(
            "Linha não encontrada.",
            code="line_not_found",
            title="Linha não encontrada",
            status_code=404,
        )
    if len(matches) > 1:
        raise ApiError(
            "Esse código identifica mais de uma linha.",
            code="ambiguous_line_code",
            title="Código de linha ambíguo",
            status_code=409,
        )
    return matches[0]


def resolve_stop(city: City, identifier: str) -> Stop:
    """Resolve uma parada por UUID ou código, com erro estável."""

    from uuid import UUID

    normalized = (identifier or "").strip()
    try:
        uuid_value = UUID(normalized)
    except (ValueError, AttributeError):
        uuid_value = None

    if uuid_value is not None:
        stop = Stop.objects.filter(
            city=city, pk=uuid_value, is_active=True
        ).first()
    else:
        stop = Stop.objects.filter(
            city=city, code__iexact=normalized, is_active=True
        ).first()

    if stop is None:
        raise ApiError(
            "Parada não encontrada.",
            code="stop_not_found",
            title="Parada não encontrada",
            status_code=404,
        )
    return stop


def line_stops(line: Line) -> list[dict]:
    """Retorna as paradas da linha na ordem do itinerário."""

    from .models import LineStop

    relations = (
        LineStop.objects.filter(line=line)
        .select_related("stop")
        .order_by("direction", "sequence")
    )
    return [stop_payload(relation.stop) for relation in relations]


def route_for_line(line: Line) -> dict | None:
    """Retorna o traçado (`direction=0`) da linha, ou `None` se inexistente."""

    route = Route.objects.filter(line=line, direction=0).first()
    return route_payload(route) if route else None

