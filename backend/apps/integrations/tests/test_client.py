from __future__ import annotations

from unittest.mock import patch

import responses
from django.test import SimpleTestCase, override_settings

from apps.integrations.sptrans.client import SPTransClient, public_line_code
from apps.integrations.sptrans.errors import (
    SPTransAuthError,
    SPTransConfigurationError,
    SPTransRateLimitError,
)

BASE_URL = "https://api.exemplo.test/v2.1"

LINE_PAYLOAD = [
    {
        "cl": 1273,
        "lc": "1012-10",
        "lt": "1012-10",
        "sl": 1,
        "tl": "10",
        "tp": "1012",
        "ts": "10",
    },
    {
        "cl": 1274,
        "lc": "1012-10",
        "lt": "1012-10",
        "sl": 2,
        "tl": "10",
        "tp": "1012",
        "ts": "10",
    },
]

STOP_PAYLOAD = [
    {
        "cp": "340015329",
        "np": "Av. Paulista",
        "ed": "Av. Paulista, 100",
        "py": -23.561,
        "px": -46.655,
    }
]

POSITION_PAYLOAD = {
    "hr": "12:00",
    "l": [
        {
            "c": "1012-10",
            "cl": 1273,
            "sl": 1,
            "lt0": "Term. A",
            "lt1": "Jd. B",
            "qv": 1,
            "p": [
                {
                    "c": "12345",
                    "a": True,
                    "ta": "2026-11-21T12:00:00Z",
                    "py": -23.55,
                    "px": -46.63,
                }
            ],
        }
    ],
}


def make_client(**kwargs) -> SPTransClient:
    return SPTransClient(
        token=kwargs.pop("token", "token-de-teste"),
        base_url=BASE_URL,
        requests_per_second=0,
        **kwargs,
    )


@override_settings(SPTRANS_API_TOKEN="token-de-teste")
class SPTransClientTests(SimpleTestCase):
    def test_public_line_code_accepts_letters(self):
        assert (
            public_line_code(
                {
                    "cl": 516,
                    "lc": False,
                    "lt": "106A",
                    "sl": 1,
                    "tl": 10,
                    "tp": "ITAIM BIBI",
                    "ts": "METRÔ SANTANA",
                }
            )
            == "106A-10"
        )

    @responses.activate
    def test_authenticates_and_searches_lines(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Linha/Buscar", json=LINE_PAYLOAD)

        client = make_client()
        records = client.search_lines("1012")

        assert [record.public_code for record in records] == ["1012-10", "1012-10"]
        assert [record.direction for record in records] == [0, 1]
        assert records[0].external_id == "1273"
        assert records[0].search_terms == ("1012-10", "1012", "10")

    @responses.activate
    def test_parses_positions_from_vs_field(self):
        payload = {
            "hr": "12:00",
            "l": [
                {
                    "c": "857R-10",
                    "cl": 1892,
                    "sl": 1,
                    "qv": 1,
                    "vs": [
                        {
                            "p": 80234,
                            "a": True,
                            "ta": "2026-11-21T12:00:00Z",
                            "py": -23.57,
                            "px": -46.70,
                        }
                    ],
                }
            ],
        }
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Posicao", json=payload)

        records = make_client().positions()

        assert len(records) == 1
        assert records[0].line_code == "857R-10"
        assert records[0].vehicle_code == "80234"
        assert records[0].direction == 0

    @responses.activate
    def test_reauthenticates_once_after_401(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Linha/Buscar", status=401)
        responses.add(responses.GET, f"{BASE_URL}/Linha/Buscar", json=LINE_PAYLOAD)

        client = make_client()
        records = client.search_lines("1012")

        assert len(records) == 2
        assert len(responses.calls) == 4  # auth, 401, reauth, sucesso

    @responses.activate
    def test_retries_on_rate_limit(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Posicao", status=429)
        responses.add(responses.GET, f"{BASE_URL}/Posicao", json=POSITION_PAYLOAD)

        client = make_client(max_retries=1)
        with patch("apps.integrations.sptrans.client.time.sleep"):
            records = client.positions()

        assert len(records) == 1

    @responses.activate
    def test_rate_limit_after_retries_raises(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Posicao", status=429)
        responses.add(responses.GET, f"{BASE_URL}/Posicao", status=429)

        client = make_client(max_retries=1)
        with patch("apps.integrations.sptrans.client.time.sleep"):
            with self.assertRaises(SPTransRateLimitError):
                client.positions()

    @responses.activate
    def test_rejected_token_raises_auth_error(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="false")

        with self.assertRaises(SPTransAuthError):
            make_client().authenticate()

    def test_missing_token_raises_configuration_error(self):
        with self.assertRaises(SPTransConfigurationError):
            make_client(token="").authenticate()

    @responses.activate
    def test_parses_stops_in_api_order(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(
            responses.GET,
            f"{BASE_URL}/Parada/BuscarParadasPorLinha",
            json=STOP_PAYLOAD,
        )

        stops = make_client().stops_for_line("1273")

        assert len(stops) == 1
        assert stops[0].code == "340015329"
        assert stops[0].latitude == -23.561
        assert stops[0].address == "Av. Paulista, 100"

    @responses.activate
    def test_parses_positions(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(responses.GET, f"{BASE_URL}/Posicao", json=POSITION_PAYLOAD)

        positions = make_client().positions()

        assert len(positions) == 1
        position = positions[0]
        assert position.line_code == "1012-10"
        assert position.vehicle_code == "12345"
        assert position.direction == 0
        assert position.is_accessible is True
        assert position.captured_at.isoformat() == "2026-11-21T12:00:00+00:00"

    @responses.activate
    def test_invalid_records_are_ignored(self):
        responses.add(responses.POST, f"{BASE_URL}/Login/Autenticar", body="true")
        responses.add(
            responses.GET,
            f"{BASE_URL}/Posicao",
            json={
                "l": [
                    {
                        "c": "1012-10",
                        "p": [
                            {"c": "ok", "ta": "2026-11-21T12:00:00Z", "py": -23.5, "px": -46.6},
                            {"c": "sem-posicao", "ta": "2026-11-21T12:00:00Z"},
                            {"c": "fora", "ta": "2026-11-21T12:00:00Z", "py": 99, "px": 0},
                        ],
                    }
                ]
            },
        )

        positions = make_client().positions()

        assert [position.vehicle_code for position in positions] == ["ok"]


class PublicLineCodeTests(SimpleTestCase):
    def test_prefers_letreiro_completo(self):
        assert public_line_code({"lt": "1012-10"}) == "1012-10"

    def test_builds_code_from_search_terms(self):
        assert public_line_code({"tp": "1012", "ts": "10"}) == "1012-10"

    def test_returns_none_when_unavailable(self):
        assert public_line_code({"lt": "sem-codigo"}) is None
