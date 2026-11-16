"""Formato das respostas de conta.

Os nomes seguem o contrato do app (camelCase). Enquanto cidade, cotas e billing
não existem, os campos correspondentes são neutros e explícitos.
"""

from __future__ import annotations

from datetime import datetime

from .models import User


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.isoformat().replace("+00:00", "Z")


def user_payload(user: User) -> dict:
    return {
        "id": str(user.id),
        "email": user.email,
        "emailVerifiedAt": _iso(user.email_verified_at),
        "createdAt": _iso(user.created_at),
    }


def preferences_payload() -> dict:
    # A cidade será implementada junto do catálogo (RF-019).
    return {"selectedCity": None, "version": 0, "updatedAt": None}


def entitlements_payload() -> dict:
    # Sem billing e sem cota implementados, a conta é catálogo somente leitura.
    return {
        "accessLevel": "catalog_only",
        "isPaid": False,
        "isTrial": False,
        "trialEndsAt": None,
        "subscriptionEndsAt": None,
        "willRenew": False,
        "managementUrl": None,
        "maxActiveLines": 0,
        "maxFavorites": 0,
        "dailyTrackingLimit": 0,
        "trackingUsedToday": 0,
        "trackingRemainingToday": 0,
        "canTrack": False,
        "canViewPositions": False,
        "canManageFavorites": False,
        "quotaDate": None,
        "quotaTimezone": None,
    }


def session_payload(user: User, *, access_token: str, refresh_token: str) -> dict:
    return {
        "accessToken": access_token,
        "refreshToken": refresh_token,
        "user": user_payload(user),
        "preferences": preferences_payload(),
        "entitlements": entitlements_payload(),
    }
