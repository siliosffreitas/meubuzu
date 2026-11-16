from apps.accounts.models import RefreshSession

from .base import AuthTestCase, SessionMixin


class RefreshTests(AuthTestCase, SessionMixin):
    def refresh(self, token: str):
        return self.client.post(
            "/v1/auth/refresh", {"refreshToken": token}, format="json"
        )

    def test_refresh_rotates_tokens(self):
        session = self.login()

        response = self.refresh(session["refreshToken"])

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["refreshToken"] != session["refreshToken"]
        assert body["accessToken"] != session["accessToken"]
        assert body["user"]["email"] == self.email

        sessions = RefreshSession.objects.order_by("created_at")
        assert sessions.count() == 2
        old = sessions.first()
        assert old.revoked_at is not None
        assert old.replaced_by is not None

    def test_reusing_rotated_token_revokes_the_family(self):
        session = self.login()
        rotated = self.refresh(session["refreshToken"]).json()

        reuse = self.refresh(session["refreshToken"])
        self.assert_problem(reuse, status_code=401, code="refresh_reuse_detected")

        after = self.refresh(rotated["refreshToken"])
        self.assert_problem(after, status_code=401, code="invalid_refresh_token")

    def test_unknown_refresh_token_returns_401(self):
        response = self.refresh("token-que-nao-existe")

        self.assert_problem(response, status_code=401, code="invalid_refresh_token")

    def test_missing_refresh_token_returns_400(self):
        response = self.client.post("/v1/auth/refresh", {}, format="json")

        self.assert_problem(response, status_code=400, code="invalid_request")


class LogoutTests(AuthTestCase, SessionMixin):
    def test_logout_revokes_current_session(self):
        session = self.login()
        self.authenticate(session["accessToken"])

        response = self.client.post("/v1/auth/logout")

        assert response.status_code == 204
        refresh = self.client.post(
            "/v1/auth/refresh",
            {"refreshToken": session["refreshToken"]},
            format="json",
        )
        assert refresh.status_code == 401
        assert refresh.json()["code"] == "invalid_refresh_token"

    def test_logout_requires_authentication(self):
        response = self.client.post("/v1/auth/logout")

        self.assert_problem(response, status_code=401, code="not_authenticated")
