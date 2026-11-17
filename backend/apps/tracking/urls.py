from django.urls import path

from .views import LinePositionsView

app_name = "tracking"

urlpatterns = [
    path(
        "cities/<slug:city_slug>/positions",
        LinePositionsView.as_view(),
        name="line-positions",
    ),
    path(
        "cities/<slug:city_slug>/lines/<str:sg_linha>/positions",
        LinePositionsView.as_view(),
        name="line-positions-detail",
    ),
]
