from django.contrib import admin

from .models import LatestPosition, TrackingSource


@admin.register(TrackingSource)
class TrackingSourceAdmin(admin.ModelAdmin):
    list_display = (
        "city",
        "kind",
        "is_active",
        "last_success_at",
        "last_error_at",
        "updated_at",
    )
    list_filter = ("kind", "is_active", "city")
    search_fields = ("city__name", "city__slug")
    readonly_fields = (
        "id",
        "last_success_at",
        "last_error_at",
        "last_error_message",
        "created_at",
        "updated_at",
    )


@admin.register(LatestPosition)
class LatestPositionAdmin(admin.ModelAdmin):
    list_display = (
        "vehicle_code",
        "line",
        "city",
        "captured_at",
        "received_at",
        "is_accessible",
    )
    list_filter = ("city", "is_accessible", "data_mode")
    search_fields = ("vehicle_code", "line__boarding_code")
    readonly_fields = [field.name for field in LatestPosition._meta.fields]
    date_hierarchy = "captured_at"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
