from django.urls import path

from .views import CityDetailView, CityListView, StopDetailView, StopListView

app_name = "catalog"

urlpatterns = [
    path("cities", CityListView.as_view(), name="city-list"),
    path("cities/<slug:city_slug>", CityDetailView.as_view(), name="city-detail"),
    path("cities/<slug:city_slug>/stops", StopListView.as_view(), name="stop-list"),
    path(
        "cities/<slug:city_slug>/stops/<uuid:stop_id>",
        StopDetailView.as_view(),
        name="stop-detail",
    ),
]
