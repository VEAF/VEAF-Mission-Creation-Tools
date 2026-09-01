"""Bornes et tolerance de la taille de police.

Sans Qt : la taille vient d'un `session.json` que rien n'empeche d'editer a la
main, et une valeur aberrante ne doit pas empecher le lancement.
"""

from __future__ import annotations

import pytest
from veaf_logs.appearance import (
    DEFAULT_FONT_SIZE,
    MAX_FONT_SIZE,
    MIN_FONT_SIZE,
    clamp_font_size,
)


class TestBornes:
    def test_valeur_ordinaire_conservee(self):
        assert clamp_font_size(12) == 12

    def test_trop_petite_remontee(self):
        assert clamp_font_size(1) == MIN_FONT_SIZE

    def test_trop_grande_rabaissee(self):
        assert clamp_font_size(400) == MAX_FONT_SIZE

    def test_negative(self):
        assert clamp_font_size(-30) == MIN_FONT_SIZE


class TestValeursAberrantes:
    @pytest.mark.parametrize("valeur", [None, "grand", "", [], {}, object()])
    def test_repli_sur_le_defaut(self, valeur):
        assert clamp_font_size(valeur) == DEFAULT_FONT_SIZE

    def test_chaine_numerique_acceptee(self):
        """`int("11")` marche : inutile de refuser ce que Python sait lire."""
        assert clamp_font_size("11") == 11

    def test_flottant_tronque(self):
        assert clamp_font_size(10.7) == 10
