"""Lock distribuído simples sobre o cache.

Usado para impedir execuções sobrepostas da importação de catálogo e do crawl
de posições. Funciona com Redis e com o cache em memória dos testes.
"""

from __future__ import annotations

import uuid
from collections.abc import Iterator
from contextlib import contextmanager

from django.core.cache import cache


class LockNotAcquired(RuntimeError):
    """Outra execução já está em andamento."""


@contextmanager
def cache_lock(key: str, *, timeout: int) -> Iterator[None]:
    token = uuid.uuid4().hex
    if not cache.add(key, token, timeout=timeout):
        raise LockNotAcquired(f"Lock ocupado: {key}")
    try:
        yield
    finally:
        if cache.get(key) == token:
            cache.delete(key)
