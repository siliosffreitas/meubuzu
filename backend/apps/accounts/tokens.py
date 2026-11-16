"""Emissão e rotação de tokens.

Access token: JWT curto com `sub` (usuário) e `sid` (sessão de refresh).
Refresh token: valor opaco aleatório; o banco guarda apenas o SHA-256.
"""

from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import timedelta

import jwt
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import RefreshSession, User


class TokenError(Exception):
    """Erro genérico de token."""

    code = "invalid_token"


class InvalidRefreshToken(TokenError):
    code = "invalid_refresh_token"


class RefreshTokenReuseDetected(TokenError):
    code = "refresh_reuse_detected"


def hash_refresh_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def issue_access_token(user_id, session_id) -> str:
    now = timezone.now()
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "typ": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=settings.ACCESS_TOKEN_TTL_SECONDS)).timestamp()),
        "jti": uuid.uuid4().hex,
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def decode_access_token(raw_token: str) -> dict:
    return jwt.decode(
        raw_token,
        settings.SECRET_KEY,
        algorithms=["HS256"],
        options={"require": ["exp", "sub", "sid"]},
    )


def create_refresh_session(
    user: User,
    *,
    device_id: str = "",
    family_id: uuid.UUID | None = None,
) -> tuple[str, RefreshSession]:
    raw_token = secrets.token_urlsafe(48)
    session = RefreshSession.objects.create(
        user=user,
        token_hash=hash_refresh_token(raw_token),
        family_id=family_id or uuid.uuid4(),
        device_id=device_id[:128],
        expires_at=timezone.now() + timedelta(seconds=settings.REFRESH_TOKEN_TTL_SECONDS),
    )
    return raw_token, session


def rotate_refresh_token(raw_token: str, *, device_id: str = "") -> tuple[User, str, str]:
    """Valida, revoga o token atual e emite um novo par.

    Reuso de token já rotacionado revoga toda a família, conforme RF-003. A
    revogação acontece fora da transação para não ser desfeita pelo rollback
    causado pela exceção de reuso.
    """

    now = timezone.now()
    reuse_family_id: uuid.UUID | None = None

    with transaction.atomic():
        session = (
            RefreshSession.objects.select_for_update()
            .select_related("user")
            .filter(token_hash=hash_refresh_token(raw_token))
            .first()
        )

        if session is None:
            raise InvalidRefreshToken("Refresh token inválido.")

        if session.revoked_at is not None:
            if session.replaced_by_id is None:
                # Revogado explicitamente (logout), não é reuso.
                raise InvalidRefreshToken("Refresh token revogado.")
            # Token rotacionado sendo reutilizado: revoga a família depois do commit.
            reuse_family_id = session.family_id
        else:
            if session.expires_at <= now:
                raise InvalidRefreshToken("Refresh token expirado.")

            if not session.user.is_active:
                raise InvalidRefreshToken("Conta inativa.")

            new_raw, new_session = create_refresh_session(
                session.user,
                device_id=device_id or session.device_id,
                family_id=session.family_id,
            )

            session.last_used_at = now
            session.revoked_at = now
            session.replaced_by = new_session
            session.save(update_fields=["last_used_at", "revoked_at", "replaced_by"])

            access_token = issue_access_token(session.user_id, new_session.id)
            user = session.user

    if reuse_family_id is not None:
        RefreshSession.objects.filter(
            family_id=reuse_family_id, revoked_at__isnull=True
        ).update(revoked_at=now)
        raise RefreshTokenReuseDetected("Refresh token já utilizado.")

    return user, access_token, new_raw


def revoke_session(*, session_id, user: User) -> None:
    RefreshSession.objects.filter(pk=session_id, user=user, revoked_at__isnull=True).update(
        revoked_at=timezone.now()
    )
