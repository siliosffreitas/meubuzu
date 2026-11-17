"""Formato das respostas de conta.

Os nomes seguem o contrato do app (camelCase). A cidade selecionada vem da
preferência do usuário; cotas e billing ainda são neutros.
"""

from __future__ import annotations

from datetime import datetime

from apps.catalog.payloads import city_payload

from .models import User, UserPreference


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


def preferences_payload(user: User, *, preference: UserPreference | None = None) -> dict:
    if preference is None:
        preference = getattr(user, "preference", None)

    selected_city = preference.selected_city if preference is not None else None
    return {
        "selectedCity": city_payload(selected_city),
        "version": preference.version if preference is not None else 0,
        "updatedAt": _iso(preference.updated_at) if preference is not None else None,
    }


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
        "preferences": preferences_payload(user),
        "entitlements": entitlements_payload(),
    }
