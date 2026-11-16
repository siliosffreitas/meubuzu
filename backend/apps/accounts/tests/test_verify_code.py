from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from apps.accounts.models import EmailCode, RefreshSession, User

from .base import AuthTestCase


class VerifyCodeTests(AuthTestCase):
    def test_valid_code_creates_user_and_returns_session(self):
        response = self.login()

        user = User.objects.get(email=self.email)
        assert user.is_email_verified
        assert response["user"]["email"] == self.email
        assert response["accessToken"]
        assert response["refreshToken"]
        assert response["entitlements"]["accessLevel"] == "catalog_only"
        assert response["entitlements"]["canTrack"] is False
        assert response["preferences"]["selectedCity"] is None
        assert RefreshSession.objects.filter(user=user).count() == 1

    def test_login_is_case_insensitive(self):
        self.request_code("Passageiro@Exemplo.com")

        response = self.verify_code(self.last_code(), "passageiro@exemplo.com")

        assert response.status_code == 200, response.content
        assert User.objects.filter(email="passageiro@exemplo.com").exists()

    def test_wrong_code_returns_401_and_counts_attempt(self):
        self.request_code()

        response = self.verify_code("000000" if self.last_code() != "000000" else "111111")

        self.assert_problem(response, status_code=401, code="invalid_code")
        stored = EmailCode.objects.get(email=self.email)
        assert stored.attempts == 1

    def test_too_many_wrong_attempts_returns_429(self):
        self.request_code()
        wrong = "000000" if self.last_code() != "000000" else "111111"

        for _ in range(settings.OTP_MAX_ATTEMPTS - 1):
            self.verify_code(wrong)

        response = self.verify_code(wrong)

        self.assert_problem(response, status_code=429, code="too_many_attempts")

    def test_attempts_already_at_limit_are_blocked(self):
        self.request_code()
        EmailCode.objects.filter(email=self.email).update(
            attempts=settings.OTP_MAX_ATTEMPTS
        )

        response = self.verify_code(self.last_code())

        self.assert_problem(response, status_code=429, code="too_many_attempts")

    def test_expired_code_returns_401(self):
        self.request_code()
        EmailCode.objects.filter(email=self.email).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )

        response = self.verify_code(self.last_code())

        self.assert_problem(response, status_code=401, code="code_expired")

    def test_code_cannot_be_used_twice(self):
        code = None
        self.request_code()
        code = self.last_code()

        assert self.verify_code(code).status_code == 200
        response = self.verify_code(code)

        self.assert_problem(response, status_code=401, code="code_already_used")

    def test_unknown_email_returns_generic_invalid_code(self):
        response = self.verify_code("123456", "ninguem@exemplo.com")

        self.assert_problem(response, status_code=401, code="invalid_code")

    def test_code_requires_six_digits(self):
        self.request_code()

        response = self.client.post(
            "/v1/auth/verify-code",
            {"email": self.email, "code": "12345"},
            format="json",
        )

        self.assert_problem(response, status_code=400, code="invalid_request")
