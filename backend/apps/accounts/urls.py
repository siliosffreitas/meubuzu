from django.urls import path

from .views import LogoutView, RefreshView, RequestCodeView, VerifyCodeView

app_name = "accounts"

urlpatterns = [
    path("request-code", RequestCodeView.as_view(), name="request-code"),
    path("verify-code", VerifyCodeView.as_view(), name="verify-code"),
    path("refresh", RefreshView.as_view(), name="refresh"),
    path("logout", LogoutView.as_view(), name="logout"),
]
