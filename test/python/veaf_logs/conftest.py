"""Fixtures communes aux tests de veaf-logs."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from veaf_logs.buffer import BytesBuffer  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402
from veaf_logs_journal import journal_bytes  # noqa: E402


@pytest.fixture(autouse=True)
def isolated_appdata(tmp_path, monkeypatch):
    """Session et profils dans un dossier temporaire, jamais dans ceux de l'utilisateur.

    Fermer une `MainWindow` sauve la session au chemin par defaut : sans ce
    detournement, chaque `pytest` remplacait la session `veaf-logs` de qui le
    lancait par un journal de test (FIX-LOGS-EXE-STARTUP-AND-VERSION, ticket 03).
    """
    monkeypatch.setenv("APPDATA", str(tmp_path / "appdata"))


@pytest.fixture(scope="session")
def rules() -> Rules:
    return Rules.load()


@pytest.fixture
def store(rules) -> LogStore:
    store = LogStore(rules, BytesBuffer(journal_bytes()))
    store.index_new()
    return store


@pytest.fixture
def journal_file(tmp_path):
    path = tmp_path / "dcs.log"
    path.write_bytes(journal_bytes())
    return path
