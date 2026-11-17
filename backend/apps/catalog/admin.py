from django.contrib import admin

from .models import City


@admin.register(City)
class CityAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "state",
        "slug",
        "timezone",
        "import_interval",
        "is_active",
        "updated_at",
    )
    list_filter = ("is_active", "import_interval", "state")
    search_fields = ("name", "slug", "state")
    readonly_fields = ("id", "created_at", "updated_at")
    prepopulated_fields = {"slug": ("name",)}
    fieldsets = (
        (None, {"fields": ("id", "slug", "name", "state", "country", "timezone")}),
        ("Mapa", {"fields": ("latitude", "longitude")}),
        ("Operação", {"fields": ("import_interval", "is_active", "coverage_note")}),
        ("Datas", {"fields": ("created_at", "updated_at")}),
    )
