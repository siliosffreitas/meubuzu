from __future__ import annotations

from uuid import UUID

from django.db.models import Case, IntegerField, Q, Value, When
from django.db.models.functions import Cast
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.services import get_active_city, resolve_line
from apps.common.exceptions import ApiError

from .models import Favorite
from .payloads import favorite_payload
from .serializers import CreateFavoriteSerializer

_FAVORITE_SELECT = ("line__city", "line__source")


def _find_favorite(user, identifier: str) -> Favorite | None:
    """Localiza um favorito do usuário por UUID, `codigoLinha` ou `sgLinha`."""

    normalized = (identifier or "").strip()
    queryset = Favorite.objects.filter(user=user).select_related(*_FAVORITE_SELECT)

    try:
        uuid_value = UUID(normalized)
    except (ValueError, AttributeError):
        uuid_value = None

    if uuid_value is not None:
        return queryset.filter(line_id=uuid_value).first()
    return queryset.filter(
        Q(line__code__iexact=normalized) | Q(line__boarding_code__iexact=normalized)
    ).first()


class FavoritesView(APIView):
    """Lista e adiciona favoritos da conta autenticada (RF-011)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        favorites = (
            Favorite.objects.filter(user=request.user)
            .select_related(*_FAVORITE_SELECT)
            .annotate(
                boarding_blank=Case(
                    When(
                        Q(line__boarding_code__isnull=True) | Q(line__boarding_code=""),
                        then=Value(1),
                    ),
                    default=Value(0),
                    output_field=IntegerField(),
                ),
                boarding_num=Case(
                    When(
                        line__boarding_code__regex=r"^\d+$",
                        then=Cast("line__boarding_code", IntegerField()),
                    ),
                    default=Value(None),
                    output_field=IntegerField(),
                ),
            )
            .order_by(
                "line__city__name",
                "line__city__slug",
                "boarding_blank",
                "boarding_num",
                "line__boarding_code",
                "line__code",
                "line__name",
                "id",
            )
        )
        return Response({"favorites": [favorite_payload(favorite) for favorite in favorites]})

    def post(self, request):
        serializer = CreateFavoriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        city = get_active_city(serializer.validated_data["citySlug"])
        line = resolve_line(city, serializer.validated_data["lineId"])

        # `get_or_create` é idempotente; a constraint única impede duplicatas
        # mesmo quando duas requisições chegam ao mesmo tempo.
        favorite, created = Favorite.objects.get_or_create(user=request.user, line=line)
        favorite = Favorite.objects.select_related(*_FAVORITE_SELECT).get(pk=favorite.pk)

        return Response(
            favorite_payload(favorite),
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class FavoriteDetailView(APIView):
    """Remove um favorito da conta autenticada."""

    permission_classes = [IsAuthenticated]

    def delete(self, request, line_id: str):
        favorite = _find_favorite(request.user, line_id)
        if favorite is None:
            raise ApiError(
                "Favorito não encontrado.",
                code="favorite_not_found",
                title="Favorito não encontrado",
                status_code=404,
            )
        favorite.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
