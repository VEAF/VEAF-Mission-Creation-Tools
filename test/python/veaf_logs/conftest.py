"""Fixtures communes aux tests de veaf-logs."""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer
from veaf_logs.rules import Rules
from veaf_logs.store import LogStore
from veaf_logs_journal import journal_bytes


@pytest.fixture(autouse=True)
def isolated_appdata(tmp_path, monkeypatch):
    """Profils dans un dossier temporaire, jamais dans ceux de l'utilisateur.

    Les profils sont ceux du viewer installe (`%APPDATA%/veaf_logs`) : sans ce
    detournement, un test qui en enregistre un ecrirait chez qui lance `pytest`.
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
