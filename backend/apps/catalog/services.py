from __future__ import annotations

from apps.common.exceptions import ApiError

from .models import City


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
