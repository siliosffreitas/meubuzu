"""Formato público dos favoritos (camelCase, contrato do app)."""

from __future__ import annotations

from collections.abc import Iterable

from apps.catalog.payloads import city_payload, line_payload

from .models import Favorite


def favorite_item_payload(favorite: Favorite) -> dict:
    """Linha favorita de um grupo, sem repetir os dados da cidade."""

    return {
        "boardingCode": favorite.line.boarding_code,
        "line": line_payload(favorite.line),
        "createdAt": favorite.created_at.isoformat() if favorite.created_at else None,
    }


def favorites_payload(favorites: Iterable[Favorite]) -> list[dict]:
    """Favoritos agrupados por cidade, mantendo a ordem da consulta."""

    groups: dict[str, dict] = {}
    for favorite in favorites:
        city = favorite.line.city
        group = groups.get(city.slug)
        if group is None:
            group = {"city": city_payload(city), "lines": []}
            groups[city.slug] = group
        group["lines"].append(favorite_item_payload(favorite))
    return list(groups.values())


def favorite_payload(favorite: Favorite) -> dict:
    """Favorito identificado por `citySlug` + `boardingCode`, sem IDs internos."""

    return {
        "boardingCode": favorite.line.boarding_code,
        "line": line_payload(favorite.line),
        "city": city_payload(favorite.line.city),
        "createdAt": favorite.created_at.isoformat() if favorite.created_at else None,
    }
