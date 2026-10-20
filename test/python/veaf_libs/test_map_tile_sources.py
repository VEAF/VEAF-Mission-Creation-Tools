"""The OpenTopoMap tiles a desert map asks for (FEAT-MCP-MISSION-BRIEFING ticket 03)."""

from __future__ import annotations

import io
from pathlib import Path

from PIL import Image
from veaf_libs.map_tiles import CREDIT, OSM, TILE_SOURCES, TOPO, render_base_map


def _png() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (0, 120, 0)).save(buffer, format="PNG")
    return buffer.getvalue()


class TestTheTileSources:
    def test_osm_stays_the_default(self, tmp_path: Path) -> None:
        asked: list[str] = []
        base = render_base_map(
            42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=lambda url: asked.append(url) or _png()
        )
        assert asked and all(url.startswith("https://tile.openstreetmap.org/") for url in asked)
        assert base.credit == CREDIT == OSM.credit

    def test_topo_asks_opentopomap_credits_it_and_caches_apart(self, tmp_path: Path) -> None:
        asked: list[str] = []
        base = render_base_map(
            42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=lambda url: asked.append(url) or _png(), source=TOPO
        )
        assert asked and all(url.startswith("https://tile.opentopomap.org/") for url in asked)
        assert base.credit == "© OpenStreetMap contributors, SRTM | style © OpenTopoMap (CC-BY-SA)"
        assert (tmp_path / "opentopomap").is_dir()
        # an OSM tile already cached is not taken for a topo one
        osm_asked: list[str] = []
        render_base_map(42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=lambda url: osm_asked.append(url) or _png())
        assert osm_asked

    def test_the_sources_by_name(self) -> None:
        assert TILE_SOURCES == {"osm": OSM, "topo": TOPO}
