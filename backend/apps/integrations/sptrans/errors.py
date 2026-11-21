"""Erros estáveis das integrações externas.

As mensagens são seguras para log: nunca incluem token, URL de autenticação ou
payload bruto da fonte.
"""

from __future__ import annotations


class IntegrationError(Exception):
    """Falha genérica de uma integração externa."""


class SPTransError(IntegrationError):
    """Falha ao consultar a API Olho Vivo."""


class SPTransConfigurationError(SPTransError):
    """Token ausente ou configuração inválida."""


class SPTransAuthError(SPTransError):
    """A API recusou a autenticação."""


class SPTransRateLimitError(SPTransError):
    """A API aplicou rate limit mesmo após as tentativas."""


class SPTransUnavailable(SPTransError):
    """A API não respondeu ou devolveu erro persistente."""


class GtfsError(IntegrationError):
    """Arquivo GTFS ausente, inválido ou inconsistente."""
