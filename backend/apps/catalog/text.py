"""Normalização de texto para o catálogo de paradas."""

from __future__ import annotations

import unicodedata


def normalize_search_text(value: str) -> str:
    """Remove acentos e caixa para comparar com o texto digitado no app."""

    decomposed = unicodedata.normalize("NFKD", value)
    without_accents = "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    )
    return " ".join(without_accents.lower().split())
