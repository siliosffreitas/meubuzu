from decimal import Decimal

from django.db import migrations


def seed_teresina(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    City.objects.get_or_create(
        slug="teresina",
        defaults={
            "name": "Teresina",
            "state": "PI",
            "country": "BR",
            "timezone": "America/Fortaleza",
            "latitude": Decimal("-5.16"),
            "longitude": Decimal("-42.79"),
            "import_interval": "weekly",
            "is_active": True,
            "coverage_note": "",
        },
    )


def unseed_teresina(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    City.objects.filter(slug="teresina").delete()


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed_teresina, unseed_teresina),
    ]
