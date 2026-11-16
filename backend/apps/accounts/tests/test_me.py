from apps.accounts.tokens import decode_access_token

from .base import AuthTestCase, SessionMixin


class MeTests(AuthTestCase, SessionMixin):
    def test_me_returns_user_and_catalog_only_access(self):
        session = self.login()
        self.authenticate(session["accessToken"])

        response = self.client.get("/v1/me")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["email"] == self.email
        assert body["emailVerifiedAt"] is not None
        assert body["preferences"]["selectedCity"] is None
        assert body["entitlements"]["accessLevel"] == "catalog_only"
        assert body["entitlements"]["canManageFavorites"] is False

    def test_me_requires_access_token(self):
        response = self.client.get("/v1/me")

        self.assert_problem(response, status_code=401, code="not_authenticated")

    def test_invalid_access_token_is_rejected(self):
        self.authenticate("nao-e-um-jwt")

        response = self.client.get("/v1/me")

        self.assert_problem(response, status_code=401, code="invalid_access_token")

    def test_access_token_carries_session_id(self):
        session = self.login()

        payload = decode_access_token(session["accessToken"])

        assert payload["typ"] == "access"
        assert payload["sid"]
        assert payload["sub"]
        assert payload["exp"] > payload["iat"]
