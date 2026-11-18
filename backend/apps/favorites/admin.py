from django.contrib import admin

from .models import Favorite


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ("user", "line", "created_at")
    list_filter = ("created_at",)
    search_fields = ("user__email", "line__name", "line__code")
    readonly_fields = ("id", "created_at")
