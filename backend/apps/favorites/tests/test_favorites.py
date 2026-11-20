from decimal import Decimal

from django.db import IntegrityError, transaction

from apps.accounts.services import start_session
from apps.accounts.tests.base import AuthTestCase, SessionMixin, make_user
from apps.catalog.models import City, Line
from apps.catalog.text import normalize_search_text
from apps.favorites.models import Favorite


def make_line(city: City, code: str, boarding_code: str) -> Line:
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
        self.line = make_line(self.city, "0001", "1")

    def _add(self, line: Line | None = None, city: City | None = None, **overrides):
        payload = {
            "boardingCode": (line or self.line).boarding_code,
            "citySlug": (city or self.city).slug,
        }
        payload.update(overrides)
        return self.client.post("/v1/favorites", payload, format="json")

    def _delete(self, city_slug: str, boarding_code: str):
        return self.client.delete(f"/v1/favorites/{city_slug}/{boarding_code}")

    def test_list_starts_empty(self):
        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert response.json() == {"favorites": []}

    def test_add_then_list_returns_line_and_city_without_ids(self):
        created = self._add()

        assert created.status_code == 201, created.content
        payload = created.json()
        assert payload["boardingCode"] == "1"
        assert payload["line"]["boardingCode"] == "1"
        assert payload["line"]["name"] == "LINHA 0001"
        assert payload["city"]["slug"] == "teresina"
        assert payload["city"]["timezone"] == "America/Fortaleza"
        assert "id" not in payload
        assert "lineId" not in payload
        assert "id" not in payload["line"]

        response = self.client.get("/v1/favorites")
        assert response.status_code == 200, response.content
        favorites = response.json()["favorites"]
        assert [item["boardingCode"] for item in favorites] == ["1"]
        assert all("id" not in item and "lineId" not in item for item in favorites)

    def test_add_is_idempotent(self):
        first = self._add()
        second = self._add()

        assert first.status_code == 201, first.content
        assert second.status_code == 200, second.content
        assert first.json()["boardingCode"] == second.json()["boardingCode"] == "1"
        assert Favorite.objects.filter(user=self.user).count() == 1

    def test_add_does_not_accept_uuid_or_internal_code(self):
        by_uuid = self._add(boardingCode=str(self.line.id))
        by_internal_code = self._add(boardingCode="0001")

        self.assert_problem(by_uuid, status_code=404, code="line_not_found")
        self.assert_problem(by_internal_code, status_code=404, code="line_not_found")

    def test_delete_by_city_and_boarding_code(self):
        self._add()

        response = self._delete("teresina", "1")

        assert response.status_code == 204, response.content
        assert self.client.get("/v1/favorites").json() == {"favorites": []}

    def test_delete_requires_city_slug(self):
        self._add()

        response = self.client.delete("/v1/favorites/1")

        assert response.status_code == 404, response.content

    def test_delete_unknown_favorite_returns_stable_error(self):
        response = self._delete("teresina", "9999")

        self.assert_problem(response, status_code=404, code="favorite_not_found")

    def test_delete_does_not_confuse_same_code_in_another_city(self):
        other_city = City.objects.create(
            slug="outra",
            name="Outra",
            state="PI",
            timezone="America/Fortaleza",
            latitude=Decimal("-5.0"),
            longitude=Decimal("-42.0"),
        )
        other_line = make_line(other_city, "9001", "1")
        self._add()
        self._add(other_line, other_city)

        response = self._delete("outra", "1")

        assert response.status_code == 204, response.content
        assert [
            (item["city"]["slug"], item["boardingCode"])
            for item in self.client.get("/v1/favorites").json()["favorites"]
        ] == [("teresina", "1")]

    def test_favorites_are_private_to_user(self):
        self._add()
        other = make_user(email="outro@exemplo.com")
        other_token, _ = start_session(other)
        self.authenticate(other_token)

        assert self.client.get("/v1/favorites").json() == {"favorites": []}
        response = self._delete("teresina", "1")
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
        other_line = make_line(other_city, "9001", "9")
        self._add()
        response = self._add(other_line, other_city)

        assert response.status_code == 201, response.content
        favorites = self.client.get("/v1/favorites").json()["favorites"]
        assert {item["city"]["slug"] for item in favorites} == {"teresina", "outra"}

    def test_list_orders_by_sglinha_within_city(self):
        line10 = make_line(self.city, "0010", "10")
        line2 = make_line(self.city, "0002", "2")
        line301 = make_line(self.city, "0301", "0301")
        line_text = make_line(self.city, "0099", "ABC")

        for line in (line10, line_text, line301, line2):
            self._add(line)

        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert [item["boardingCode"] for item in response.json()["favorites"]] == [
            "2",
            "10",
            "0301",
            "ABC",
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
        teresina_2 = make_line(self.city, "0002", "2")
        outra_1 = make_line(other_city, "9001", "1")
        outra_9 = make_line(other_city, "9009", "9")

        for line in (teresina_2, outra_9, outra_1):
            self._add(line, line.city)

        response = self.client.get("/v1/favorites")

        assert response.status_code == 200, response.content
        assert [
            (item["city"]["slug"], item["boardingCode"])
            for item in response.json()["favorites"]
        ] == [
            ("outra", "1"),
            ("outra", "9"),
            ("teresina", "2"),
        ]

    def test_city_and_line_errors(self):
        missing_city = self._add(citySlug="inexistente")
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
        inactive = self._add(citySlug=inactive_city.slug)
        self.assert_problem(inactive, status_code=409, code="city_inactive")

        unknown_line = self._add(boardingCode="linha-inexistente")
        self.assert_problem(unknown_line, status_code=404, code="line_not_found")

    def test_requires_access_token(self):
        self.clear_credentials()

        for response in (
            self.client.get("/v1/favorites"),
            self._add(),
            self._delete("teresina", "1"),
        ):
            assert response.status_code == 401, response.content

    def test_unique_constraint_blocks_duplicates(self):
        Favorite.objects.create(user=self.user, line=self.line)
        with transaction.atomic(), self.assertRaises(IntegrityError):
            Favorite.objects.create(user=self.user, line=self.line)
