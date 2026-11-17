from django.conf import settings
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.services import get_active_city

from . import services
from .models import UserPreference
from .payloads import (
    entitlements_payload,
    preferences_payload,
    session_payload,
    user_payload,
)
from .serializers import (
    RefreshSerializer,
    RequestCodeSerializer,
    UpdatePreferencesSerializer,
    VerifyCodeSerializer,
)


def client_ip(request) -> str | None:
    """IP do cliente.

    `X-Forwarded-For` só é considerado quando o backend roda atrás de um proxy
    confiável (`TRUST_X_FORWARDED_FOR`); caso contrário, é forjável e burlaria
    o rate limit.
    """

    if settings.TRUST_X_FORWARDED_FOR:
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


class RequestCodeView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RequestCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        services.request_access_code(
            email=serializer.validated_data["email"],
            ip=client_ip(request),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
        )

        return Response(
            {"message": services.GENERIC_REQUEST_MESSAGE},
            status=status.HTTP_202_ACCEPTED,
        )


class VerifyCodeView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = services.verify_access_code(
            email=serializer.validated_data["email"],
            code=serializer.validated_data["code"],
        )
        access_token, refresh_token = services.start_session(
            user, device_id=request.META.get("HTTP_X_DEVICE_ID", "")
        )

        return Response(
            session_payload(
                user, access_token=access_token, refresh_token=refresh_token
            )
        )


class RefreshView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        device_id = (
            serializer.validated_data.get("deviceId")
            or request.META.get("HTTP_X_DEVICE_ID", "")
        )
        user, access_token, refresh_token = services.refresh_access_token(
            raw_refresh=serializer.validated_data["refreshToken"],
            device_id=device_id,
        )

        return Response(
            {
                "accessToken": access_token,
                "refreshToken": refresh_token,
                "user": user_payload(user),
                "preferences": preferences_payload(user),
            }
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        services.logout(session_id=request.auth.get("sid"), user=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            {
                **user_payload(request.user),
                "preferences": preferences_payload(request.user),
                "entitlements": entitlements_payload(),
            }
        )


class PreferencesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(preferences_payload(request.user))

    def put(self, request):
        serializer = UpdatePreferencesSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        city = get_active_city(serializer.validated_data["selectedCitySlug"])

        with transaction.atomic():
            preference, _ = UserPreference.objects.get_or_create(user=request.user)
            preference = UserPreference.objects.select_for_update().get(pk=preference.pk)
            if preference.selected_city_id != city.id:
                preference.selected_city = city
                preference.version += 1
                preference.save(
                    update_fields=["selected_city", "version", "updated_at"]
                )

        return Response(preferences_payload(request.user, preference=preference))
