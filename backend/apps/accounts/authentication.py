"""Autenticação por Bearer access token (JWT)."""

from __future__ import annotations

from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed

from .models import User
from .tokens import decode_access_token


class AccessTokenAuthentication(BaseAuthentication):
    keyword = "Bearer"

    def authenticate(self, request):
        header = get_authorization_header(request).split()
        if not header or header[0].lower() != self.keyword.lower().encode():
            return None

        if len(header) != 2:
            raise AuthenticationFailed("Cabeçalho de autorização malformado.")

        try:
            payload = decode_access_token(header[1].decode("utf-8"))
        except Exception as exc:
            raise AuthenticationFailed("Token inválido ou expirado.") from exc

        if payload.get("typ") != "access":
            raise AuthenticationFailed("Tipo de token inválido.")

        user = User.objects.filter(pk=payload.get("sub"), is_active=True).first()
        if user is None:
            raise AuthenticationFailed("Conta não encontrada.")

        return user, payload

    def authenticate_header(self, request):
        return self.keyword
