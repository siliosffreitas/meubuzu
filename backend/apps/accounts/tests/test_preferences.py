from apps.accounts.models import User, UserPreference
from apps.accounts.services import start_session
from apps.catalog.models import City

from .base import AuthTestCase, SessionMixin


class PreferencesTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        self.session = self.login()
        self.authenticate(self.session["accessToken"])

    def select_city(self, slug: str = "teresina"):
        return self.client.put(
            "/v1/me/preferences",
            {"selectedCitySlug": slug},
            format="json",
        )

    def test_new_user_has_no_selected_city(self):
        response = self.client.get("/v1/me/preferences")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["selectedCity"] is None
        assert body["version"] == 0
        assert body["updatedAt"] is None
        assert not UserPreference.objects.filter(user__email=self.email).exists()

    def test_selects_city_and_increments_version(self):
        response = self.select_city()

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["selectedCity"]["slug"] == "teresina"
        assert body["selectedCity"]["timezone"] == "America/Fortaleza"
        assert body["version"] == 1
        assert body["updatedAt"] is not None

        preference = UserPreference.objects.get(user__email=self.email)
        assert preference.selected_city.slug == "teresina"

    def test_selecting_the_same_city_is_idempotent(self):
        self.select_city()
        response = self.select_city()

        assert response.status_code == 200, response.content
        assert response.json()["version"] == 1

    def test_missing_city_slug_is_invalid(self):
        response = self.client.put("/v1/me/preferences", {}, format="json")

        self.assert_problem(response, status_code=400, code="invalid_request")

    def test_unknown_city_returns_city_not_found(self):
        response = self.select_city("inexistente")

        self.assert_problem(response, status_code=404, code="city_not_found")

    def test_inactive_city_returns_city_inactive(self):
        City.objects.create(
            slug="inativa",
            name="Inativa",
            state="PI",
            timezone="America/Fortaleza",
            latitude="-5.0",
            longitude="-42.0",
            is_active=False,
        )

        response = self.select_city("inativa")

        self.assert_problem(response, status_code=409, code="city_inactive")

    def test_preferences_are_restored_in_a_new_session(self):
        self.select_city()

        user = User.objects.get(email=self.email)
        access_token, _ = start_session(user)
        self.authenticate(access_token)

        response = self.client.get("/v1/me")

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["preferences"]["selectedCity"]["slug"] == "teresina"
        assert body["preferences"]["version"] == 1

    def test_refresh_returns_preferences(self):
        self.select_city()

        response = self.client.post(
            "/v1/auth/refresh",
            {"refreshToken": self.session["refreshToken"]},
            format="json",
        )

        assert response.status_code == 200, response.content
        body = response.json()
        assert body["preferences"]["selectedCity"]["slug"] == "teresina"

    def test_requires_authentication(self):
        self.clear_credentials()

        response = self.client.get("/v1/me/preferences")

        self.assert_problem(response, status_code=401, code="not_authenticated")
