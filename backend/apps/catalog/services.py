from __future__ import annotations

import hashlib
import json
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.core.cache import cache

from apps.common.exceptions import ApiError

from .models import City, Stop
from .payloads import stop_payload
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
