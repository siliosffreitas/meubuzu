from django.urls import path

from .views import FavoriteDetailView, FavoritesView

app_name = "favorites"

urlpatterns = [
    path("favorites", FavoritesView.as_view(), name="favorite-list"),
    path("favorites/<str:line_id>", FavoriteDetailView.as_view(), name="favorite-detail"),
]
