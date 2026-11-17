import json
import tempfile
from decimal import Decimal
from pathlib import Path

from django.core.management import call_command
from django.test import TestCase

from apps.catalog.models import CatalogSource, City, Line, LineStop, Route, Stop
from apps.catalog.text import normalize_search_text


def make_stop(city: City, code: str) -> Stop:
    return Stop.objects.create(
        city=city,
        code=code,
        name=f"Parada {code}",
        address="Endereço",
        latitude=Decimal("-5.16"),
        longitude=Decimal("-42.79"),
        search_text=normalize_search_text(code),
    )


class ImportLinesCommandTests(TestCase):
    def setUp(self):
        self.city = City.objects.get(slug="teresina")
        self.first_stop = make_stop(self.city, "100")
        self.second_stop = make_stop(self.city, "200")
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

        lines_path = self.root / "lines.csv"
        lines_path.write_text(
            "codigoLinha,nomeLinha,getOrigemIda,destinoIda,sgLinha\n"
            "3,CENTRO - NORTE,Centro,Norte,0001\n"
            "4,NORTE - CENTRO,Norte,Centro,0002\n",
            encoding="utf-8",
        )
        self.lines_path = lines_path

        stops_path = self.root / "lines_paradas.json"
        stops_path.write_text(
            json.dumps({"0001": "200,100", "4": "100,200"}),
            encoding="utf-8",
        )
        self.stops_path = stops_path

        routes_dir = self.root / "routes"
        routes_dir.mkdir()
        (routes_dir / "0001.csv").write_text(
            "-5.16,-42.79\n-5.17,-42.80\n", encoding="utf-8"
        )
        self.routes_dir = routes_dir

    def _import(self, *extra_args):
        call_command(
            "import_lines",
            "--city",
            "teresina",
            "--lines-path",
            str(self.lines_path),
            "--line-stops-path",
            str(self.stops_path),
            "--routes-dir",
            str(self.routes_dir),
            *extra_args,
        )

    def test_imports_lines_stops_and_routes(self):
        self._import()

        assert Line.objects.filter(city=self.city).count() == 2
        source = CatalogSource.objects.get(city=self.city, slug="csv-linhas")
        assert source.data_mode == CatalogSource.DataMode.DEMO

        line = Line.objects.get(city=self.city, code="3")
        assert line.boarding_code == "0001"
        assert line.name == "CENTRO - NORTE"
        assert line.source == source
        assert line.search_text == "3 0001 centro - norte centro norte"

        relations = LineStop.objects.filter(line=line).order_by("sequence")
        assert [(relation.stop.code, relation.sequence) for relation in relations] == [
            ("200", 1),
            ("100", 2),
        ]

        route = Route.objects.get(line=line)
        assert route.path == [[-5.16, -42.79], [-5.17, -42.80]]

        # O JSON também resolve a linha pelo código interno (`codigoLinha`).
        other = Line.objects.get(city=self.city, code="4")
        assert LineStop.objects.filter(line=other).count() == 2

    def test_import_is_idempotent(self):
        self._import()
        self._import()

        assert Line.objects.filter(city=self.city).count() == 2
        assert LineStop.objects.filter(line__city=self.city).count() == 4
        assert Route.objects.filter(line__city=self.city).count() == 1
        assert CatalogSource.objects.filter(city=self.city).count() == 1

    def test_dry_run_does_not_write(self):
        self._import("--dry-run")

        assert Line.objects.filter(city=self.city).count() == 0
        assert LineStop.objects.filter(line__city=self.city).count() == 0
        assert Route.objects.filter(line__city=self.city).count() == 0
        assert CatalogSource.objects.filter(city=self.city).count() == 0
