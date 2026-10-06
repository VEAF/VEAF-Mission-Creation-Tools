"""Fixtures every test gets."""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs import map_tiles


@pytest.fixture(autouse=True)
def no_map_tiles_from_the_network(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """No test downloads a map tile, nor writes to the user's tile cache.

    `campaign next` and `campaign briefing` draw a strategic map on OpenStreetMap tiles; a test that
    reaches them renders the map offline, in its own temporary cache. A test that wants tiles passes
    its own `fetch`.
    """
    monkeypatch.setattr(map_tiles, "http_fetch", lambda url: None)
    monkeypatch.setattr(map_tiles, "default_cache_dir", lambda: tmp_path / "tiles")
