from unittest.mock import patch

from django.db import connection
from django.test import TestCase


class ReadyViewTests(TestCase):
    def test_reports_ok_and_active_sources(self):
        response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["status"], "ok")

        sources = {item["city"]: item for item in payload["sources"]}
        self.assertEqual(sources["teresina"]["kind"], "csv_demo")
        self.assertEqual(sources["sao-paulo"]["kind"], "sptrans_api")
        self.assertNotIn("token", str(payload).lower())

    def test_reports_unavailable_when_database_fails(self):
        with patch.object(connection, "cursor", side_effect=RuntimeError("sem banco")):
            response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"status": "unavailable"})
