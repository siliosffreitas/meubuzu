from rest_framework import serializers


class RequestCodeSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class VerifyCodeSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    code = serializers.RegexField(r"^\d{6}$", min_length=6, max_length=6)


class RefreshSerializer(serializers.Serializer):
    refreshToken = serializers.CharField(max_length=512)
    deviceId = serializers.CharField(max_length=128, required=False, allow_blank=True, default="")
