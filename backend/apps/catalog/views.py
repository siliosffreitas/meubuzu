from __future__ import annotations

from django.core.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import ApiError

from .models import City, Line, Stop
from .payloads import city_payload, line_payload, stop_payload
from .services import (
    MAX_CODES,
    cached_lines,
    cached_stops,
    get_active_city,
    line_stops,
    parse_bbox,
    resolve_line,
    resolve_stop,
    route_for_line,
)


class CityListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        cities = City.objects.filter(is_active=True).order_by("name")
        return Response({"cities": [city_payload(city) for city in cities]})


class CityDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str):
        return Response(city_payload(get_active_city(city_slug)))


class CityScopedAPIView(APIView):
    """Base dos endpoints de catálogo e rastreamento escopados por cidade.

    Toda rota `/v1/cities/{citySlug}/...` deve herdar desta classe para que a
    cidade exista, esteja ativa e fique disponível em `self.city`.
    """

    city: City

    def initial(self, request, *args, **kwargs):
        self.city = get_active_city(kwargs["city_slug"])
        super().initial(request, *args, **kwargs)


class StopListView(CityScopedAPIView):
    """Paradas da cidade, filtráveis por bbox, busca textual e códigos.

    As respostas são servidas do cache Redis (com chave versionada por cidade),
    conforme a decisão de armazenar o catálogo quente em cache.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str):
        bbox_raw = request.query_params.get("bbox")
        bbox = parse_bbox(bbox_raw) if bbox_raw else None

        query = request.query_params.get("q") or None
        if query and len(query) > 100:
            raise ApiError(
                "A busca deve ter até 100 caracteres.",
                code="invalid_query",
                title="Busca inválida",
                status_code=400,
            )

        codes_raw = request.query_params.get("codes")
        codes = (
            [code.strip() for code in codes_raw.split(",") if code.strip()]
            if codes_raw
            else None
        )
        if codes and len(codes) > MAX_CODES:
            raise ApiError(
                f"Informe no máximo {MAX_CODES} códigos.",
                code="invalid_codes",
                title="Códigos inválidos",
                status_code=400,
            )

        stops, cache_hit = cached_stops(
            self.city.slug,
            bbox=bbox,
            query=query,
            codes=codes,
        )
        response = Response({"stops": stops, "count": len(stops)})
        response["X-Catalog-Cache"] = "HIT" if cache_hit else "MISS"
        return response


class StopDetailView(CityScopedAPIView):
    """Detalhes de uma parada da cidade."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, stop_id: str):
        try:
            stop = Stop.objects.select_related("source").get(
                city=self.city,
                pk=stop_id,
                is_active=True,
            )
        except (Stop.DoesNotExist, ValidationError, ValueError) as exc:
            raise ApiError(
                "Parada não encontrada.",
                code="stop_not_found",
                title="Parada não encontrada",
                status_code=404,
            ) from exc

        return Response(stop_payload(stop))


class LineListView(CityScopedAPIView):
    """Busca de linhas da cidade por código, nome ou código de embarque."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str):
        query = request.query_params.get("q") or None
        codes_raw = request.query_params.get("codes")

        if query:
            query = query.strip()
            if len(query) > 100:
                raise ApiError(
                    "A busca deve ter até 100 caracteres.",
                    code="invalid_query",
                    title="Busca inválida",
                    status_code=400,
                )
            if not query:
                query = None

        codes = (
            [code.strip() for code in codes_raw.split(",") if code.strip()]
            if codes_raw
            else None
        )
        if codes and len(codes) > MAX_CODES:
            raise ApiError(
                f"Informe no máximo {MAX_CODES} códigos.",
                code="invalid_codes",
                title="Códigos inválidos",
                status_code=400,
            )

        if not query and not codes:
            raise ApiError(
                "Informe q ou codes para buscar linhas.",
                code="invalid_query",
                title="Busca inválida",
                status_code=400,
            )

        lines, cache_hit = cached_lines(
            self.city.slug,
            query=query,
            codes=codes,
        )
        response = Response({"lines": lines, "count": len(lines)})
        response["X-Catalog-Cache"] = "HIT" if cache_hit else "MISS"
        return response


class LineDetailView(CityScopedAPIView):
    """Detalhes de uma linha (UUID, `codigoLinha`, `sgLinha` ou alias)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, line_id: str):
        line = resolve_line(self.city, line_id)
        return Response(line_payload(line))


class LineStopsView(CityScopedAPIView):
    """Paradas da linha na ordem do itinerário."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, line_id: str):
        line = resolve_line(self.city, line_id)
        stops = line_stops(line)
        return Response({"stops": stops, "count": len(stops)})


class LineRouteView(CityScopedAPIView):
    """Traçado geográfico da linha, ou `route: null` quando inexistente."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, line_id: str):
        line = resolve_line(self.city, line_id)
        route = route_for_line(line)
        return Response(route if route is not None else {"route": None})


class StopLinesView(CityScopedAPIView):
    """Linhas que passam por uma parada da cidade."""

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, stop_id: str):
        stop = resolve_stop(self.city, stop_id)
        lines = line_payloads_for_stop(stop)
        return Response({"lines": lines, "count": len(lines)})


def line_payloads_for_stop(stop: Stop) -> list[dict]:
    """Linhas ativas que passam pela parada, em ordem previsível."""

    line_ids = (
        stop.line_stops.filter(line__is_active=True)
        .values_list("line", flat=True)
        .distinct()
    )
    queryset = Line.objects.filter(pk__in=line_ids).select_related("source").order_by("code")
    return [line_payload(line) for line in queryset]
