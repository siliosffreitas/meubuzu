from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class Favorite(models.Model):
    """Linha favorita de um usuário (RF-011).

    Favoritos são globais por conta; a cidade vem da linha associada e é
    devolvida no payload para o app agrupar sem consultas extras.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="favorites",
    )
    line = models.ForeignKey(
        "catalog.Line",
        on_delete=models.CASCADE,
        related_name="favorites",
    )
    created_at = models.DateTimeField("criado em", auto_now_add=True)

    class Meta:
        db_table = "favorites_favorite"
        verbose_name = "favorito"
        verbose_name_plural = "favoritos"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "line"],
                name="favorites_favorite_user_line_uniq",
            )
        ]
        indexes = [models.Index(fields=["user"], name="favorites_fav_user_idx")]

    def __str__(self) -> str:
        return f"{self.user_id}:{self.line_id}"
