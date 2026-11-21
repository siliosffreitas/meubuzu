"""Cria a tabela particionada do histórico de posições.

Django não gera DDL de tabela particionada, então a tabela pai e os índices são
criados por SQL. O model `PositionHistory` usa `managed = False` e apenas
consulta/insere.

A partição é diária, em UTC. O expurgo (jobs de partição) mantém a retenção de
24 horas definida em `TRACKING_HISTORY_RETENTION_HOURS`.
"""

from django.db import migrations

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS tracking_position_history (
    id uuid NOT NULL,
    city_id uuid NOT NULL,
    line_id uuid NULL,
    source_id uuid NULL,
    vehicle_code varchar(40) NOT NULL,
    latitude numeric(9, 6) NOT NULL,
    longitude numeric(9, 6) NOT NULL,
    direction smallint NOT NULL DEFAULT 0,
    is_accessible boolean NOT NULL DEFAULT false,
    data_mode varchar(8) NOT NULL DEFAULT 'live',
    captured_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    PRIMARY KEY (id, captured_at)
) PARTITION BY RANGE (captured_at)
"""

CREATE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS tracking_history_city_time_idx "
    "ON tracking_position_history (city_id, captured_at)",
    "CREATE INDEX IF NOT EXISTS tracking_history_line_time_idx "
    "ON tracking_position_history (line_id, captured_at)",
    "CREATE INDEX IF NOT EXISTS tracking_history_time_idx "
    "ON tracking_position_history (captured_at)",
    "CREATE UNIQUE INDEX IF NOT EXISTS tracking_history_vehicle_time_uniq "
    "ON tracking_position_history (city_id, source_id, vehicle_code, captured_at)",
]


class Migration(migrations.Migration):
    dependencies = [
        ("tracking", "0001_initial"),
    ]

    operations = [
        migrations.RunSQL(
            sql=[CREATE_TABLE, *CREATE_INDEXES],
            reverse_sql="DROP TABLE IF EXISTS tracking_position_history",
        ),
    ]
