"""L'icone de veaf-logs : le fichier, l'executable et la fenetre (CHORE-SMALL-POLISH 02).

L'icone est dessinee pour le projet (une page de journal sous une loupe), pas tiree
d'une illustration existante.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from PIL import Image

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

ROOT = Path(__file__).parents[3]
SPEC = ROOT / "veaf-logs.spec"


def test_l_icone_porte_les_tailles_de_windows():
    from veaf_logs.appearance import APP_ICON_PATH

    with Image.open(APP_ICON_PATH) as icon:
        assert icon.format == "ICO"
        sizes = {width for width, _ in icon.info["sizes"]}
    assert {16, 24, 32, 48, 256} <= sizes


def test_l_executable_la_porte_et_l_embarque():
    """`icon=` habille le fichier dans l'Explorateur ; `datas` la rend lisible par Qt a l'execution."""
    spec = SPEC.read_text(encoding="utf-8")
    assert 'icon=str(SOURCE / "veaf_logs" / "veaf-logs.ico")' in spec
    assert '(str(SOURCE / "veaf_logs" / "veaf-logs.ico"), "veaf_logs")' in spec


def test_qt_sait_la_lire():
    pytest.importorskip("PySide6")
    from PySide6.QtWidgets import QApplication
    from veaf_logs.ui.main_window import app_icon

    QApplication.instance() or QApplication([])
    icon = app_icon()
    assert not icon.isNull()
    assert 16 in {size.width() for size in icon.availableSizes()}
