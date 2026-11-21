"""Cálculos geográficos usados pelo rastreamento."""

from __future__ import annotations

from math import atan2, cos, degrees, radians, sin


def heading_between(
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
