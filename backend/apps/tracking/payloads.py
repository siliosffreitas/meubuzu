"""Formato público das posições (camelCase, contrato do app)."""

from __future__ import annotations

from datetime import UTC, datetime


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def position_payload(
    *,
    line_id: str,
    boarding_code: str,
    vehicle_code: str,
    latitude: float,
    longitude: float,
    captured_at: datetime,
    generated_at: datetime | None,
    received_at: datetime,
    is_stale: bool,
) -> dict:
    return {
        "lineId": line_id,
        "boardingCode": boarding_code,
        "vehicleCode": vehicle_code,
        "latitude": latitude,
        "longitude": longitude,
        "capturedAt": _iso(captured_at),
        "generatedAt": _iso(generated_at),
        "receivedAt": _iso(received_at),
        "speed": None,
        "heading": None,
        "isStale": is_stale,
    }


def line_positions_payload(
    *,
    line_id: str,
    boarding_code: str,
    requested_id: str,
    source: str,
    data_mode: str,
    is_stale: bool,
    source_status: str,
    positions: list[dict],
) -> dict:
    return {
        "lineId": line_id,
        "boardingCode": boarding_code,
        "requestedId": requested_id,
        "source": source,
        "dataMode": data_mode,
        "isStale": is_stale,
        "sourceStatus": source_status,
        "positions": positions,
    }


def positions_payload(
    *,
    city_slug: str,
    generated_at: datetime,
    source: str,
    data_mode: str,
    lines: list[dict],
    unresolved_lines: list[str],
) -> dict:
    return {
        "city": city_slug,
        "generatedAt": _iso(generated_at),
        "source": source,
        "dataMode": data_mode,
        "lines": lines,
        "unresolvedLines": unresolved_lines,
    }
