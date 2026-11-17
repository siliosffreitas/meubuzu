from django.contrib import admin

from .models import CatalogSource, City, Stop


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


@admin.register(CatalogSource)
class CatalogSourceAdmin(admin.ModelAdmin):
    list_display = ("name", "city", "slug", "data_mode", "is_active", "updated_at")
    list_filter = ("data_mode", "is_active", "city")
    search_fields = ("name", "slug", "city__name")
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Stop)
class StopAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "city", "is_active", "origin_type", "updated_at")
    list_filter = ("city", "is_active", "origin_type")
    search_fields = ("code", "name", "address", "external_id")
    readonly_fields = ("id", "created_at", "updated_at")
    autocomplete_fields = ("city", "source")
