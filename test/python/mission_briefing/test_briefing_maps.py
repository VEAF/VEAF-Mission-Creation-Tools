"""A one-shot mission's briefing maps (FEAT-MCP-MISSION-BRIEFING ticket 03)."""

from __future__ import annotations

import io
import itertools
from pathlib import Path
from typing import Any

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


def _waypoint(report: Any, number: int) -> tuple[float, float]:
    """Where the route's waypoint ``number`` was drawn: its symbol is named by its label, ``waypoint W1 POTI``."""
    found = [
        xy
        for name, xy in report.symbols.items()
        if name.startswith(f"waypoint W{number}") and name[len(f"waypoint W{number}")] in " /"
    ]
    assert found, sorted(report.symbols)
    return found[0]


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
        assert {"Khobi", "SA-6 Gori", "bullseye", "carrier", "Kobuleti", "Overlord 1-1"} <= set(report.symbols)
        assert _waypoint(report, 1)
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


class TestTheRoute:
    def test_it_leaves_from_the_departure(self, tmp_path: Path) -> None:
        inputs = _inputs(tmp_path)
        report = render_overview_map(**inputs, out=tmp_path / "overview.png", cache_dir=tmp_path, fetch=_white)
        (x0, y0), (x1, y1) = report.symbols["Kobuleti"], _waypoint(report, 1)
        image = Image.open(report.path).convert("RGB")
        red, green, blue = image.getpixel((int(x0 + (x1 - x0) * 0.4), int(y0 + (y1 - y0) * 0.4)))
        assert max(red, green, blue) < 120  # the dark route line, on a white background

    def test_it_crosses_a_threat_circle_visible(self, tmp_path: Path) -> None:
        # POTI → KHOBI runs inside the SA-6's 13 nm: a fill drawn after the route used to erase it there
        report = render_overview_map(
            **_inputs(tmp_path), out=tmp_path / "overview.png", cache_dir=tmp_path, fetch=_white
        )
        (x0, y0), (x1, y1) = _waypoint(report, 1), _waypoint(report, 2)
        image = Image.open(report.path).convert("RGB")
        red, green, blue = image.getpixel((int(x0 + (x1 - x0) * 0.6), int(y0 + (y1 - y0) * 0.6)))
        assert max(red, green, blue) < 120


class TestTheReadableOverview:
    """FEAT-OBJECTIVE-BRIEFING-QUALITY 02: 715 × 628 px, framed on the tankers' tracks, half a slide of legend."""

    def test_it_is_as_wide_as_asked_at_its_aspect(self, tmp_path: Path) -> None:
        report = render_overview_map(
            **_inputs(tmp_path), out=tmp_path / "o.png", cache_dir=tmp_path, fetch=_white, aspect=2.0, width=2000
        )
        width, height = Image.open(report.path).size
        assert width >= 2000
        assert abs(width / height - 2.0) < 0.02
        assert report.metres_per_pixel > 0

    def test_the_frame_holds_the_route_and_the_support(self, tmp_path: Path) -> None:
        # the support was left out (FEAT-OBJECTIVE-BRIEFING-QUALITY 02); the theatre is the overview's since
        # FIX-BRIEFING-PARITY-MARTEAU 02: the tankers and the AWACS are where the package refuels
        from dataclasses import replace

        inputs = _inputs(tmp_path)
        picture = inputs["picture"]
        far = tuple(replace(s, route=tuple((x - 150_000, y) for x, y in s.route)) for s in picture.support)
        inputs["picture"] = replace(picture, support=far)  # 150 km south of where the fixture has them
        report = render_overview_map(
            **inputs, out=tmp_path / "o.png", cache_dir=tmp_path, fetch=_white, aspect=2.0, width=1200
        )
        width, height = Image.open(report.path).size

        def inside(name: str) -> bool:
            x, y = report.symbols[name]
            return 0 <= x < width and 0 <= y < height

        assert all(inside(name) for name in ("Khobi", "SA-6 Gori", "Kobuleti", "bullseye", "Overlord 1-1"))

    def test_the_key_is_drawn_into_the_map_and_no_label_overlaps_it(self, tmp_path: Path) -> None:
        report = render_overview_map(
            **_inputs(tmp_path), out=tmp_path / "o.png", cache_dir=tmp_path, fetch=_white, aspect=2.0, width=1200
        )
        assert "key" in report.symbols and "north" in report.symbols
        for a, b in itertools.combinations(report.labels, 2):
            assert not intersects(a, b), (a, b)

    def test_locate_finds_a_waypoint_where_it_was_drawn(self, tmp_path: Path) -> None:
        inputs = _inputs(tmp_path)
        report = render_overview_map(
            **inputs, out=tmp_path / "o.png", cache_dir=tmp_path, fetch=_white, aspect=2.0, width=1200
        )
        waypoint = inputs["picture"].flight_plans[0].waypoints[0]
        assert report.locate is not None
        x, y = report.locate(waypoint.x, waypoint.y)
        wx, wy = _waypoint(report, 1)
        assert abs(x - wx) < 2 and abs(y - wy) < 2


class TestTheRotation:
    """A frame turned to hold a diagonal route tighter; north up when a turn gains little."""

    def test_a_south_west_to_north_east_line_is_turned(self) -> None:
        from campaign_manager.map_canvas import best_rotation

        diagonal = [(33.0, 35.6), (33.4, 36.1)]
        assert 25 <= abs(best_rotation(diagonal, 5_000, 2.0)) <= 65

    def test_an_east_west_line_stays_north_up(self) -> None:
        from campaign_manager.map_canvas import best_rotation

        assert best_rotation([(33.0, 35.6), (33.02, 36.3)], 5_000, 2.0) == 0.0

    def test_a_turned_map_keeps_its_symbols_where_locate_says(self, tmp_path: Path) -> None:
        from campaign_manager.map_canvas import MapCanvas

        canvas = MapCanvas(
            "Caucasus", [(42.0, 41.6), (42.3, 42.1)], 3_000, tmp_path, _white, aspect=2.0, width=800, rotation=40
        )
        x, y = canvas.at(42.0, 41.6)
        canvas.mark("a", (x, y), 4)
        canvas.turn()
        report = canvas.save(tmp_path / "turned.png")
        assert Image.open(report.path).size[0] >= 800
        ax, ay = report.symbols["a"]
        assert 0 <= ax < Image.open(report.path).size[0] and 0 <= ay < Image.open(report.path).size[1]


class TestTheInset:
    def test_a_zoom_carries_the_overview_with_its_place(self, tmp_path: Path) -> None:
        """FEAT-OBJECTIVE-BRIEFING-QUALITY 03: where the zone stands in the whole picture."""
        from mission_briefing.briefing_maps import Inset

        inputs = _inputs(tmp_path)
        overview = render_overview_map(
            **inputs, out=tmp_path / "o.png", cache_dir=tmp_path, fetch=_white, aspect=2.0, width=1200
        )
        objective, area = inputs["objectives"][0]
        assert overview.locate is not None
        inset = Inset(overview.path, overview.locate(area.x, area.y), 20)
        report = render_objective_zoom(
            inputs["picture"].theatre,
            objective,
            area,
            inputs["threats"],
            out=tmp_path / "zoom.png",
            cache_dir=tmp_path,
            fetch=_white,
            width=1000,
            inset=inset,
        )
        assert "inset" in report.symbols
        for a, b in itertools.combinations(report.labels, 2):
            assert not intersects(a, b), (a, b)


class TestTheReviewFindings:
    """pr-code-review of #1206: a steep turn cut black bands; the north arrow could land on the key."""

    def test_a_north_south_route_turned_near_ninety_degrees_has_no_black_band(self, tmp_path: Path) -> None:
        from campaign_manager.map_canvas import MapCanvas, best_rotation

        points = [(41.5, 42.0), (43.0, 42.05)]
        rotation = best_rotation(points, 20_000, 2.0)
        assert abs(rotation) >= 60
        canvas = MapCanvas("Caucasus", points, 20_000, tmp_path, _white, aspect=2.0, width=1200, rotation=rotation)
        canvas.turn()
        image = Image.open(canvas.save(tmp_path / "steep.png").path).convert("RGB")
        width, height = image.size
        row = [image.getpixel((x, height // 2)) for x in range(width)]
        assert all(max(pixel) > 100 for pixel in row), "black pixels: the frame was cut outside the background"

    def test_two_corners_asked_are_two_different_corners(self, tmp_path: Path) -> None:
        from campaign_manager.map_canvas import MapCanvas

        canvas = MapCanvas("Caucasus", [(42.0, 41.6), (42.3, 42.1)], 3_000, tmp_path, _white, aspect=2.0, width=800)
        canvas.turn()
        first = canvas.free_corner((100, 100))
        second = canvas.free_corner((100, 100))
        assert first[:2] != second[:2]

    def test_the_key_leaves_out_what_the_frame_leaves_out(self, tmp_path: Path) -> None:
        from dataclasses import replace

        inputs = _inputs(tmp_path)
        picture = inputs["picture"]
        far = tuple(replace(s, route=tuple((x - 150_000, y) for x, y in s.route)) for s in picture.support)
        inputs["picture"] = replace(picture, support=far)
        # the combat area frames the fight alone: the support it leaves out is out of its key too
        report = render_overview_map(
            **inputs,
            out=tmp_path / "o.png",
            cache_dir=tmp_path,
            fetch=_white,
            aspect=2.0,
            width=1200,
            combat_area=True,
        )
        assert "key objective" in report.symbols
        assert "key awacs" not in report.symbols
