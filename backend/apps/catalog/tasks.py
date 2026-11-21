"""Tarefas Celery de importação do catálogo."""

from __future__ import annotations

import logging

from celery import shared_task
from django.conf import settings

from apps.catalog.models import CatalogImportRun, CatalogSource, City
from apps.catalog.sptrans_import import import_catalog
from apps.common.locks import LockNotAcquired, cache_lock
from apps.integrations.sptrans.client import SPTransClient
from apps.integrations.sptrans.gtfs import GtfsFeed

logger = logging.getLogger(__name__)

DEFAULT_SOURCE_SLUG = "sptrans-api"


@shared_task(name="apps.catalog.tasks.import_sptrans_catalog_task")
def import_sptrans_catalog_task(city_slug: str = "sao-paulo") -> dict:
    """Importação semanal do catálogo de uma cidade."""

    city = City.objects.get(slug=city_slug)
    source = CatalogSource.objects.get(city=city, slug=DEFAULT_SOURCE_SLUG)
    feed = GtfsFeed(settings.SPTRANS_GTFS_DIR)

    try:
        with cache_lock(key=f"catalog:import:{city.slug}", timeout=60 * 60 * 4):
            result = import_catalog(
                city=city,
                source=source,
                client=SPTransClient(),
                feed=feed if feed.directory.is_dir() else None,
                trigger=CatalogImportRun.Trigger.SCHEDULE,
            )
    except LockNotAcquired:
        logger.info("Importação de %s já em andamento; ignorando.", city_slug)
        return {"city": city_slug, "status": "locked"}

    return {"city": city_slug, **result.as_dict()}
