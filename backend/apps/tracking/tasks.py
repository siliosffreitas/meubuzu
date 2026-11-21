"""Tarefas Celery de rastreamento e manutenção do histórico."""

from __future__ import annotations

import logging

from celery import shared_task
from django.conf import settings

from apps.catalog.models import City
from apps.common.locks import LockNotAcquired, cache_lock
from apps.integrations.sptrans.client import SPTransClient

from .crawler import crawl_positions, record_source_error, record_source_success
from .models import TrackingSource
from .partitions import drop_expired_partitions, ensure_partitions, trim_expired_rows

logger = logging.getLogger(__name__)


@shared_task(name="apps.tracking.tasks.crawl_sptrans_positions_task")
def crawl_sptrans_positions_task(city_slug: str = "sao-paulo") -> dict:
    """Ingestão de posições a cada 30 segundos."""

    city = City.objects.filter(slug=city_slug).first()
    if city is None:
        return {"city": city_slug, "status": "city_not_found"}

    source = TrackingSource.objects.filter(
        city=city, is_active=True, kind=TrackingSource.Kind.SPTRANS_API
    ).first()
    if source is None:
        return {"city": city_slug, "status": "source_not_configured"}

    try:
        with cache_lock(
            key=f"tracking:crawl:{city.slug}",
            timeout=int(getattr(settings, "TRACKING_CRAWL_LOCK_SECONDS", 25)),
        ):
            result = crawl_positions(
                city=city, source=source, client=SPTransClient()
            )
    except LockNotAcquired:
        return {"city": city_slug, "status": "locked"}
    except Exception as exc:  # noqa: BLE001 - registra e não derruba o beat
        record_source_error(source, exc)
        logger.exception("Crawl de posições falhou para %s", city_slug)
        return {"city": city_slug, "status": "error"}

    record_source_success(source)
    return result.as_dict()


@shared_task(name="apps.tracking.tasks.maintain_tracking_partitions_task")
def maintain_tracking_partitions_task(days_ahead: int = 2) -> dict:
    """Cria as partições futuras e dropa as expiradas."""

    created = ensure_partitions(days_ahead=days_ahead)
    dropped = drop_expired_partitions()
    return {"created": created, "dropped": dropped}


@shared_task(name="apps.tracking.tasks.trim_position_history_task")
def trim_position_history_task() -> dict:
    """Remove linhas fora da janela de retenção de 24 horas."""

    return {"trimmed": trim_expired_rows()}
