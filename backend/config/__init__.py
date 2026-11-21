"""Inicialização do projeto.

Importa a aplicação Celery para que `@shared_task` funcione em qualquer módulo
carregado depois do Django.
"""

from __future__ import annotations

from .celery import app as celery_app

__all__ = ("celery_app",)
