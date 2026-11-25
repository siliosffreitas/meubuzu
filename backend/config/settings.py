"""Configurações do backend do MeuBuzu.

Valores sensíveis vêm de variáveis de ambiente (`.env` local, secret manager em
produção). Nunca versione o `.env`.
"""

from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlparse

from celery.schedules import crontab
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def _bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default


def _list(name: str, default: str) -> list[str]:
    raw = os.getenv(name, default)
    return [item.strip() for item in raw.split(",") if item.strip()]


SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY",
    "dev-apenas-local-9L8YFQ96arBByXuuU6AagKM5PEMYVliXZukb73SDjHWMVoHY8",
)
DEBUG = _bool("DJANGO_DEBUG", True)
ALLOWED_HOSTS = _list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "apps.accounts",
    "apps.catalog",
    "apps.tracking",
    "apps.favorites",
    "apps.integrations",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# --- Banco de dados ---------------------------------------------------------

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgres://meubuzu:meubuzu@127.0.0.1:5432/meubuzu"
)

if DATABASE_URL.startswith("sqlite"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    _db = urlparse(DATABASE_URL)
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": _db.path.lstrip("/") or "meubuzu",
            "USER": _db.username or "",
            "PASSWORD": _db.password or "",
            "HOST": _db.hostname or "127.0.0.1",
            "PORT": str(_db.port or 5432),
            "CONN_MAX_AGE": 60,
        }
    }

# --- Cache (rate limit, locks) ---------------------------------------------

REDIS_URL = os.getenv("REDIS_URL", "")
if REDIS_URL:
    CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.redis.RedisCache",
            "LOCATION": REDIS_URL,
        }
    }
else:
    CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
            "LOCATION": "meubuzu",
        }
    }

# Catálogo de linhas/paradas é quase estático (import semanal/mensal).
CATALOG_CACHE_TTL_SECONDS = _int("CATALOG_CACHE_TTL_SECONDS", 300)

# --- Rastreamento ------------------------------------------------------------

# Por enquanto as posições vêm de CSVs de demonstração dentro do backend.
# Em produção esta fonte é proibida: o crawler/API de Teresina substituirá o adaptador.
TRACKING_POSITIONS_SOURCE = os.getenv("TRACKING_POSITIONS_SOURCE", "csv_demo")
_tracking_csv_dir = os.getenv("TRACKING_CSV_DIR", "").strip()
TRACKING_CSV_DIR = Path(
    _tracking_csv_dir or BASE_DIR / "apps" / "tracking" / "data" / "locations"
)
TRACKING_DEMO_ACCESS_ENABLED = _bool("TRACKING_DEMO_ACCESS_ENABLED", DEBUG)
TRACKING_POSITION_WINDOW_SECONDS = _int("TRACKING_POSITION_WINDOW_SECONDS", 300)
# Corte rígido das posições live devolvidas ao app. Posições mais antigas que
# isto não saem do endpoint, mesmo que ainda existam em LatestPosition.
TRACKING_LIVE_MAX_POSITION_AGE_SECONDS = _int(
    "TRACKING_LIVE_MAX_POSITION_AGE_SECONDS",
    TRACKING_POSITION_WINDOW_SECONDS,
)
TRACKING_STALE_AFTER_SECONDS = _int("TRACKING_STALE_AFTER_SECONDS", 120)
TRACKING_CACHE_TTL_SECONDS = _int("TRACKING_CACHE_TTL_SECONDS", 10)

# Libera o rastreamento de fontes `live` sem billing. Somente staging: em
# produção o acesso continua dependendo de trial/assinatura.
TRACKING_LIVE_ACCESS_ENABLED = _bool("TRACKING_LIVE_ACCESS_ENABLED", False)

# Histórico de posições: retenção curta, particionada por dia. O trim horário
# mantém a retenção efetiva entre 24 e 25 horas.
TRACKING_HISTORY_ENABLED = _bool("TRACKING_HISTORY_ENABLED", True)
TRACKING_HISTORY_RETENTION_HOURS = _int("TRACKING_HISTORY_RETENTION_HOURS", 24)
TRACKING_HISTORY_PARTITION_UNIT = os.getenv("TRACKING_HISTORY_PARTITION_UNIT", "day")
TRACKING_HISTORY_TRIM_MINUTES = _int("TRACKING_HISTORY_TRIM_MINUTES", 60)
TRACKING_HISTORY_TRIM_BATCH = _int("TRACKING_HISTORY_TRIM_BATCH", 50_000)
# Capturas mais antigas que isto são descartadas na ingestão: elas cairiam em
# partições já expiradas e seriam removidas no próximo trim.
TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS = _int(
    "TRACKING_HISTORY_MAX_CAPTURE_AGE_SECONDS", 600
)
TRACKING_CRAWL_LOCK_SECONDS = _int("TRACKING_CRAWL_LOCK_SECONDS", 25)

# --- Integração SPTrans (Olho Vivo + GTFS) ----------------------------------

SPTRANS_API_BASE_URL = os.getenv(
    "SPTRANS_API_BASE_URL", "https://api.olhovivo.sptrans.com.br/v2.1"
).rstrip("/")
# Nunca versionado: o token fica apenas no `.env`/secret manager.
SPTRANS_API_TOKEN = os.getenv("SPTRANS_API_TOKEN", "").strip()
SPTRANS_API_TIMEOUT_SECONDS = _int("SPTRANS_API_TIMEOUT_SECONDS", 30)
SPTRANS_API_REQUESTS_PER_SECOND = _int("SPTRANS_API_REQUESTS_PER_SECOND", 5)
SPTRANS_API_MAX_RETRIES = _int("SPTRANS_API_MAX_RETRIES", 3)
_sp_trans_gtfs_dir = os.getenv("SPTRANS_GTFS_DIR", "").strip()
SPTRANS_GTFS_DIR = Path(
    _sp_trans_gtfs_dir or BASE_DIR / "data" / "gtfs" / "sptrans"
)

# --- Celery -----------------------------------------------------------------

CELERY_BROKER_URL = os.getenv(
    "CELERY_BROKER_URL", REDIS_URL or "redis://127.0.0.1:6379/1"
)
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "") or None
CELERY_TASK_ALWAYS_EAGER = _bool("CELERY_TASK_ALWAYS_EAGER", False)
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_TIMEZONE = "UTC"
CELERY_ENABLE_UTC = True
CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TASK_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_RESULT_SERIALIZER = "json"
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True

CELERY_BEAT_SCHEDULE = {
    # Catálogo semanal: segunda-feira, 06:00 UTC (03:00 em São Paulo).
    "catalog-sptrans-weekly": {
        "task": "apps.catalog.tasks.import_sptrans_catalog_task",
        "schedule": crontab(minute=0, hour=6, day_of_week=1),
        "options": {"expires": 3600},
    },
    # Posições a cada 30 s; `expires` evita fila de execuções atrasadas.
    "tracking-sptrans-positions": {
        "task": "apps.tracking.tasks.crawl_sptrans_positions_task",
        "schedule": 30.0,
        "options": {"expires": 25},
    },
    # Partições do histórico: cria a de amanhã e dropa as expiradas.
    "tracking-history-partitions-daily": {
        "task": "apps.tracking.tasks.maintain_tracking_partitions_task",
        "schedule": crontab(minute=5, hour=0),
        "options": {"expires": 1800},
    },
    # Trim intradiário: mantém a retenção efetiva próxima de 24 h.
    "tracking-history-trim-hourly": {
        "task": "apps.tracking.tasks.trim_position_history_task",
        "schedule": crontab(minute=10),
        "options": {"expires": 1800},
    },
}

# --- E-mail -----------------------------------------------------------------

EMAIL_BACKEND = os.getenv(
    "EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend"
)
EMAIL_HOST = os.getenv("EMAIL_HOST", "127.0.0.1")
EMAIL_PORT = _int("EMAIL_PORT", 1025)
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = _bool("EMAIL_USE_TLS", False)
DEFAULT_FROM_EMAIL = os.getenv(
    "DEFAULT_FROM_EMAIL", "MeuBuzu <nao-responda@meubuzu.local>"
)

# --- Autenticação -----------------------------------------------------------

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]

# --- API --------------------------------------------------------------------

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "apps.accounts.authentication.AccessTokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "EXCEPTION_HANDLER": "apps.common.exceptions.api_exception_handler",
    "DEFAULT_RENDERER_CLASSES": (
        ["rest_framework.renderers.JSONRenderer", "rest_framework.renderers.BrowsableAPIRenderer"]
        if DEBUG
        else ["rest_framework.renderers.JSONRenderer"]
    ),
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
}

# --- Regras de acesso -------------------------------------------------------

OTP_TTL_SECONDS = _int("OTP_TTL_SECONDS", 600)
OTP_RESEND_COOLDOWN_SECONDS = _int("OTP_RESEND_COOLDOWN_SECONDS", 60)
OTP_MAX_ATTEMPTS = _int("OTP_MAX_ATTEMPTS", 5)
OTP_RATE_LIMIT_PER_EMAIL = _int("OTP_RATE_LIMIT_PER_EMAIL", 5)
OTP_RATE_LIMIT_PER_IP = _int("OTP_RATE_LIMIT_PER_IP", 20)

# Só ative atrás de um proxy confiável; do contrário X-Forwarded-For é forjável.
TRUST_X_FORWARDED_FOR = _bool("TRUST_X_FORWARDED_FOR", False)

ACCESS_TOKEN_TTL_SECONDS = _int("ACCESS_TOKEN_TTL_SECONDS", 900)
REFRESH_TOKEN_TTL_SECONDS = _int("REFRESH_TOKEN_TTL_SECONDS", 2_592_000)

# --- Internacionalização ----------------------------------------------------

LANGUAGE_CODE = "pt-br"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# --- Arquivos estáticos -----------------------------------------------------

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Segurança em produção --------------------------------------------------

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31_536_000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

# --- Logs -------------------------------------------------------------------

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "%(asctime)s %(levelname)s %(name)s %(message)s",
        }
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "default"},
    },
    "root": {"handlers": ["console"], "level": "INFO"},
    "loggers": {
        "django.request": {"handlers": ["console"], "level": "WARNING", "propagate": False},
        "apps": {"handlers": ["console"], "level": "INFO", "propagate": False},
    },
}
