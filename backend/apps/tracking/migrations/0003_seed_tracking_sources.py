"""Cadastra a fonte de rastreamento de cada cidade.

Teresina continua com o replay dos CSVs de demonstração. São Paulo usa a API
Olho Vivo. As fontes ficam ativas mesmo com a cidade inativa, para que o
catálogo e as posições estejam prontos quando a cidade for liberada.
"""

from django.db import migrations

SOURCES = {
    "teresina": {
        "kind": "csv_demo",
        "config": {"source": "TRACKING_CSV_DIR"},
    },
    "sao-paulo": {
        "kind": "sptrans_api",
        "config": {"token_env": "SPTRANS_API_TOKEN"},
    },
}


def seed_sources(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    TrackingSource = apps.get_model("tracking", "TrackingSource")
    for slug, values in SOURCES.items():
        city = City.objects.filter(slug=slug).first()
        if city is None:
            continue
        TrackingSource.objects.get_or_create(
            city=city,
            is_active=True,
            defaults={"kind": values["kind"], "config": values["config"]},
        )


def unseed_sources(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    TrackingSource = apps.get_model("tracking", "TrackingSource")
    for slug in SOURCES:
        city = City.objects.filter(slug=slug).first()
        if city is not None:
            TrackingSource.objects.filter(city=city).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0007_seed_sao_paulo"),
        ("tracking", "0002_position_history"),
    ]

    operations = [
        migrations.RunPython(seed_sources, unseed_sources),
    ]
