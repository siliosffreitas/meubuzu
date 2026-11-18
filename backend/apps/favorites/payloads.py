"""Formato público dos favoritos (camelCase, contrato do app)."""

from __future__ import annotations

from apps.catalog.payloads import city_payload, line_payload

from .models import Favorite


def favorite_payload(favorite: Favorite) -> dict:
    return {
        "id": str(favorite.id),
        "lineId": str(favorite.line_id),
        "line": line_payload(favorite.line),
        "city": city_payload(favorite.line.city),
        "createdAt": favorite.created_at.isoformat() if favorite.created_at else None,
    }
