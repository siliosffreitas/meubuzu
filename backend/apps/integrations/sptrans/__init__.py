"""Integração com a API Olho Vivo e com o GTFS da SPTrans."""

from __future__ import annotations

from .client import (
    LineRecord,
    SPTransClient,
    StopRecord,
    VehiclePositionRecord,
    public_line_code,
)
from .errors import (
    GtfsError,
    SPTransAuthError,
    SPTransConfigurationError,
    SPTransError,
    SPTransRateLimitError,
    SPTransUnavailable,
)
from .gtfs import GtfsFeed, GtfsRoute, GtfsValidation

__all__ = [
    "GtfsError",
    "GtfsFeed",
    "GtfsRoute",
    "GtfsValidation",
    "LineRecord",
    "SPTransAuthError",
    "SPTransClient",
    "SPTransConfigurationError",
    "SPTransError",
    "SPTransRateLimitError",
    "SPTransUnavailable",
    "StopRecord",
    "VehiclePositionRecord",
    "public_line_code",
]
