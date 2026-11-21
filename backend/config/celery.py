"""Aplicação Celery do backend do MeuBuzu.

O worker executa as tarefas de importação de catálogo, ingestão de posições e
manutenção das partições do histórico. O beat agenda as execuções; nenhuma
tarefa é disparada pelo app.
"""

from __future__ import annotations

import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("meubuzu")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
