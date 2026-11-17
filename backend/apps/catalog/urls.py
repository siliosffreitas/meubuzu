from django.urls import path

from .views import CityDetailView, CityListView

app_name = "catalog"

urlpatterns = [
    path("cities", CityListView.as_view(), name="city-list"),
    path("cities/<slug:city_slug>", CityDetailView.as_view(), name="city-detail"),
]
