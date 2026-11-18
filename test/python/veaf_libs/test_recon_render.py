"""The reconnaissance look, the felt-pen marks and the window-grab helpers (FEAT-DCS-RECON-AND-MISSION-CHECK)."""

from __future__ import annotations

import random
from collections.abc import Iterator
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from geographiclib.geodesic import Geodesic  # type: ignore[import-untyped]
from PIL import Image, ImageDraw
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.dcs_recon import INFO_BAR_PX, LiveUnit, MissionInfo, Shot, camera_for, project, shot_metadata
from veaf_libs.dcs_window_capture import client_box, is_black
from veaf_libs.i18n import language
from veaf_libs.magnetic import declination
from veaf_libs.recon_render import (
    RED,
    felt_ring,
    group_label,
    marks_of,
    merge_marks,
    recce_look,
    render_shot,
    shot_headings,
)


@pytest.fixture(autouse=True)
def _english() -> Iterator[None]:
    """The assertions read the English report."""
    with language("en"):
        yield


WIDTH, HEIGHT = 1280, 720


def _meta(mark: str = "groups", labels: dict[str, str] | None = None) -> dict[str, Any]:
    """A shot of two SA-6 vehicles and a far-off unit outside the frame."""
    units = [
        LiveUnit("unit", 1, "SA6Sasa [r] battery#2", "Kub 1S91 str", 1000, 1000, 800),
        LiveUnit("unit", 1, "SA6Sasa [r] battery#2", "Kub 2P25 ln", 1040, 1030, 800),
        LiveUnit("unit", 1, "SA6Sasa [r] battery#2", "Kub 2P25 ln", 1080, 960, 800),
        LiveUnit("unit", 1, "Far [r] x#1", "Ural", 1000, 9000, 800),
    ]
    camera = camera_for(1040, 1000, 800, heading=0, pitch=30, slant=900)
    return shot_metadata(
        Shot("02-sa6", "Batterie SA-6", ["SA6Sasa"], 0, 30, 900, mark, labels or {}),
        camera,
        units,
        (1040, 1000, 800),
        MissionInfo("Caucasus", "2011-04-16", 41460),
        (WIDTH, HEIGHT),
        (42.0, 41.0),
    )


class TestMarks:
    def test_one_ring_per_group_around_its_vehicles(self) -> None:
        meta = _meta()
        marks = marks_of(meta, (WIDTH, HEIGHT - INFO_BAR_PX))
        assert len(marks) == 1  # the far-off unit projects outside the frame
        x, y, radius, label = marks[0]
        # its category, nothing given: the search radar names the battery, two launchers or not
        assert label == "Medium-range air defence"
        camera = camera_for(1040, 1000, 800, 0, 30, 900)
        for u in meta["units"][:3]:
            px, py = project(camera, u["x"], u["z"], u["alt"], WIDTH, HEIGHT) or (0.0, 0.0)
            assert abs(px - x) <= radius and abs(py - y) <= radius

    def test_one_ring_per_vehicle_with_labels_by_type(self) -> None:
        marks = marks_of(_meta("units", {"Kub 1S91": "RADAR 1S91"}), (WIDTH, HEIGHT - INFO_BAR_PX))
        assert sorted(m[3] for m in marks) == ["Kub 2P25 ln", "Kub 2P25 ln", "RADAR 1S91"]

    @staticmethod
    def _shot(units: list[LiveUnit], mark: str = "groups") -> dict[str, Any]:
        """A shot looking north at (1040, 1000) from 900 m, of *units*."""
        return shot_metadata(
            Shot("05-khan", "Khan", ["Khan"], 0, 30, 900, mark, {}),
            camera_for(1040, 1000, 800, heading=0, pitch=30, slant=900),
            units,
            (1040, 1000, 800),
            MissionInfo("Caucasus", "2011-04-16", 41460),
            (WIDTH, HEIGHT),
            (42.0, 41.0),
        )

    def test_vehicles_that_move_are_ringed_by_category(self) -> None:
        """Their positions are read at the grab: on a battle there is something to ring (David, 2026-11-17)."""
        units = [
            LiveUnit("unit", 1, "Khan [r] Armor#1", "T-72B", 1000, 1000, 800),
            LiveUnit("unit", 1, "Khan [r] Armor#1", "BMP-2", 1040, 1030, 800),
            LiveUnit("unit", 1, "Khan [r] SA13#2", "Strela-10M3", 1080, 960, 800),
        ]
        labels = sorted(m[3] for m in marks_of(self._shot(units), (WIDTH, HEIGHT - INFO_BAR_PX)))
        # a tank and an IFV: a tie, the higher priority wins
        assert labels == ["Heavy armour", "Short-range air defence"]

    def test_a_shot_of_statics_only_is_one_target_area(self) -> None:
        """A range of statics got a ring and a label per static, stacked in a column (Open Training)."""
        units = [
            LiveUnit("static", 1, "Range target 1", "T-72B", 1040, 1000, 800),
            LiveUnit("static", 1, "Range target 2", ".Command Center", 1060, 1010, 800),
            LiveUnit("static", 1, "Range target 3", "Ural-375", 1020, 990, 800),
        ]
        marks = marks_of(self._shot(units), (WIDTH, HEIGHT - INFO_BAR_PX))
        assert [m[3] for m in marks] == ["Target area"]

    def test_each_ship_gets_its_own_ring(self) -> None:
        units = [
            LiveUnit("unit", 1, "Gulf [r] boats#1", "speedboat", 1040, 650, 800),
            LiveUnit("unit", 1, "Gulf [r] boats#1", "speedboat", 1040, 1350, 800),
        ]
        marks = marks_of(self._shot(units), (WIDTH, HEIGHT - INFO_BAR_PX))
        assert [m[3] for m in marks] == ["Armed ships", "Armed ships"]

    def test_close_rings_of_one_label_merge(self) -> None:
        marks = merge_marks([(100, 100, 40, "Infantry"), (300, 120, 40, "Infantry"), (320, 140, 40, "Artillery")])
        assert sorted(m[3] for m in marks) == ["Artillery", "Infantry"]
        x, y, radius, _ = next(m for m in marks if m[3] == "Infantry")
        assert (x, y) == (200, 110) and radius == 140

    def test_a_merge_stops_at_the_largest_ring(self) -> None:
        marks = merge_marks([(100, 100, 40, "Infantry"), (800, 100, 40, "Infantry")])
        assert len(marks) == 2

    def test_a_group_label_by_category(self) -> None:
        def label(*types: str, kind: str = "unit") -> str:
            return group_label([LiveUnit(kind, 1, "g", t, 0, 0, 0) for t in types])

        assert label("S-300PS 64H6E sr", "Ural-375", "Ural-375") == "Long-range air defence"
        assert label("Grad-URAL", "Grad-URAL", "Ural-375") == "Artillery"
        assert label("Infantry AK", "Infantry AK", "SA-18 Igla manpad") == "Infantry"
        assert label("Ural-375", "Hummer", "Ural-375") == "Logistics"
        assert label(".Command Center", kind="static") == "Targets"
        assert label("Unknown thing") == "Unknown thing"

    def test_a_group_label_by_prefix(self) -> None:
        marks = marks_of(_meta("groups", {"SA6Sasa": "SA-6"}), (WIDTH, HEIGHT - INFO_BAR_PX))
        assert [m[3] for m in marks] == ["SA-6"]

    def test_a_felt_ring_is_red_and_open_ended(self) -> None:
        image = Image.new("RGB", (400, 400), (0, 0, 0))
        rx, ry = felt_ring(ImageDraw.Draw(image), 200, 200, 50, random.Random(1))
        assert 50 < rx < 70 and 35 < ry < 50
        assert image.getpixel((200, 200)) == (0, 0, 0)  # the centre stays clear
        assert RED in {image.getpixel((x, 200)) for x in range(400)}


class TestRender:
    def test_the_look_is_monochrome_and_keeps_the_size(self) -> None:
        image = Image.new("RGB", (200, 100), (10, 120, 30))
        image.paste((240, 240, 240), (50, 25, 150, 75))
        out = recce_look(image)
        assert out.size == (200, 100)
        r, g, b = out.getpixel((100, 50))
        assert abs(r - g) < 30 and abs(g - b) < 30  # tinted greys, no green left

    def test_a_shot_is_rendered_with_banner_and_marks(self, tmp_path: Path) -> None:
        raw = tmp_path / "02-sa6.png"
        Image.new("RGB", (WIDTH, HEIGHT - INFO_BAR_PX), (120, 110, 100)).save(raw)
        out = tmp_path / "recon" / "02-sa6.jpg"
        lines: list[str] = []
        size = render_shot(raw, _meta(), out, "Marteau du Golan", 2, 12, progress=lines.append)
        assert size == (WIDTH, HEIGHT - INFO_BAR_PX + 70 + 166)  # the MGRS has its own line
        assert Image.open(out).size == size
        assert lines == ["02-sa6.jpg: 1 mark(s)"]

    def test_the_banner_heading_is_magnetic_and_the_rose_true(self) -> None:
        # FIX-BRIEFING-MAGNETIC-HEADINGS: the camera looks north on the grid, which is not north.
        meta = _meta()
        x, _, z = meta["camera"]["position"]
        start, ahead = xy_to_latlon("Caucasus", x, z), xy_to_latlon("Caucasus", x + 1000, z)
        true = float(Geodesic.WGS84.Inverse(*start, *ahead)["azi1"]) % 360
        magnetic, rose = shot_headings(meta)
        assert rose == pytest.approx(true, abs=0.001)
        assert magnetic == round(true - declination(*start, date(2011, 4, 16))) % 360

    def test_a_shot_without_coordinates_still_renders(self, tmp_path: Path) -> None:
        raw = tmp_path / "s.png"
        Image.new("RGB", (WIDTH, HEIGHT - INFO_BAR_PX), (120, 110, 100)).save(raw)
        meta = _meta()
        meta["target"]["lat"] = meta["target"]["lon"] = None
        render_shot(raw, meta, tmp_path / "s.jpg", "", 1, 1)
        assert (tmp_path / "s.jpg").exists()


class TestCaptureHelpers:
    def test_the_client_box_is_origin_plus_size(self) -> None:
        assert client_box((10, 20), (2560, 1440)) == (10, 20, 2570, 1460)

    def test_a_black_grab_is_recognised(self) -> None:
        assert is_black(Image.new("RGB", (8, 8), (0, 0, 0)))
        assert not is_black(Image.new("RGB", (8, 8), (0, 0, 1)))
        assert is_black(Image.new("L", (8, 8), 0))
        assert not is_black(Image.new("L", (8, 8), 3))
