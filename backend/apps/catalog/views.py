from __future__ import annotations

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import City
from .payloads import city_payload
from .services import get_active_city


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
