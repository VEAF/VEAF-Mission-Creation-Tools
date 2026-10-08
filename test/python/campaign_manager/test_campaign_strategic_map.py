"""The campaign's strategic map, and the map background it stands on (FEAT-CAMPAIGN-BRIEFING-DECK ticket 01)."""

from __future__ import annotations

import copy
import io
import re
from pathlib import Path

import pytest
from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.models import CampaignDefinition
from campaign_manager.strategic_map import render_strategic_map, zone_position
from PIL import Image
from veaf_libs import map_tiles
from veaf_libs.map_tiles import USER_AGENT, http_fetch, render_base_map, world_pixel


def _png(colour: tuple[int, int, int]) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), colour).save(buffer, format="PNG")
    return buffer.getvalue()


class Tiles:
    """A tile server in memory: counts what is asked of it."""

    def __init__(self, data: bytes | None) -> None:
        self.data, self.calls = data, 0

    def __call__(self, url: str) -> bytes | None:
        self.calls += 1
        return self.data


def _campaign() -> CampaignDefinition:
    campaign, issues = parse_campaign(copy.deepcopy(VALID))
    assert campaign is not None, issues
    return campaign


class TestTheBackground:
    def test_the_user_agent_names_the_tool_and_nothing_else(self) -> None:
        # the OSM policy asks for an identifying User-Agent; a personal address was once sent in one
        assert USER_AGENT == "veaf-tools (+https://github.com/VEAF/VEAF-Mission-Creation-Tools)"
        assert not re.search(r"@|\\|users", USER_AGENT, re.IGNORECASE)

    def test_the_tile_download_sends_that_user_agent(self, monkeypatch: pytest.MonkeyPatch) -> None:
        sent = {}

        class Response:
            ok, content = True, b"tile"

        def get(url: str, headers: dict[str, str], timeout: int) -> Response:
            sent.update(headers)
            return Response()

        monkeypatch.setattr(map_tiles.requests, "get", get)
        # the function itself: the conftest replaces map_tiles.http_fetch for every other test
        assert http_fetch("https://tile.openstreetmap.org/1/0/0.png") == b"tile"
        assert sent == {"User-Agent": USER_AGENT}

    def test_tiles_are_cached_and_not_downloaded_twice(self, tmp_path: Path) -> None:
        tiles = Tiles(_png((0, 200, 0)))
        render_base_map(42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=tiles)
        first = tiles.calls
        render_base_map(42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=tiles)
        assert first > 0 and tiles.calls == first

    def test_without_tiles_the_map_is_plain_and_says_so(self, tmp_path: Path) -> None:
        base = render_base_map(42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=Tiles(None))
        assert base.offline
        assert base.image.getpixel((5, 5)) == map_tiles.PLAIN

    def test_a_point_falls_where_web_mercator_puts_it(self, tmp_path: Path) -> None:
        base = render_base_map(42.6, 41.4, 41.5, 42.3, cache_dir=tmp_path, fetch=Tiles(None))
        x, y = base.pixel(42.6, 41.4)
        assert 0 <= x < 1 and 0 <= y < 1  # the corner, within the pixel the origin is rounded to
        wx, wy = world_pixel(41.5, 42.3, base.zoom)
        assert base.pixel(41.5, 42.3) == (wx - base.origin[0], wy - base.origin[1])


class TestTheStrategicMap:
    def test_an_airfield_zone_stands_at_the_shipped_airbase_position(self) -> None:
        campaign = _campaign()
        lat, lon = zone_position(campaign, campaign.zone("Senaki"))
        # The reference point, on the runways' centre (FEAT-DCS-REFERENCE-DATA); getPoint() gave 42.06.
        assert (round(lat, 2), round(lon, 2)) == (42.24, 42.05)
        assert zone_position(campaign, campaign.zone("Gudauta depot")) == (43.10, 40.58)

    def test_each_zone_is_drawn_in_its_owners_colour(self, tmp_path: Path) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        report = render_strategic_map(
            campaign, state, tmp_path / "map.png", cache_dir=tmp_path, fetch=Tiles(_png((255, 255, 255)))
        )
        assert not report.offline
        image = Image.open(report.path).convert("RGB")
        # the zone centres, where nothing but the circle is drawn
        from campaign_manager.strategic_map import _MARGIN_LAT, _MARGIN_LON

        lats = [zone_position(campaign, zone)[0] for zone in campaign.zones]
        lons = [zone_position(campaign, zone)[1] for zone in campaign.zones]
        base = render_base_map(
            max(lats) + _MARGIN_LAT,
            min(lons) - _MARGIN_LON,
            min(lats) - _MARGIN_LAT,
            max(lons) + _MARGIN_LON,
            cache_dir=tmp_path,
            fetch=Tiles(None),
        )
        for name, owner in (("Kobuleti", "blue"), ("Senaki", "red")):
            red, _, blue = image.getpixel(
                tuple(int(v) for v in base.pixel(*zone_position(campaign, campaign.zone(name))))
            )
            assert (blue > red) == (owner == "blue"), name

    def test_the_map_renders_without_the_network(self, tmp_path: Path) -> None:
        campaign = _campaign()
        report = render_strategic_map(
            campaign, initial_state(campaign), tmp_path / "map.png", cache_dir=tmp_path, fetch=Tiles(None)
        )
        assert report.offline and report.path.is_file()
