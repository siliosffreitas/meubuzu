from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import EmailCode, RefreshSession, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("email",)
    list_display = ("email", "is_active", "email_verified_at", "created_at")
    list_filter = ("is_active", "is_staff", "is_superuser")
    search_fields = ("email",)
    readonly_fields = ("id", "created_at", "updated_at", "last_login", "email_verified_at")

    fieldsets = (
        (None, {"fields": ("id", "email", "password")}),
        (
            "Permissões",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        ("Sessão", {"fields": ("last_login", "email_verified_at")}),
        ("Datas", {"fields": ("created_at", "updated_at")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "password1", "password2", "is_staff", "is_superuser"),
            },
        ),
    )
    filter_horizontal = ("groups", "user_permissions")


@admin.register(EmailCode)
class EmailCodeAdmin(admin.ModelAdmin):
    list_display = ("email", "created_at", "expires_at", "consumed_at", "attempts")
    list_filter = ("consumed_at",)
    search_fields = ("email",)
    readonly_fields = (
        "id",
        "email",
        "expires_at",
        "consumed_at",
        "attempts",
        "ip",
        "user_agent",
        "created_at",
    )
    exclude = ("code_hash",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(RefreshSession)
class RefreshSessionAdmin(admin.ModelAdmin):
    list_display = ("user", "created_at", "expires_at", "revoked_at", "device_id")
    list_filter = ("revoked_at",)
    search_fields = ("user__email", "device_id")
    readonly_fields = (
        "id",
        "user",
        "family_id",
        "device_id",
        "expires_at",
        "revoked_at",
        "replaced_by",
        "last_used_at",
        "created_at",
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
