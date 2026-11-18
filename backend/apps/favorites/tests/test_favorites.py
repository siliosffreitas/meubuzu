from decimal import Decimal

from django.db import IntegrityError, transaction

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City, Line
from apps.catalog.text import normalize_search_text
from apps.favorites.models import Favorite


def make_line(city: City, code: str, boarding_code: str = "") -> Line:
    return Line.objects.create(
        city=city,
        code=code,
        boarding_code=boarding_code,
        name=f"LINHA {code}",
        origin="Origem",
        destination="Destino",
        search_text=normalize_search_text(" ".join((code, boarding_code, "LINHA"))),
    )


class FavoritesApiTests(AuthTestCase, SessionMixin):
    def setUp(self):
        super().setUp()
        user = make_user()
        access_token, _ = start_session(user)
        self.authenticate(access_token)
        self.user = user
        self.city = City.objects.get(slug="teresina")
        self.line = make_line(self.city, "0001", boarding_code="1")

    def _add(self, line: Line | None = None, city: City | None = None):
        return self.client.post(
            "/v1/favorites",
            {
                "lineId": str((line or self.line).id),
                "citySlug": (city or self.city).slug,
            },
            format="json",
        )

    def test_list_starts_empty(self):
        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert response.json() == {"favorites": []}

    def test_add_then_list_returns_line_and_city(self):
        created = self._add()

        assert created.status_code == 201, created.content
        payload = created.json()
        assert payload["lineId"] == str(self.line.id)
        assert payload["line"]["name"] == "LINHA 0001"
        assert payload["city"]["slug"] == "teresina"
        assert payload["city"]["timezone"] == "America/Fortaleza"

        response = self.client.get("/v1/favorites")
        assert response.status_code == 200, response.content
        favorites = response.json()["favorites"]
        assert [item["id"] for item in favorites] == [payload["id"]]
        assert favorites[0]["line"]["boardingCode"] == "1"

    def test_add_is_idempotent(self):
        first = self._add()
        second = self._add()

        assert first.status_code == 201, first.content
        assert second.status_code == 200, second.content
        assert first.json()["id"] == second.json()["id"]
        assert Favorite.objects.filter(user=self.user).count() == 1

    def test_add_accepts_boarding_code(self):
        response = self.client.post(
            "/v1/favorites",
            {"lineId": "1", "citySlug": self.city.slug},
            format="json",
        )

        assert response.status_code == 201, response.content
        assert response.json()["lineId"] == str(self.line.id)

    def test_delete_by_line_id(self):
        self._add()

        response = self.client.delete(f"/v1/favorites/{self.line.id}")

        assert response.status_code == 204, response.content
        assert self.client.get("/v1/favorites").json() == {"favorites": []}

    def test_delete_by_line_code(self):
        self._add()

        response = self.client.delete("/v1/favorites/0001")

        assert response.status_code == 204, response.content

    def test_delete_unknown_favorite_returns_stable_error(self):
        response = self.client.delete("/v1/favorites/9999")

        self.assert_problem(response, status_code=404, code="favorite_not_found")

    def test_favorites_are_private_to_user(self):
        self._add()
        other = make_user(email="outro@exemplo.com")
        other_token, _ = start_session(other)
        self.authenticate(other_token)

        assert self.client.get("/v1/favorites").json() == {"favorites": []}
        response = self.client.delete(f"/v1/favorites/{self.line.id}")
        self.assert_problem(response, status_code=404, code="favorite_not_found")

        self.authenticate(start_session(self.user)[0])
        assert len(self.client.get("/v1/favorites").json()["favorites"]) == 1

    def test_list_includes_favorites_from_other_cities(self):
        other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        other_line = make_line(other_city, "9001", boarding_code="9")
        self._add()
        response = self._add(other_line, other_city)

        assert response.status_code == 201, response.content
        favorites = self.client.get("/v1/favorites").json()["favorites"]
        assert {item["city"]["slug"] for item in favorites} == {"teresina", "outra"}

    def test_list_orders_by_sglinha_within_city(self):
        line10 = make_line(self.city, "0010", boarding_code="10")
        line2 = make_line(self.city, "0002", boarding_code="2")
        line301 = make_line(self.city, "0301", boarding_code="0301")
        line_blank = make_line(self.city, "0099", boarding_code="")

        for line in (line10, line_blank, line301, line2):
            self._add(line)

        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert [item["line"]["id"] for item in response.json()["favorites"]] == [
            str(line2.id),
            str(line10.id),
            str(line301.id),
            str(line_blank.id),
        ]

    def test_list_orders_by_city_then_sglinha(self):
        other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        teresina_2 = make_line(self.city, "0002", boarding_code="2")
        outra_1 = make_line(other_city, "9001", boarding_code="1")
        outra_9 = make_line(other_city, "9009", boarding_code="9")

        for line in (teresina_2, outra_9, outra_1):
            self._add(line, line.city)

        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert [item["line"]["id"] for item in response.json()["favorites"]] == [
            str(outra_1.id),
            str(outra_9.id),
            str(teresina_2.id),
        ]

    def test_city_and_line_errors(self):
        missing_city = self.client.post(
            "/v1/favorites",
            {"lineId": str(self.line.id), "citySlug": "inexistente"},
            format="json",
        )
        self.assert_problem(missing_city, status_code=404, code="city_not_found")

        inactive_city = City.objects.create(
            slug="inativa",
            name="Inativa",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
            is_active=False,
        )
        inactive = self.client.post(
            "/v1/favorites",
            {"lineId": str(self.line.id), "citySlug": inactive_city.slug},
            format="json",
        )
        self.assert_problem(inactive, status_code=409, code="city_inactive")

        unknown_line = self.client.post(
            "/v1/favorites",
            {"lineId": "linha-inexistente", "citySlug": self.city.slug},
            format="json",
        )
        self.assert_problem(unknown_line, status_code=404, code="line_not_found")

    def test_requires_access_token(self):
        self.clear_credentials()

        for response in (
            self.client.get("/v1/favorites"),
            self._add(),
            self.client.delete(f"/v1/favorites/{self.line.id}"),
        ):
            assert response.status_code == 401, response.content

    def test_unique_constraint_blocks_duplicates(self):
        Favorite.objects.create(user=self.user, line=self.line)
        with transaction.atomic(), self.assertRaises(IntegrityError):
            Favorite.objects.create(user=self.user, line=self.line)
