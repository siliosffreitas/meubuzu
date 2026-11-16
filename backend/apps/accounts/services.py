"""Regras de autenticação: código de acesso, sessões e rate limit."""

from __future__ import annotations

import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.core.cache import cache
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status

from apps.common.exceptions import ApiError

from .emails import send_access_code
from .models import EmailCode, User
from .tokens import (
    InvalidRefreshToken,
    RefreshTokenReuseDetected,
    create_refresh_session,
    issue_access_token,
    revoke_session,
    rotate_refresh_token,
)

logger = logging.getLogger(__name__)

GENERIC_REQUEST_MESSAGE = "Se o e-mail existir, enviaremos um código."
RATE_LIMIT_WINDOW_SECONDS = 3600


def normalize_email(email: str) -> str:
    return email.strip().lower()


def _increment_counter(key: str, window_seconds: int) -> int:
    if cache.add(key, 1, timeout=window_seconds):
        return 1
    try:
        return cache.incr(key)
    except ValueError:
        # A chave expirou entre o add e o incr.
        cache.set(key, 1, timeout=window_seconds)
        return 1


def _enforce_rate_limit(
    *, key: str, limit: int, window_seconds: int, title: str, retry_after: int | None = None
) -> None:
    count = _increment_counter(key, window_seconds)
    if count > limit:
        extra = {"retryAfter": retry_after} if retry_after else {}
        raise ApiError(
            "Muitas solicitações. Tente novamente mais tarde.",
            code="rate_limited",
            title=title,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            extra=extra,
        )


def request_access_code(
    *, email: str, ip: str | None = None, user_agent: str = ""
) -> None:
    """Cria e envia um código de 6 dígitos, com cooldown e rate limit."""

    email = normalize_email(email)
    now = timezone.now()
    cooldown = settings.OTP_RESEND_COOLDOWN_SECONDS

    last_code = EmailCode.objects.filter(email=email).order_by("-created_at").first()
    if last_code is not None:
        elapsed = (now - last_code.created_at).total_seconds()
        if elapsed < cooldown:
            raise ApiError(
                "Aguarde antes de pedir um novo código.",
                code="rate_limited",
                title="Muitas solicitações",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                extra={"retryAfter": int(cooldown - elapsed) + 1},
            )

    _enforce_rate_limit(
        key=f"otp:email:{email}",
        limit=settings.OTP_RATE_LIMIT_PER_EMAIL,
        window_seconds=RATE_LIMIT_WINDOW_SECONDS,
        title="Muitas solicitações para este e-mail",
    )
    if ip:
        _enforce_rate_limit(
            key=f"otp:ip:{ip}",
            limit=settings.OTP_RATE_LIMIT_PER_IP,
            window_seconds=RATE_LIMIT_WINDOW_SECONDS,
            title="Muitas solicitações deste endereço",
        )

    code = f"{secrets.randbelow(1_000_000):06d}"

    # Apenas o código mais recente vale.
    EmailCode.objects.filter(email=email, consumed_at__isnull=True).update(consumed_at=now)

    EmailCode.objects.create(
        email=email,
        code_hash=make_password(code, hasher="argon2"),
        expires_at=now + timedelta(seconds=settings.OTP_TTL_SECONDS),
        ip=ip,
        user_agent=user_agent[:500],
    )

    try:
        send_access_code(email, code)
    except Exception:
        # Nunca registre o código. Falha de e-mail não revela existência da conta.
        logger.exception("Falha ao enviar e-mail de código de acesso")


def verify_access_code(*, email: str, code: str) -> User:
    """Valida o código, consome o registro e devolve o usuário."""

    email = normalize_email(email)
    now = timezone.now()

    latest = EmailCode.objects.filter(email=email).order_by("-created_at").first()
    if latest is None:
        raise ApiError(
            "Código inválido.",
            code="invalid_code",
            title="Código inválido",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    if latest.is_consumed:
        raise ApiError(
            "Este código já foi utilizado.",
            code="code_already_used",
            title="Código já utilizado",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    if latest.is_expired:
        raise ApiError(
            "Este código expirou. Peça um novo.",
            code="code_expired",
            title="Código expirado",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    if latest.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise ApiError(
            "Muitas tentativas. Peça um novo código.",
            code="too_many_attempts",
            title="Tentativas excedidas",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    EmailCode.objects.filter(pk=latest.pk).update(attempts=F("attempts") + 1)
    latest.refresh_from_db(fields=["attempts"])

    if not check_password(code, latest.code_hash):
        if latest.attempts >= settings.OTP_MAX_ATTEMPTS:
            raise ApiError(
                "Muitas tentativas. Peça um novo código.",
                code="too_many_attempts",
                title="Tentativas excedidas",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        raise ApiError(
            "Código inválido.",
            code="invalid_code",
            title="Código inválido",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    consumed = EmailCode.objects.filter(pk=latest.pk, consumed_at__isnull=True).update(
        consumed_at=now
    )
    if not consumed:
        raise ApiError(
            "Este código já foi utilizado.",
            code="code_already_used",
            title="Código já utilizado",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    with transaction.atomic():
        user, created = User.objects.get_or_create(email=email)
        if created:
            user.set_unusable_password()
            user.save(update_fields=["password"])
        user.mark_email_verified()

    return user


def start_session(user: User, *, device_id: str = "") -> tuple[str, str]:
    """Cria a sessão de refresh e devolve (access_token, refresh_token)."""

    raw_refresh, session = create_refresh_session(user, device_id=device_id)
    return issue_access_token(user.id, session.id), raw_refresh


def refresh_access_token(*, raw_refresh: str, device_id: str = "") -> tuple[User, str, str]:
    try:
        return rotate_refresh_token(raw_refresh, device_id=device_id)
    except RefreshTokenReuseDetected as exc:
        raise ApiError(
            "Refresh token reutilizado. Entre novamente.",
            code="refresh_reuse_detected",
            title="Sessão inválida",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc
    except InvalidRefreshToken as exc:
        raise ApiError(
            "Refresh token inválido ou expirado.",
            code="invalid_refresh_token",
            title="Sessão inválida",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc


def logout(*, session_id, user: User) -> None:
    revoke_session(session_id=session_id, user=user)
