from django.urls import path

from .views import FavoriteDetailView, FavoritesView

app_name = "favorites"

urlpatterns = [
    path("favorites", FavoritesView.as_view(), name="favorite-list"),
    path(
        "favorites/<slug:city_slug>/<str:boarding_code>",
        FavoriteDetailView.as_view(),
        name="favorite-detail",
    ),
]
