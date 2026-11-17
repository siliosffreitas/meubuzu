from django.urls import path

from .views import (
    CityDetailView,
    CityListView,
    LineDetailView,
    LineListView,
    LineRouteView,
    LineStopsView,
    StopDetailView,
    StopLinesView,
    StopListView,
)

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
    path(
        "cities/<slug:city_slug>/stops/<str:stop_id>/lines",
        StopLinesView.as_view(),
        name="stop-lines",
    ),
    # Linhas e itinerários do catálogo da cidade
    path("cities/<slug:city_slug>/lines", LineListView.as_view(), name="line-list"),
    path(
        "cities/<slug:city_slug>/lines/<str:line_id>",
        LineDetailView.as_view(),
        name="line-detail",
    ),
    path(
        "cities/<slug:city_slug>/lines/<str:line_id>/stops",
        LineStopsView.as_view(),
        name="line-stops",
    ),
    path(
        "cities/<slug:city_slug>/lines/<str:line_id>/route",
        LineRouteView.as_view(),
        name="line-route",
    ),
]
