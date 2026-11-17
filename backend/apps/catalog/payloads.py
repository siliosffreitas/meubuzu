"""Formato público do catálogo (camelCase, contrato do app)."""

from __future__ import annotations

from .models import City, Line, Route, Stop


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


def stop_payload(stop: Stop) -> dict:
    """Formato público de uma parada usado pelos endpoints do catálogo."""

    return {
        "id": str(stop.id),
        "code": stop.code,
        "name": stop.name,
        "address": stop.address,
        "latitude": float(stop.latitude),
        "longitude": float(stop.longitude),
        "isActive": stop.is_active,
        "dataMode": stop.source.data_mode if stop.source_id else None,
        "updatedAt": stop.updated_at.isoformat() if stop.updated_at else None,
    }


def line_payload(line: Line) -> dict:
    """Formato público de uma linha usado pelos endpoints do catálogo."""

    return {
        "id": str(line.id),
        "code": line.code,
        "boardingCode": line.boarding_code,
        "name": line.name,
        "origin": line.origin,
        "destination": line.destination,
        "isActive": line.is_active,
        "dataMode": line.source.data_mode if line.source_id else None,
        "updatedAt": line.updated_at.isoformat() if line.updated_at else None,
    }


def route_payload(route: Route) -> dict:
    """Formato público do traçado de uma linha."""

    return {
        "lineId": str(route.line_id),
        "direction": route.direction,
        "coordinates": route.path,
        "updatedAt": route.updated_at.isoformat() if route.updated_at else None,
    }
