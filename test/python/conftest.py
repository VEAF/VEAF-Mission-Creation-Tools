"""Fixtures every test gets."""

from __future__ import annotations

from pathlib import Path

import pytest
from offline import isolate


@pytest.fixture(autouse=True)
def no_network_and_no_user_cache(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """No test downloads a map tile or an elevation grid, nor writes to the user's tile cache.

    `campaign next` and `campaign briefing` draw a strategic map on OpenStreetMap tiles; a test that
    reaches them renders the map offline, in its own temporary cache. A test that wants tiles passes
    its own `fetch`. `grid_for_theatre` fetches a missing theatre from the `terrain-data` release; a
    theatre with no local grid stays without one, and `test_terrain_data.py` puts the real download back,
    against a fake release. A fixture wider than one test gets the same through `offline.offline()`.
    """
    isolate(monkeypatch, tmp_path)
