from datetime import timedelta

from django.conf import settings
from django.core import mail
from django.test import override_settings
from django.utils import timezone

from apps.accounts.models import EmailCode, User

from .base import AuthTestCase


class RequestCodeTests(AuthTestCase):
    def test_sends_code_without_storing_it_in_plain_text(self):
        response = self.request_code()

        assert response.status_code == 202, response.content
        assert len(mail.outbox) == 1

        code = self.last_code()
        stored = EmailCode.objects.get(email=self.email)
        assert stored.code_hash != code
        assert code not in stored.code_hash
        assert response.json()["message"]

    def test_unknown_and_existing_email_return_the_same_response(self):
        User.objects.create_user(email="existente@exemplo.com")

        first = self.request_code("novo@exemplo.com")
        self.skip_cooldown("novo@exemplo.com")
        second = self.request_code("existente@exemplo.com")

        assert first.status_code == second.status_code == 202
        assert first.json() == second.json()

    def test_cooldown_returns_429_with_retry_after(self):
        self.request_code()
        response = self.request_code()

        self.assert_problem(response, status_code=429, code="rate_limited")
        assert response.json()["retryAfter"] >= 1

    def test_new_code_invalidates_previous_one(self):
        self.request_code()
        first_code = self.last_code()
        self.skip_cooldown()
        self.request_code()

        response = self.verify_code(first_code)

        self.assert_problem(response, status_code=401, code="invalid_code")

    def test_email_rate_limit_is_enforced(self):
        limit = settings.OTP_RATE_LIMIT_PER_EMAIL

        for _ in range(limit):
            self.request_code()
            self.skip_cooldown()

        response = self.request_code()

        self.assert_problem(response, status_code=429, code="rate_limited")

    @override_settings(OTP_RATE_LIMIT_PER_IP=2)
    def test_forwarded_header_cannot_bypass_ip_rate_limit(self):
        self.request_code()
        self.skip_cooldown()
        self.request_code()
        self.skip_cooldown()

        response = self.client.post(
            "/v1/auth/request-code",
            {"email": self.email},
            format="json",
            HTTP_X_FORWARDED_FOR="203.0.113.99",
        )

        self.assert_problem(response, status_code=429, code="rate_limited")

    def test_invalid_email_returns_400(self):
        response = self.client.post(
            "/v1/auth/request-code", {"email": "sem-arroba"}, format="json"
        )

        self.assert_problem(response, status_code=400, code="invalid_request")
        assert "email" in response.json()["errors"]

    def test_code_expires_at_configured_ttl(self):
        before = timezone.now()
        self.request_code()
        stored = EmailCode.objects.get(email=self.email)

        expected = before + timedelta(seconds=settings.OTP_TTL_SECONDS)
        assert abs((stored.expires_at - expected).total_seconds()) < 5
