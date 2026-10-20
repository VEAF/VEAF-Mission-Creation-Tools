"""A one-shot mission's briefing maps (FEAT-MCP-MISSION-BRIEFING ticket 03)."""

from __future__ import annotations

import io
import itertools
from pathlib import Path

from campaign_manager.mission_picture import read_mission_picture
from mission_briefing.briefing_maps import render_objective_zoom, render_overview_map, threat_circles
from mission_briefing.mission_reader import departures, group_position, objective_area
from mission_briefing.models import Objective, Threat
from mission_tools.miz_tools import read_miz
from objective_mission_fixture import SA6_XY, objective_mission
from PIL import Image
from veaf_libs.map_labels import intersects
from veaf_libs.map_tiles import TOPO

OBJECTIVE = Objective("Khobi", "Détruire le dépôt de Khobi", ("Dépôt et sa défense SA-8",))
SA6 = Threat("SA-6 Gori", "SA-6 Site", "SA-6", engagement_nm=13.0, detection_nm=30.0, source="measured in game")


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def _inputs(tmp_path: Path) -> dict:
    miz = objective_mission(tmp_path / "mission")
    content = read_miz(miz).mission_content or {}
    picture = read_mission_picture(miz, "blue", tmp_path / "mission")
    position = group_position(content, SA6.group)
    assert position is not None
    return {
        "picture": picture,
        "objectives": [(OBJECTIVE, objective_area(content, "Khobi", "red"))],
        "threats": [(SA6, position)],
        "departures": departures(content, "blue", picture.theatre),
    }


class TestTheThreatCircles:
    def test_engagement_plain_detection_dashed_nothing_without_a_range(self) -> None:
        assert threat_circles(SA6) == [(13.0 * 1852, False), (30.0 * 1852, True)]
        assert threat_circles(Threat("AAA", "g")) == []


class TestTheDepartures:
    def test_an_airfield_departure_named_and_a_carrier_or_air_start_left_out(self, tmp_path: Path) -> None:
        miz = objective_mission(tmp_path / "mission")
        found = departures(read_miz(miz).mission_content or {}, "blue", "Caucasus")
        assert [name for name, _, _ in found] == ["Kobuleti"]


class TestTheOverview:
    def test_everything_is_drawn_and_no_label_overlaps(self, tmp_path: Path) -> None:
        report = render_overview_map(
            **_inputs(tmp_path), out=tmp_path / "overview.png", cache_dir=tmp_path, fetch=_white
        )
        assert report.path.is_file() and not report.offline
        assert {"Khobi", "SA-6 Gori", "bullseye", "carrier", "Kobuleti", "Overlord 1-1", "waypoint 1"} <= set(
            report.symbols
        )
        for a, b in itertools.combinations(report.labels, 2):
            assert not intersects(a, b), (a, b)

    def test_the_threat_stands_where_its_group_is(self, tmp_path: Path) -> None:
        inputs = _inputs(tmp_path)
        assert inputs["threats"][0][1] == SA6_XY
        report = render_overview_map(**inputs, out=tmp_path / "overview.png", cache_dir=tmp_path, fetch=_white)
        image = Image.open(report.path).convert("RGB")
        red, _, blue = image.getpixel(tuple(int(v) for v in report.symbols["SA-6 Gori"]))
        assert red > blue + 50

    def test_offline_the_map_is_drawn_and_says_so(self, tmp_path: Path) -> None:
        report = render_overview_map(
            **_inputs(tmp_path), out=tmp_path / "overview.png", cache_dir=tmp_path, fetch=lambda url: None
        )
        assert report.path.is_file() and report.offline

    def test_topo_tiles_carry_their_credit(self, tmp_path: Path) -> None:
        asked: list[str] = []
        render_overview_map(
            **_inputs(tmp_path),
            out=tmp_path / "overview.png",
            cache_dir=tmp_path,
            fetch=lambda url: asked.append(url) or _white(url),
            source=TOPO,
        )
        assert asked and all("opentopomap" in url for url in asked)


class TestTheZoom:
    def test_the_zone_its_targets_and_a_wide_frame(self, tmp_path: Path) -> None:
        inputs = _inputs(tmp_path)
        objective, area = inputs["objectives"][0]
        report = render_objective_zoom(
            inputs["picture"].theatre,
            objective,
            area,
            inputs["threats"],
            out=tmp_path / "zoom.png",
            cache_dir=tmp_path,
            fetch=_white,
        )
        assert {"Khobi", "target SA8", "target Dépôt de munitions"} <= set(report.symbols)
        assert "target Patrol" not in report.symbols
        for a, b in itertools.combinations(report.labels, 2):
            assert not intersects(a, b), (a, b)
        width, _ = Image.open(report.path).size
        assert width >= 600  # framed 3 km at least around the zone: the base map still shows
