from __future__ import annotations

import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField("e-mail", unique=True)
    email_verified_at = models.DateTimeField("e-mail verificado em", null=True, blank=True)
    is_active = models.BooleanField("ativo", default=True)
    is_staff = models.BooleanField("equipe", default=False)
    created_at = models.DateTimeField("criado em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizado em", auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        db_table = "accounts_user"
        verbose_name = "usuário"
        verbose_name_plural = "usuários"

    def __str__(self) -> str:
        return self.email

    def save(self, *args, **kwargs):
        if self.email:
            self.email = self.email.strip().lower()
        super().save(*args, **kwargs)

    @property
    def is_email_verified(self) -> bool:
        return self.email_verified_at is not None

    def mark_email_verified(self) -> None:
        if self.email_verified_at is None:
            self.email_verified_at = timezone.now()
            self.save(update_fields=["email_verified_at", "updated_at"])


class EmailCode(models.Model):
    """Código de acesso de uso único. Apenas o hash é armazenado."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField("e-mail", db_index=True)
    code_hash = models.CharField("hash do código", max_length=255)
    expires_at = models.DateTimeField("expira em")
    consumed_at = models.DateTimeField("consumido em", null=True, blank=True)
    attempts = models.PositiveSmallIntegerField("tentativas", default=0)
    ip = models.GenericIPAddressField("IP", null=True, blank=True)
    user_agent = models.TextField("user agent", blank=True, default="")
    created_at = models.DateTimeField("criado em", auto_now_add=True)

    class Meta:
        db_table = "accounts_email_code"
        verbose_name = "código de acesso"
        verbose_name_plural = "códigos de acesso"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["email", "-created_at"], name="emailcode_email_created_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.email} ({self.created_at:%Y-%m-%d %H:%M})"

    @property
    def is_consumed(self) -> bool:
        return self.consumed_at is not None

    @property
    def is_expired(self) -> bool:
        return self.expires_at <= timezone.now()


class RefreshSession(models.Model):
    """Sessão de refresh token rotativo, agrupada por família."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="refresh_sessions",
        verbose_name="usuário",
    )
    token_hash = models.CharField("hash do token", max_length=64, unique=True)
    family_id = models.UUIDField("família", db_index=True)
    device_id = models.CharField("dispositivo", max_length=128, blank=True, default="")
    expires_at = models.DateTimeField("expira em")
    revoked_at = models.DateTimeField("revogado em", null=True, blank=True)
    replaced_by = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="replacement",
        verbose_name="substituído por",
    )
    last_used_at = models.DateTimeField("último uso", null=True, blank=True)
    created_at = models.DateTimeField("criado em", auto_now_add=True)

    class Meta:
        db_table = "accounts_refresh_session"
        verbose_name = "sessão de refresh"
        verbose_name_plural = "sessões de refresh"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="refresh_user_created_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.user_id} ({self.id})"

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None and self.expires_at > timezone.now()


class UserPreference(models.Model):
    """Cidade escolhida pelo usuário, sincronizada entre dispositivos."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name="preference",
        verbose_name="usuário",
    )
    selected_city = models.ForeignKey(
        "catalog.City",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="user_preferences",
        verbose_name="cidade selecionada",
    )
    version = models.PositiveIntegerField("versão", default=0)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        db_table = "accounts_user_preference"
        verbose_name = "preferência do usuário"
        verbose_name_plural = "preferências dos usuários"
        indexes = [
            models.Index(fields=["selected_city"], name="userpref_city_idx"),
        ]

    def __str__(self) -> str:
        city = self.selected_city.slug if self.selected_city_id else "sem cidade"
        return f"{self.user_id} ({city})"
