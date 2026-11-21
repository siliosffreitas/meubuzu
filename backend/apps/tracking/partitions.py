"""Manutenção das partições diárias do histórico de posições.

O histórico é retido por 24 horas. Com partição diária, o expurgo combina:

- `DROP TABLE` da partição quando ela está inteiramente fora da janela;
- `DELETE` em lotes na partição que ainda contém a fronteira de 24 h.

Assim a retenção efetiva fica entre 24 e 25 horas, sem `DELETE` de milhões de
linhas em uma única transação.
"""

from __future__ import annotations

import logging
import re
from datetime import UTC, date, datetime, time, timedelta

from django.conf import settings
from django.db import connection

logger = logging.getLogger(__name__)

HISTORY_TABLE = "tracking_position_history"
PARTITION_PREFIX = f"{HISTORY_TABLE}_"
PARTITION_PATTERN = re.compile(rf"^{PARTITION_PREFIX}(\d{{8}})$")


def _settings_int(name: str, default: int) -> int:
    return int(getattr(settings, name, default))


def retention_hours() -> int:
    return max(_settings_int("TRACKING_HISTORY_RETENTION_HOURS", 24), 1)


def partition_name(day: date) -> str:
    return f"{PARTITION_PREFIX}{day:%Y%m%d}"


def day_bounds(day: date) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=UTC)
    return start, start + timedelta(days=1)


def _sql_timestamp(value: datetime) -> str:
    return value.astimezone(UTC).isoformat()


def table_exists(table: str = HISTORY_TABLE) -> bool:
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass(%s)", [table])
        return cursor.fetchone()[0] is not None


def existing_partitions() -> list[tuple[str, date]]:
    """Partições existentes, com o dia que cada uma cobre."""

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT child.relname
            FROM pg_inherits
            JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
            JOIN pg_class child ON child.oid = pg_inherits.inhrelid
            WHERE parent.relname = %s
            ORDER BY child.relname
            """,
            [HISTORY_TABLE],
        )
        names = [row[0] for row in cursor.fetchall()]

    partitions: list[tuple[str, date]] = []
    for name in names:
        match = PARTITION_PATTERN.match(name)
        if match is None:
            continue
        partitions.append((name, datetime.strptime(match.group(1), "%Y%m%d").date()))
    return partitions


def create_partition(day: date) -> bool:
    """Cria a partição do dia, se ainda não existir."""

    if not table_exists():
        raise RuntimeError(
            "A tabela tracking_position_history não existe; rode as migrations."
        )

    name = partition_name(day)
    start, end = day_bounds(day)
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {name}
            PARTITION OF {HISTORY_TABLE}
            FOR VALUES FROM ('{_sql_timestamp(start)}')
                          TO ('{_sql_timestamp(end)}')
            """
        )
    return name


def ensure_partitions(*, days_ahead: int = 2, now: datetime | None = None) -> list[str]:
    """Garante a partição de hoje e das próximas `days_ahead` datas."""

    today = (now or datetime.now(UTC)).astimezone(UTC).date()
    existing = {day for _, day in existing_partitions()}
    created: list[str] = []
    for offset in range(max(days_ahead, 0) + 1):
        day = today + timedelta(days=offset)
        if day not in existing:
            created.append(create_partition(day))
    return created


def drop_expired_partitions(
    *, hours: int | None = None, now: datetime | None = None
) -> list[str]:
    """Dropa partições cujo intervalo termina antes da janela de retenção."""

    retention = hours or retention_hours()
    cutoff = (now or datetime.now(UTC)) - timedelta(hours=retention)
    dropped: list[str] = []

    for name, day in existing_partitions():
        _, end = day_bounds(day)
        if end <= cutoff:
            with connection.cursor() as cursor:
                cursor.execute(f"DROP TABLE IF EXISTS {name}")
            dropped.append(name)
            logger.info("Partição expirada removida: %s", name)
    return dropped


def trim_expired_rows(
    *,
    hours: int | None = None,
    now: datetime | None = None,
    batch_size: int | None = None,
) -> int:
    """Remove, em lotes, linhas mais antigas que a janela de retenção.

    Só age na partição que contém a fronteira: as partições totalmente expiradas
    já foram removidas por `drop_expired_partitions`.
    """

    retention = hours or retention_hours()
    cutoff = (now or datetime.now(UTC)) - timedelta(hours=retention)
    size = batch_size or _settings_int("TRACKING_HISTORY_TRIM_BATCH", 50_000)
    removed = 0

    for name, day in existing_partitions():
        start, end = day_bounds(day)
        if not start < cutoff < end:
            continue

        while True:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    DELETE FROM {name}
                    WHERE ctid IN (
                        SELECT ctid FROM {name}
                        WHERE captured_at < %s
                        LIMIT %s
                    )
                    """,
                    [cutoff, size],
                )
                deleted = cursor.rowcount or 0
            removed += deleted
            if deleted < size:
                break

    if removed:
        logger.info(
            "Histórico: %d linhas removidas (retenção de %d h).", removed, retention
        )
    return removed


def maintain(*, days_ahead: int = 2, now: datetime | None = None) -> dict[str, object]:
    """Executa criação de partições, expurgo e trim em uma chamada."""

    created = ensure_partitions(days_ahead=days_ahead, now=now)
    dropped = drop_expired_partitions(now=now)
    trimmed = trim_expired_rows(now=now)
    return {"created": created, "dropped": dropped, "trimmed": trimmed}
