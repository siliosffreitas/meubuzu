"""Testes das partições diárias e da retenção de 24 horas do histórico."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from django.test import TestCase, override_settings

from apps.tracking.models import PositionHistory
from apps.tracking.partitions import (
    create_partition,
    drop_expired_partitions,
    ensure_partitions,
    existing_partitions,
    maintain,
    partition_name,
    trim_expired_rows,
)

NOW = datetime(2026, 11, 21, 12, 0, tzinfo=UTC)


def make_history(captured_at: datetime, *, vehicle: str) -> PositionHistory:
    return PositionHistory.objects.create(
        city_id=uuid.uuid4(),
        vehicle_code=vehicle,
        latitude="-23.550000",
        longitude="-46.630000",
        captured_at=captured_at,
        received_at=captured_at,
    )


@override_settings(TRACKING_HISTORY_RETENTION_HOURS=24, TRACKING_HISTORY_TRIM_BATCH=1000)
class PartitionTests(TestCase):
    def partition_days(self) -> set:
        return {day for _, day in existing_partitions()}

    def test_ensure_creates_today_and_future_partitions(self):
        created = ensure_partitions(days_ahead=1, now=NOW)

        assert created == [
            partition_name(NOW.date()),
            partition_name(NOW.date() + timedelta(days=1)),
        ]
        assert self.partition_days() >= {
            NOW.date(),
            NOW.date() + timedelta(days=1),
        }

    def test_ensure_is_idempotent(self):
        ensure_partitions(days_ahead=1, now=NOW)

        assert ensure_partitions(days_ahead=1, now=NOW) == []

    def test_create_partition_is_idempotent(self):
        day = NOW.date()

        first = create_partition(day)
        second = create_partition(day)

        assert first == second == partition_name(day)
        assert day in self.partition_days()

    def test_drops_only_expired_partitions(self):
        expired = NOW.date() - timedelta(days=3)
        boundary = NOW.date() - timedelta(days=1)
        create_partition(expired)
        create_partition(boundary)
        create_partition(NOW.date())

        dropped = drop_expired_partitions(hours=24, now=NOW)

        assert partition_name(expired) in dropped
        remaining = self.partition_days()
        assert expired not in remaining
        assert boundary in remaining
        assert NOW.date() in remaining

    def test_drop_is_idempotent(self):
        create_partition(NOW.date() - timedelta(days=3))

        drop_expired_partitions(hours=24, now=NOW)

        assert drop_expired_partitions(hours=24, now=NOW) == []

    def test_trim_removes_only_rows_older_than_retention(self):
        # A fronteira de 24 h cai em 2026-11-20 12:00 UTC.
        boundary_day = NOW.date() - timedelta(days=1)
        create_partition(boundary_day)
        create_partition(NOW.date())

        old = make_history(
            datetime(2026, 11, 20, 11, 0, tzinfo=UTC), vehicle="antigo"
        )
        kept_boundary = make_history(
            datetime(2026, 11, 20, 13, 0, tzinfo=UTC), vehicle="fronteira"
        )
        kept_today = make_history(
            datetime(2026, 11, 21, 10, 0, tzinfo=UTC), vehicle="hoje"
        )

        removed = trim_expired_rows(hours=24, now=NOW)

        assert removed == 1
        remaining = set(
            PositionHistory.objects.values_list("vehicle_code", flat=True)
        )
        assert remaining == {"fronteira", "hoje"}
        assert old.id not in set(PositionHistory.objects.values_list("id", flat=True))
        assert kept_boundary.id in set(PositionHistory.objects.values_list("id", flat=True))
        assert kept_today.id in set(PositionHistory.objects.values_list("id", flat=True))

    def test_trim_is_idempotent(self):
        create_partition(NOW.date() - timedelta(days=1))
        make_history(datetime(2026, 11, 20, 11, 0, tzinfo=UTC), vehicle="antigo")

        assert trim_expired_rows(hours=24, now=NOW) == 1
        assert trim_expired_rows(hours=24, now=NOW) == 0

    def test_maintain_combines_operations(self):
        expired = NOW.date() - timedelta(days=3)
        create_partition(expired)

        result = maintain(days_ahead=1, now=NOW)

        assert partition_name(expired) in result["dropped"]
        assert partition_name(NOW.date()) in result["created"]
        assert partition_name(NOW.date() + timedelta(days=1)) in result["created"]
        assert result["trimmed"] == 0
