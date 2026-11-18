from rest_framework import serializers


class CreateFavoriteSerializer(serializers.Serializer):
    lineId = serializers.CharField(max_length=64)
    citySlug = serializers.SlugField(max_length=60)
