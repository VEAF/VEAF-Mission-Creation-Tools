"""Fixtures every test gets."""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs import map_tiles, terrain_data


@pytest.fixture(autouse=True)
def no_map_tiles_from_the_network(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """No test downloads a map tile, nor writes to the user's tile cache.

    `campaign next` and `campaign briefing` draw a strategic map on OpenStreetMap tiles; a test that
    reaches them renders the map offline, in its own temporary cache. A test that wants tiles passes
    its own `fetch`.
    """
    monkeypatch.setattr(map_tiles, "http_fetch", lambda url: None)
    monkeypatch.setattr(map_tiles, "default_cache_dir", lambda: tmp_path / "tiles")


@pytest.fixture(autouse=True)
def no_terrain_data_from_the_network(monkeypatch: pytest.MonkeyPatch) -> None:
    """No test downloads an elevation grid: a theatre with no local grid stays without one.

    `grid_for_theatre` fetches a missing theatre from the `terrain-data` release; `test_terrain_data.py`
    puts the real download back, against a fake release.
    """
    monkeypatch.setattr(terrain_data, "download_grid", lambda theatre, target: False)
