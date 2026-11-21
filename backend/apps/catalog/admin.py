from django.contrib import admin

from .models import (
    CatalogImportRun,
    CatalogSource,
    City,
    Line,
    LineSourceRef,
    Stop,
)


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


@admin.register(Line)
class LineAdmin(admin.ModelAdmin):
    list_display = (
        "boarding_code",
        "name",
        "city",
        "is_active",
        "origin_type",
        "updated_at",
    )
    list_filter = ("city", "is_active", "origin_type")
    search_fields = ("boarding_code", "name", "code")
    readonly_fields = ("id", "created_at", "updated_at")
    autocomplete_fields = ("city", "source")


@admin.register(CatalogSource)
class CatalogSourceAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "city",
        "slug",
        "kind",
        "data_mode",
        "is_active",
        "last_import_at",
        "updated_at",
    )
    list_filter = ("kind", "data_mode", "is_active", "city")
    search_fields = ("name", "slug", "city__name")
    readonly_fields = (
        "id",
        "last_import_at",
        "last_error_at",
        "last_error_message",
        "created_at",
        "updated_at",
    )


@admin.register(CatalogImportRun)
class CatalogImportRunAdmin(admin.ModelAdmin):
    list_display = (
        "city",
        "status",
        "trigger",
        "started_at",
        "finished_at",
        "lines_created",
        "lines_updated",
        "errors",
    )
    list_filter = ("status", "trigger", "city")
    search_fields = ("city__name", "city__slug")
    readonly_fields = [field.name for field in CatalogImportRun._meta.fields]
    date_hierarchy = "started_at"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(LineSourceRef)
class LineSourceRefAdmin(admin.ModelAdmin):
    list_display = ("line", "source", "external_id", "direction", "updated_at")
    list_filter = ("source", "direction", "line__city")
    search_fields = ("line__boarding_code", "external_id")
    readonly_fields = ("id", "created_at", "updated_at")
    autocomplete_fields = ("line", "source")


@admin.register(Stop)
class StopAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "city", "is_active", "origin_type", "updated_at")
    list_filter = ("city", "is_active", "origin_type")
    search_fields = ("code", "name", "address", "external_id")
    readonly_fields = ("id", "created_at", "updated_at")
    autocomplete_fields = ("city", "source")
