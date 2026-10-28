"""What the test conftests keep away from every test, for a fixture wider than one test.

The autouse fixtures of `conftest.py` are function-scoped: a module- or class-scoped fixture runs before
them and outside them, so a briefing it builds would download real map tiles into the user's cache
(measured 2026-10-28: 532 OpenStreetMap tiles, 161 s). Such a fixture builds under `offline()`.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest
from veaf_libs import map_tiles, terrain_data


def isolate(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """No map tile and no elevation grid from the network, no tile written to the user's cache.

    Args:
        monkeypatch: Undoes the patches when its scope ends.
        tmp_path: Where the tiles that are drawn anyway are cached.
    """
    monkeypatch.setattr(map_tiles, "http_fetch", lambda url: None)
    monkeypatch.setattr(map_tiles, "default_cache_dir", lambda: tmp_path / "tiles")
    monkeypatch.setattr(terrain_data, "download_grid", lambda theatre, target: False)


@contextmanager
def offline(tmp_path: Path) -> Iterator[None]:
    """`isolate()`, and the VEAF home `veaf_mission_mcp/conftest.py` isolates, for as long as the block runs.

    Args:
        tmp_path: The fixture's own temporary folder.

    Yields:
        Nothing: the block runs isolated.
    """
    with pytest.MonkeyPatch.context() as monkeypatch:
        isolate(monkeypatch, tmp_path)
        monkeypatch.setenv("VEAF_HOME", str(tmp_path / "veaf-home"))
        yield
