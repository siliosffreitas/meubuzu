"""Formato público de uma cidade (camelCase, contrato do app)."""

from __future__ import annotations

from .models import City


def city_payload(city: City | None) -> dict | None:
    if city is None:
        return None
    return {
        "slug": city.slug,
        "name": city.name,
        "label": city.label,
        "state": city.state,
        "country": city.country,
        "timezone": city.timezone,
        "center": {
            "latitude": float(city.latitude),
            "longitude": float(city.longitude),
        },
        "isActive": city.is_active,
        "coverageNote": city.coverage_note or None,
    }
