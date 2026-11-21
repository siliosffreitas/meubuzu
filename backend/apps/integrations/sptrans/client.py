"""Cliente da API Olho Vivo (SPTrans).

A API usa autenticação por token em `POST /Login/Autenticar?token=...` e mantém
a sessão por cookie. Este cliente:

- nunca registra o token em log;
- reautentica uma vez quando recebe `401`;
- respeita um limite de requisições por segundo;
- tenta novamente em `429` e `5xx` com backoff exponencial;
- normaliza os campos da API em DTOs imutáveis, tolerando variações de nome.

Os identificadores internos (`cl`) só existem nos DTOs usados pela importação.
Eles nunca são devolvidos pela API pública do MeuBuzu.
"""

from __future__ import annotations

import logging
import re
import time
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import requests
from django.conf import settings

from .errors import (
    SPTransAuthError,
    SPTransConfigurationError,
    SPTransRateLimitError,
    SPTransUnavailable,
)

logger = logging.getLogger(__name__)

# Letreiro numérico/alfanumérico da SPTrans (ex.: 1012-10, 106A-10, 857R-10).
LINE_CODE_PATTERN = re.compile(r"^[0-9A-Z]{3,5}-[0-9]{1,2}$")

# Sentidos da API (`sl`): 1 e 2. O contrato do MeuBuzu usa 0 e 1.
_DIRECTION_MAP = {1: 0, 2: 1, 0: 0, 3: 1}

_RETRYABLE_STATUS = {429, 500, 502, 503, 504}


@dataclass(frozen=True, slots=True)
class LineRecord:
    """Linha em um sentido, como devolvida por `/Linha/Buscar`."""

    external_id: str
    public_code: str
    direction: int
    origin_label: str
    destination_label: str
    search_terms: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class StopRecord:
    """Parada de uma linha, na ordem devolvida pela API."""

    code: str
    name: str
    address: str
    latitude: float
    longitude: float


@dataclass(frozen=True, slots=True)
class VehiclePositionRecord:
    """Posição de um veículo em um instante."""

    line_code: str
    vehicle_code: str
    latitude: float
    longitude: float
    captured_at: datetime
    direction: int
    is_accessible: bool


def _text(raw: Any) -> str:
    return str(raw).strip() if raw is not None else ""


def _first(raw: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        value = raw.get(key)
        if value not in (None, ""):
            return value
    return None


def _float_or_none(raw: Any) -> float | None:
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def parse_timestamp(raw: Any) -> datetime | None:
    """Lê um timestamp ISO 8601 (com `Z` ou offset) e devolve em UTC."""

    value = _text(raw)
    if not value:
        return None
    if value.endswith("Z"):
        value = f"{value[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def public_line_code(raw: dict[str, Any]) -> str | None:
    """Extrai o código público (`lt-tl`, ex.: `1012-10` ou `106A-10`) de um registro.

    Os nomes dos campos variam entre versões da API, então o código é procurado
    em `lt`/`lc` e, na falta de um valor já no formato `0000-00`, montado a
    partir dos termos de pesquisa.
    """

    for key in ("lt", "lc"):
        value = _text(raw.get(key))
        if LINE_CODE_PATTERN.match(value):
            return value

    for first, second in (("tp", "ts"), ("lt", "tl")):
        left = _text(raw.get(first))
        right = _text(raw.get(second))
        if left and right:
            candidate = f"{left}-{right}"
            if LINE_CODE_PATTERN.match(candidate):
                return candidate
    return None


def direction_from(raw: Any) -> int:
    """Converte o sentido da API (`sl` 1/2) para o sentido do MeuBuzu (0/1)."""

    try:
        return _DIRECTION_MAP.get(int(raw), 0)
    except (TypeError, ValueError):
        return 0


class SPTransClient:
    """Cliente HTTP com autenticação, throttle e retry."""

    def __init__(
        self,
        *,
        token: str | None = None,
        base_url: str | None = None,
        session: requests.Session | None = None,
        timeout: int | None = None,
        requests_per_second: int | None = None,
        max_retries: int | None = None,
    ) -> None:
        self.token = (token if token is not None else settings.SPTRANS_API_TOKEN).strip()
        self.base_url = (
            base_url or settings.SPTRANS_API_BASE_URL
        ).rstrip("/")
        self.session = session or requests.Session()
        self.timeout = int(timeout or settings.SPTRANS_API_TIMEOUT_SECONDS)
        rate = int(requests_per_second or settings.SPTRANS_API_REQUESTS_PER_SECOND)
        self.min_interval = 1.0 / rate if rate > 0 else 0.0
        self.max_retries = int(max_retries or settings.SPTRANS_API_MAX_RETRIES)
        self._last_request_at = 0.0
        self._authenticated = False

    # -- Autenticação --------------------------------------------------------

    def authenticate(self) -> None:
        if not self.token:
            raise SPTransConfigurationError(
                "SPTRANS_API_TOKEN não configurado; a importação não pode continuar."
            )

        self._throttle()
        try:
            response = self.session.post(
                f"{self.base_url}/Login/Autenticar",
                params={"token": self.token},
                timeout=self.timeout,
            )
        except requests.RequestException as exc:
            raise SPTransUnavailable("Falha de rede ao autenticar na SPTrans.") from exc

        if response.status_code == 401:
            raise SPTransAuthError("Token da SPTrans recusado (401).")
        if response.status_code >= 400:
            raise SPTransUnavailable(
                f"Autenticação da SPTrans falhou com status {response.status_code}."
            )

        body = (response.text or "").strip().lower()
        if body not in {"true", "1"}:
            raise SPTransAuthError("A SPTrans recusou o token informado.")
        self._authenticated = True

    # -- HTTP ----------------------------------------------------------------

    def _throttle(self) -> None:
        if self.min_interval <= 0:
            return
        elapsed = time.monotonic() - self._last_request_at
        if elapsed < self.min_interval:
            time.sleep(self.min_interval - elapsed)
        self._last_request_at = time.monotonic()

    def _get(self, path: str, *, params: dict[str, Any] | None = None) -> Any:
        if not self._authenticated:
            self.authenticate()

        last_error: Exception | None = None
        for attempt in range(self.max_retries + 1):
            self._throttle()
            try:
                response = self.session.get(
                    f"{self.base_url}{path}",
                    params=params,
                    timeout=self.timeout,
                )
            except requests.RequestException as exc:
                last_error = exc
                if attempt >= self.max_retries:
                    break
                time.sleep(min(2**attempt, 8))
                continue

            if response.status_code == 401 and attempt == 0:
                # Cookie expirou: reautentica uma vez e repete a requisição.
                self._authenticated = False
                self.authenticate()
                continue

            if response.status_code == 401:
                raise SPTransAuthError("Sessão da SPTrans recusada (401).")

            if response.status_code in _RETRYABLE_STATUS:
                if attempt >= self.max_retries:
                    if response.status_code == 429:
                        raise SPTransRateLimitError(
                            "Rate limit da SPTrans excedido após as tentativas."
                        )
                    raise SPTransUnavailable(
                        f"SPTrans indisponível (status {response.status_code})."
                    )
                retry_after = response.headers.get("Retry-After")
                delay = float(retry_after) if (retry_after or "").isdigit() else 2**attempt
                time.sleep(min(delay, 30))
                continue

            if response.status_code >= 400:
                raise SPTransUnavailable(
                    f"SPTrans devolveu status {response.status_code} em {path}."
                )

            try:
                return response.json()
            except ValueError as exc:
                raise SPTransUnavailable(
                    f"Resposta inválida da SPTrans em {path}."
                ) from exc

        raise SPTransUnavailable("A SPTrans não respondeu após as tentativas.") from last_error

    # -- Endpoints -----------------------------------------------------------

    def search_lines(self, term: str) -> list[LineRecord]:
        """Busca linhas por termo e devolve um registro por sentido."""

        payload = self._get("/Linha/Buscar", params={"termosBusca": term})
        return self._parse_lines(payload)

    def stops_for_line(self, external_id: str) -> list[StopRecord]:
        """Paradas do sentido identificado pelo `cl` interno, na ordem da API."""

        payload = self._get(
            "/Parada/BuscarParadasPorLinha",
            params={"codigoLinha": external_id},
        )
        return self._parse_stops(payload)

    def positions(self) -> list[VehiclePositionRecord]:
        """Posições de todos os veículos em operação."""

        payload = self._get("/Posicao")
        return self._parse_positions(payload)

    # -- Parsing -------------------------------------------------------------

    @staticmethod
    def _parse_lines(payload: Any) -> list[LineRecord]:
        if not isinstance(payload, list):
            return []

        records: list[LineRecord] = []
        for raw in payload:
            if not isinstance(raw, dict):
                continue
            code = public_line_code(raw)
            external_id = _text(_first(raw, "cl", "codigoLinha"))
            if not code or not external_id:
                continue
            records.append(
                LineRecord(
                    external_id=external_id,
                    public_code=code,
                    direction=direction_from(raw.get("sl")),
                    origin_label=_text(_first(raw, "lt0", "origem")),
                    destination_label=_text(_first(raw, "lt1", "destino")),
                    search_terms=tuple(
                        dict.fromkeys(
                            term
                            for term in (
                                _text(raw.get("lt")),
                                _text(raw.get("lc")),
                                _text(raw.get("tp")),
                                _text(raw.get("ts")),
                            )
                            if term
                        )
                    ),
                )
            )
        return records

    @staticmethod
    def _parse_stops(payload: Any) -> list[StopRecord]:
        if not isinstance(payload, list):
            return []

        records: list[StopRecord] = []
        for raw in payload:
            if not isinstance(raw, dict):
                continue
            code = _text(_first(raw, "cp", "codigoParada"))
            latitude = _float_or_none(_first(raw, "py", "lat", "latitude"))
            longitude = _float_or_none(_first(raw, "px", "lon", "longitude"))
            if (
                not code
                or latitude is None
                or longitude is None
                or not -90 <= latitude <= 90
                or not -180 <= longitude <= 180
            ):
                continue
            records.append(
                StopRecord(
                    code=code,
                    name=_text(_first(raw, "np", "nome")) or code,
                    address=_text(_first(raw, "ed", "endereco")),
                    latitude=latitude,
                    longitude=longitude,
                )
            )
        return records

    @staticmethod
    def _parse_positions(payload: Any) -> list[VehiclePositionRecord]:
        if not isinstance(payload, dict):
            return []

        records: list[VehiclePositionRecord] = []
        for line in payload.get("l") or []:
            if not isinstance(line, dict):
                continue
            line_code = _text(_first(line, "c", "lc", "lt"))
            if not line_code:
                continue
            direction = direction_from(line.get("sl"))
            # A API v2.1 usa `vs` para os veículos de cada linha; versões
            # antigas/alguns adaptadores devolvem `p`.
            vehicles = line.get("vs") or line.get("p") or []
            for vehicle in vehicles:
                if not isinstance(vehicle, dict):
                    continue
                vehicle_code = _text(_first(vehicle, "p", "c", "prefixo"))
                latitude = _float_or_none(_first(vehicle, "py", "lat", "latitude"))
                longitude = _float_or_none(_first(vehicle, "px", "lon", "longitude"))
                captured_at = parse_timestamp(_first(vehicle, "ta", "t", "capturedAt"))
                if (
                    not vehicle_code
                    or latitude is None
                    or longitude is None
                    or captured_at is None
                    or not -90 <= latitude <= 90
                    or not -180 <= longitude <= 180
                ):
                    continue
                records.append(
                    VehiclePositionRecord(
                        line_code=line_code,
                        vehicle_code=vehicle_code,
                        latitude=latitude,
                        longitude=longitude,
                        captured_at=captured_at,
                        direction=direction,
                        is_accessible=bool(vehicle.get("a")),
                    )
                )
        return records

    # -- Enumeração de linhas ------------------------------------------------

    def discover_line_codes(self, terms: Iterable[str] | None = None) -> set[str]:
        """Códigos públicos encontrados pela busca por termos amplos.

        A API não expõe um endpoint de "todas as linhas", então a descoberta é
        feita com termos curtos (`0`–`9`) e complementada pelo GTFS.
        """

        found: set[str] = set()
        for term in terms or [str(number) for number in range(10)]:
            for record in self.search_lines(term):
                found.add(record.public_code)
        return found
