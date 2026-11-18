"""Roteamento raiz da API."""

from django.contrib import admin
from django.db import connection
from django.http import JsonResponse
from django.urls import include, path

from apps.accounts.views import MeView, PreferencesView


def healthz(_request):
    return JsonResponse({"status": "ok"})


def readyz(_request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("admin/", admin.site.urls),
    path("v1/", include("apps.catalog.urls")),
    path("v1/", include("apps.tracking.urls")),
    path("v1/", include("apps.favorites.urls")),
    path("v1/auth/", include("apps.accounts.urls")),
    path("v1/me/preferences", PreferencesView.as_view()),
    path("v1/me/preferences/", PreferencesView.as_view()),
    path("v1/me", MeView.as_view()),
    path("v1/me/", MeView.as_view()),
    path("healthz", healthz),
    path("readyz", readyz),
]
