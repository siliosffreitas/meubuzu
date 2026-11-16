from django.conf import settings
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .payloads import (
    entitlements_payload,
    preferences_payload,
    session_payload,
    user_payload,
)
from .serializers import RefreshSerializer, RequestCodeSerializer, VerifyCodeSerializer


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
                "preferences": preferences_payload(),
                "entitlements": entitlements_payload(),
            }
        )
