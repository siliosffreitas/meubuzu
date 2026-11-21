from __future__ import annotations

import tempfile
from pathlib import Path

from django.test import SimpleTestCase

from apps.integrations.sptrans.gtfs import GtfsFeed

ROUTES = (
    "route_id,agency_id,route_short_name,route_long_name,route_type,route_color,route_text_color\n"
    '"1012-10","1","1012-10","Term. A - Jd. B","3","509E2F","FFFFFF"\n'
    '"9000-1","1","9000-1","Metrô","1","000000","FFFFFF"\n'
)

TRIPS = (
    "route_id,service_id,trip_id,trip_headsign,direction_id,shape_id\n"
    '"1012-10","USD","1012-10-0","Jd. B","0","100"\n'
    '"1012-10","USD","1012-10-1","Term. A","1","200"\n'
)

SHAPES = (
    "shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence,shape_dist_traveled\n"
    '"100","-23.40","-46.70","3","0"\n'
    '"100","-23.50","-46.60","1","0"\n'
    '"100","-23.45","-46.65","2","0"\n'
    '"200","-23.51","-46.61","1","0"\n'
)


class GtfsFeedTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        (self.directory / "routes.txt").write_text(ROUTES, encoding="utf-8")
        (self.directory / "trips.txt").write_text(TRIPS, encoding="utf-8")
        (self.directory / "shapes.txt").write_text(SHAPES, encoding="utf-8")
        self.feed = GtfsFeed(self.directory)

    def test_validate_counts_bus_routes_and_shapes(self):
        validation = self.feed.validate()

        assert validation.is_valid, validation.errors
        assert validation.routes == 2
        assert validation.bus_routes == 1
        assert validation.trips == 2
        assert validation.shapes == 2
        assert validation.shape_points == 4

    def test_routes_filter_non_bus_by_default(self):
        routes = self.feed.routes()

        assert set(routes) == {"1012-10"}
        assert routes["1012-10"].long_name == "Term. A - Jd. B"

    def test_line_codes_are_the_bus_short_names(self):
        assert self.feed.line_codes() == {"1012-10"}

    def test_shape_map_uses_route_and_direction(self):
        assert self.feed.shape_map() == {
            ("1012-10", 0): "100",
            ("1012-10", 1): "200",
        }

    def test_shapes_are_sorted_by_sequence(self):
        shapes = self.feed.shapes({"100"})

        assert shapes["100"] == [
            (-23.50, -46.60),
            (-23.45, -46.65),
            (-23.40, -46.70),
        ]

    def test_missing_file_is_reported(self):
        (self.directory / "shapes.txt").unlink()

        validation = self.feed.validate()

        assert not validation.is_valid
        assert any("shapes.txt" in error for error in validation.errors)

    def test_missing_directory_is_reported(self):
        validation = GtfsFeed(self.directory / "nao-existe").validate()

        assert not validation.is_valid
