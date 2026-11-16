"""Erros da API no formato Problem Details (RFC 9457).

Todo erro carrega um `code` estável. O app decide o que fazer pelo código, nunca
pelo texto, conforme RF-017.
"""

from __future__ import annotations

from typing import Any

from django.http import JsonResponse
from rest_framework import status
from rest_framework.exceptions import (
    APIException,
    AuthenticationFailed,
    MethodNotAllowed,
    NotAuthenticated,
    NotFound,
    PermissionDenied,
    Throttled,
    ValidationError,
)
from rest_framework.views import exception_handler as drf_exception_handler

PROBLEM_BASE_URL = "https://api.meubuzu.com/problems"


class ApiError(APIException):
    """Erro de domínio com código estável e campos extras opcionais."""

    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "Requisição inválida."
    default_code = "invalid_request"
    default_title = "Requisição inválida"

    def __init__(
        self,
        detail: str | None = None,
        *,
        code: str | None = None,
        title: str | None = None,
        status_code: int | None = None,
        extra: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(detail=detail or self.default_detail)
        self.api_code = code or self.default_code
        self.api_title = title or self.default_title
        if status_code is not None:
            self.status_code = status_code
        self.extra = extra or {}


def problem_response(
    *,
    code: str,
    title: str,
    status_code: int,
    detail: str,
    extra: dict[str, Any] | None = None,
) -> JsonResponse:
    body: dict[str, Any] = {
        "type": f"{PROBLEM_BASE_URL}/{code.replace('_', '-')}",
        "title": title,
        "status": status_code,
        "code": code,
        "detail": detail,
    }
    if extra:
        body.update(extra)
    return JsonResponse(body, status=status_code, content_type="application/problem+json")


def _first_message(detail: Any) -> str:
    if isinstance(detail, dict):
        for value in detail.values():
            return _first_message(value)
    if isinstance(detail, list) and detail:
        return _first_message(detail[0])
    return str(detail)


def api_exception_handler(exc, context):
    """Converte exceções do DRF em Problem Details com código estável."""

    if isinstance(exc, ApiError):
        return problem_response(
            code=exc.api_code,
            title=exc.api_title,
            status_code=exc.status_code,
            detail=str(exc.detail),
            extra=exc.extra,
        )

    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    code = "error"
    title = "Erro na requisição"
    extra: dict[str, Any] = {}

    if isinstance(exc, ValidationError):
        code = "invalid_request"
        title = "Dados inválidos"
        extra["errors"] = exc.detail
    elif isinstance(exc, NotAuthenticated):
        code = "not_authenticated"
        title = "Autenticação necessária"
    elif isinstance(exc, AuthenticationFailed):
        code = "invalid_access_token"
        title = "Token de acesso inválido"
    elif isinstance(exc, PermissionDenied):
        code = "permission_denied"
        title = "Acesso negado"
    elif isinstance(exc, NotFound):
        code = "not_found"
        title = "Recurso não encontrado"
    elif isinstance(exc, MethodNotAllowed):
        code = "method_not_allowed"
        title = "Método não permitido"
    elif isinstance(exc, Throttled):
        code = "rate_limited"
        title = "Muitas requisições"
        extra["retryAfter"] = exc.wait

    detail = _first_message(getattr(exc, "detail", None) or response.data)
    response.data = None
    response.content_type = "application/problem+json"
    return problem_response(
        code=code,
        title=title,
        status_code=response.status_code,
        detail=detail,
        extra=extra,
    )
