from decimal import Decimal

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City


def make_inactive_city() -> City:
    return City.objects.create(
        slug="inativa",
        name="Inativa",
        state="PI",
        timezone="America/Fortaleza",
        latitude=Decimal("-5.0"),
        longitude=Decimal("-42.0"),
        is_active=False,
    )


class CityApiTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        user = make_user()
        access_token, _ = start_session(user)
        self.authenticate(access_token)

    def test_lists_active_cities(self):
        response = self.client.get("/v1/cities")

        assert response.status_code == 200, response.content
        body = response.json()
        slugs = [city["slug"] for city in body["cities"]]
        assert "teresina" in slugs
        # São Paulo entra inativa: só aparece após ativação explícita.
        assert "sao-paulo" not in slugs

        teresina = next(city for city in body["cities"] if city["slug"] == "teresina")
        assert teresina["name"] == "Teresina"
        assert teresina["label"] == "Teresina - PI"
        assert teresina["state"] == "PI"
        assert teresina["country"] == "BR"
        assert teresina["timezone"] == "America/Fortaleza"
        assert teresina["center"]["latitude"] == -5.16
        assert teresina["center"]["longitude"] == -42.79
        assert teresina["isActive"] is True

    def test_hides_inactive_cities(self):
        make_inactive_city()

        response = self.client.get("/v1/cities")

        slugs = [city["slug"] for city in response.json()["cities"]]
        assert "inativa" not in slugs

    def test_city_detail(self):
        response = self.client.get("/v1/cities/teresina")

        assert response.status_code == 200, response.content
        assert response.json()["slug"] == "teresina"

    def test_unknown_city_returns_not_found(self):
        response = self.client.get("/v1/cities/inexistente")

        self.assert_problem(response, status_code=404, code="city_not_found")

    def test_inactive_city_returns_conflict(self):
        make_inactive_city()

        response = self.client.get("/v1/cities/inativa")

        self.assert_problem(response, status_code=409, code="city_inactive")

    def test_requires_authentication(self):
        self.clear_credentials()

        response = self.client.get("/v1/cities")

        self.assert_problem(response, status_code=401, code="not_authenticated")
