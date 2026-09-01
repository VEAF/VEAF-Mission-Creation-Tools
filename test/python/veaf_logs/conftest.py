"""Fixtures communes aux tests de veaf-logs."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from veaf_logs.buffer import BytesBuffer  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402
from veaf_logs_journal import journal_bytes  # noqa: E402


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
