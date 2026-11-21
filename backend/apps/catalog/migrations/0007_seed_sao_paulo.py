"""Cria São Paulo como cidade **inativa**.

A cidade só aparece em `GET /v1/cities` depois da ativação explícita
(`manage.py set_city_active sao-paulo --active`), feita primeiro em staging e em
produção apenas após o gate de lançamento.
"""

from decimal import Decimal

from django.db import migrations

SAO_PAULO = {
    "slug": "sao-paulo",
    "name": "São Paulo",
    "state": "SP",
    "country": "BR",
    "timezone": "America/Sao_Paulo",
    "latitude": Decimal("-23.550520"),
    "longitude": Decimal("-46.633308"),
    "import_interval": "weekly",
    "is_active": False,
    "coverage_note": "Catálogo: API Olho Vivo (SPTrans); traçados: GTFS SPTrans.",
}


def seed_sao_paulo(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    City.objects.get_or_create(slug=SAO_PAULO["slug"], defaults=SAO_PAULO)


def unseed_sao_paulo(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    City.objects.filter(slug=SAO_PAULO["slug"]).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0006_catalogimportrun_linesourceref_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_sao_paulo, unseed_sao_paulo),
    ]
