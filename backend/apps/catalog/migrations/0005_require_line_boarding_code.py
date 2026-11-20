"""Torna o `sgLinha` obrigatório e único entre as linhas ativas.

O `boardingCode` passa a ser a identidade pública da linha, então nenhuma linha
ativa pode ficar sem ele e não pode haver duplicata dentro da cidade. Linhas
ativas sem `sgLinha` são desativadas antes das constraints serem criadas.
"""

from django.db import migrations, models
from django.db.models import Q


def deactivate_lines_without_boarding_code(apps, schema_editor):
    Line = apps.get_model("catalog", "Line")
    Line.objects.filter(is_active=True, boarding_code="").update(is_active=False)


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0004_add_lines_routes"),
    ]

    operations = [
        migrations.RunPython(
            deactivate_lines_without_boarding_code,
            migrations.RunPython.noop,
        ),
        migrations.AlterField(
            model_name="line",
            name="boarding_code",
            field=models.CharField(max_length=20, verbose_name="sgLinha"),
        ),
        migrations.AddConstraint(
            model_name="line",
            constraint=models.CheckConstraint(
                condition=Q(is_active=False) | ~Q(boarding_code=""),
                name="catalog_line_active_boarding_code_required",
            ),
        ),
        migrations.AddConstraint(
            model_name="line",
            constraint=models.UniqueConstraint(
                fields=("city", "boarding_code"),
                condition=Q(is_active=True),
                name="catalog_line_active_city_boarding_uniq",
            ),
        ),
    ]
