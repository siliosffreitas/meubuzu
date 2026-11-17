"""Endpoints de posições do rastreamento."""

from __future__ import annotations

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.catalog.views import CityScopedAPIView

from .services import get_positions_payload, parse_line_codes


class LinePositionsView(CityScopedAPIView):
    """Posições atuais de uma ou mais linhas da cidade.

    O parâmetro é sempre o `sgLinha` (por exemplo, `0301`), tanto em `?codes=`
    quanto no caminho singular. A rota coletiva é usada pelo app para consultar
    todas as linhas acompanhadas em uma única requisição.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, city_slug: str, sg_linha: str | None = None):
        if sg_linha is not None:
            requested = [sg_linha]
            strict = True
        else:
            requested = parse_line_codes(request.query_params.get("codes"))
            strict = False

        payload, cache_hit = get_positions_payload(
            self.city,
            requested,
            user=request.user,
            strict=strict,
        )
        response = Response(payload)
        response["X-Tracking-Cache"] = "HIT" if cache_hit else "MISS"
        return response
