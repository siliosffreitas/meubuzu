from __future__ import annotations

from django.core.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import ApiError

from .models import City, Stop
from .payloads import city_payload, stop_payload
from .services import MAX_CODES, cached_stops, get_active_city, parse_bbox


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
