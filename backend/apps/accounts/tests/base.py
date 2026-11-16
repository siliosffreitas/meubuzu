import re
from datetime import timedelta

from django.conf import settings
from django.core import mail
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import EmailCode, User

CODE_RE = re.compile(r"\b(\d{6})\b")


@override_settings(
    EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
    CACHES={
        "default": {
            "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
            "LOCATION": "auth-tests",
        }
    },
)
class AuthTestCase(TestCase):
    email = "passageiro@exemplo.com"

    def setUp(self):
        cache.clear()
        mail.outbox.clear()
        self.client = APIClient()

    def request_code(self, email: str | None = None):
        return self.client.post(
            "/v1/auth/request-code",
            {"email": email or self.email},
            format="json",
        )

    def last_code(self) -> str:
        match = CODE_RE.search(mail.outbox[-1].body)
        assert match is not None, "e-mail não contém código"
        return match.group(1)

    def verify_code(self, code: str, email: str | None = None):
        return self.client.post(
            "/v1/auth/verify-code",
            {"email": email or self.email, "code": code},
            format="json",
        )

    def login(self) -> dict:
        self.request_code()
        response = self.verify_code(self.last_code())
        assert response.status_code == 200, response.content
        return response.json()

    def skip_cooldown(self, email: str | None = None) -> None:
        """Recua o código mais recente para permitir novo pedido."""
        EmailCode.objects.filter(email=email or self.email).update(
            created_at=timezone.now()
            - timedelta(seconds=settings.OTP_RESEND_COOLDOWN_SECONDS + 5)
        )

    def assert_problem(self, response, *, status_code: int, code: str) -> None:
        assert response.status_code == status_code, response.content
        assert response["Content-Type"].startswith("application/problem+json")
        body = response.json()
        assert body["code"] == code, body
        assert body["status"] == status_code


class SessionMixin:
    def authenticate(self, access_token: str) -> None:
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access_token}")

    def clear_credentials(self) -> None:
        self.client.credentials()


def make_user(email: str = "existente@exemplo.com") -> User:
    user = User.objects.create_user(email=email)
    user.mark_email_verified()
    return user
