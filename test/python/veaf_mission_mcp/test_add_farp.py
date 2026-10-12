"""`add_farp` — a complete FARP, FIX-SCRATCH-MISSION-FINDINGS ticket 19.

`add_group` in category `static` placed the object alone: no heliport frequency, no callsign, and no
warehouse entry, so no helicopter could rearm or refuel there. GermanyCW-v6 fell back on
`#veafInterpreter["-farp <name>"]`, a runtime spawn. The shape here is measured on the 372 heliports of
the missions under D:\\dev\\_VEAF (2026-09-24): `shape_name` per type (`FARP` → `FARPS`, `Invisible
FARP` → `invisiblefarp`, `SINGLE_HELIPAD` → `FARP`), 127.5 MHz AM in 288 of 369, and a warehouse entry
keyed by the unit id with the coalition in lower case (292 of 300).
"""

import math
from array import array
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs import clear_ground_placement as placement
from veaf_libs.clear_ground_catalogue import STATE_BLOCKED, STATE_CLEAR, Catalogue, GridSpec, Layer
from veaf_libs.terrain_elevation import ElevationGrid, save_grid
from veaf_mission_mcp.add_farp import add_farp

_MISSION = """\
mission =
{
  ["coalition"] = {["blue"] = {["country"] = {}}, ["red"] = {["country"] = {}}},
  ["coalitions"] = {["blue"] = {}, ["red"] = {}, ["neutrals"] = {}},
}
"""

_WAREHOUSES = """\
warehouses =
{
  ["airports"] = {},
  ["warehouses"] = {},
}
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (exploded / "warehouses").write_text(_WAREHOUSES, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


def _values(container: Any) -> list[Any]:
    return list(container.values()) if isinstance(container, dict) else list(container or [])


def _farp(folder: Path) -> tuple[dict[str, Any], dict[str, Any], dict[Any, Any]]:
    mission = read_mission_folder(folder)
    content = mission.mission_content or {}
    for country in _values(content["coalition"]["blue"]["country"]):
        for group in _values((country.get("static") or {}).get("group")):
            unit = _values(group["units"])[0]
            return group, unit, (mission.warehouses_content or {}).get("warehouses") or {}
    raise AssertionError("no static group written")


def _add(folder: Path, **extra: Any) -> dict[str, Any]:
    return add_farp(
        folder,
        name="FARP Fulda",
        position={"x": 1000.0, "y": 2000.0},
        coalition="blue",
        country_id=2,
        country_name="USA",
        **extra,
    )


class TestTheHeliport:
    def test_the_unit_is_a_heliport_in_the_editor_shape(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        _add(folder)
        _, unit, _ = _farp(folder)
        assert (unit["type"], unit["category"], unit["shape_name"]) == ("FARP", "Heliports", "FARPS")
        assert unit["heliport_frequency"] == "127.5"
        assert (unit["heliport_modulation"], unit["heliport_callsign_id"]) == (0, 1)

    @pytest.mark.parametrize(("farp_type", "shape"), [("Invisible FARP", "invisiblefarp"), ("SINGLE_HELIPAD", "FARP")])
    def test_each_type_carries_its_own_shape(self, tmp_path: Path, farp_type: str, shape: str) -> None:
        folder = _folder(tmp_path)
        _add(folder, farp_type=farp_type)
        assert _farp(folder)[1]["shape_name"] == shape

    def test_the_frequency_and_callsign_are_set(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        _add(folder, frequency_mhz=31.5, modulation="FM", callsign_id=3)
        _, unit, _ = _farp(folder)
        assert (unit["heliport_frequency"], unit["heliport_modulation"], unit["heliport_callsign_id"]) == (
            "31.5",
            1,
            3,
        )

    def test_an_unknown_type_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="farp_type"):
            _add(_folder(tmp_path), farp_type="Oil rig")


class TestTheWarehouse:
    def test_the_farp_gets_a_warehouse_keyed_by_its_unit_id(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = _add(folder)
        _, unit, warehouses = _farp(folder)
        # A 1-based table with contiguous keys comes back as a list (unit id 1 in an empty mission).
        entry = warehouses[unit["unitId"]] if isinstance(warehouses, dict) else warehouses[unit["unitId"] - 1]
        assert entry["coalition"] == "blue"
        assert (entry["unlimitedFuel"], entry["unlimitedMunitions"]) == (True, True)
        assert result["unit_id"] == unit["unitId"]

    def test_a_mission_without_a_warehouses_file_is_refused(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        (folder / "src" / "mission" / "warehouses").unlink()
        with pytest.raises(ValueError, match="warehouses"):
            _add(folder)


def _statics(folder: Path) -> list[dict[str, Any]]:
    content = read_mission_folder(folder).mission_content or {}
    return [
        _values(group["units"])[0]
        for country in _values(content["coalition"]["blue"]["country"])
        for group in _values((country.get("static") or {}).get("group"))
    ]


class TestTheAmmoDump:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 05: each Syria FARP needed a separate call for its dump."""

    def test_the_dump_is_placed_beside_the_pad_in_the_editor_shape(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = _add(folder)
        dump = next(u for u in _statics(folder) if u["type"] == "FARP Ammo Dump Coating")
        assert (dump["name"], dump["category"], dump["shape_name"]) == (
            "FARP Fulda - Ammo",
            "Fortifications",
            "SetkaKP",
        )
        assert ((dump["x"] - 1000.0) ** 2 + (dump["y"] - 2000.0) ** 2) ** 0.5 == pytest.approx(120.0)
        assert result["ammo_dump"] == "FARP Fulda - Ammo"

    def test_it_can_be_left_out(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = _add(folder, ammo_dump=False)
        assert [u["type"] for u in _statics(folder)] == ["FARP"]
        assert "ammo_dump" not in result


# FIX-FARP-PLACEMENT 01: « FARP Merizo » was placed in the Marianas jungle and on a slope, and the only
# warning was about the sea. The pad is now checked for trees (clear-ground catalogue) and slope
# (elevation grid), and says what it could not check.

_MISSION_CAUCASUS = _MISSION.replace("mission =\n{\n", 'mission =\n{\n  ["theatre"] = "Caucasus",\n', 1)


def _wood_then_field() -> Catalogue:
    """Rows 0-19 wood, the rest open, 25 m apart: a wood south of x=0, a field north of it."""
    grid = GridSpec(-500, -1000, 25, 81, 81)
    states = bytearray([STATE_CLEAR]) * grid.size
    for index in range(20 * 81):
        states[index] = STATE_BLOCKED
    layer = Layer("zone:test", grid, states)
    layer.derive_radii()
    return Catalogue("Caucasus", [layer])


@pytest.fixture
def caucasus(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """A Caucasus folder, a wood-then-field catalogue, and a grid: flat south of x=2000, a 10 % slope north."""
    folder = _folder(tmp_path)
    (folder / "src" / "mission" / "mission").write_text(_MISSION_CAUCASUS, encoding="utf-8")
    catalogue = _wood_then_field()
    monkeypatch.setattr(
        placement, "catalogue_for_theatre", lambda theatre: catalogue if theatre == "Caucasus" else None
    )
    grid = GridSpec(-5000.0, -5000.0, 100.0, 101, 101)
    heights = array("h")
    for row in range(grid.rows):
        for col in range(grid.cols):
            x, _y = grid.cell_position(row, col)
            heights.append(100 + max(0, int((x - 2000) / 10)))
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    save_grid(ElevationGrid("Caucasus", grid, heights), tmp_path / "home" / "terrain" / "Caucasus.terrain")
    return folder


def _add_at(folder: Path, x: float, y: float, **extra: Any) -> dict[str, Any]:
    return add_farp(
        folder,
        name="FARP Merizo",
        position={"x": x, "y": y},
        coalition="blue",
        country_id=2,
        country_name="USA",
        **extra,
    )


def _pad_and_dump(folder: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    statics = _statics(folder)
    return (
        next(u for u in statics if u["type"] == "FARP"),
        next(u for u in statics if u["type"] == "FARP Ammo Dump Coating"),
    )


class TestThePadIsChecked:
    def test_a_pad_in_a_catalogued_wood_moves_onto_clear_ground_with_its_dump(self, caucasus: Path) -> None:
        result = _add_at(caucasus, -300.0, 0.0)
        pad, dump = _pad_and_dump(caucasus)
        assert pad["x"] > -300.0
        assert (dump["x"], dump["y"] - pad["y"]) == (pad["x"], pytest.approx(120.0))
        assert result["position"] == {"x": pad["x"], "y": pad["y"]}
        moved = [w for w in result["warnings"] if w.startswith("'FARP Merizo' moved")]
        assert len(moved) == 1 and "clear ground" in moved[0]
        assert math.hypot(pad["x"] + 300.0, pad["y"]) <= placement.SEARCH_RADIUS_METERS

    def test_keep_position_keeps_it_and_says_it_stands_in_the_trees(self, caucasus: Path) -> None:
        result = _add_at(caucasus, -300.0, 0.0, keep_position=True)
        pad, _ = _pad_and_dump(caucasus)
        assert (pad["x"], pad["y"]) == (-300.0, 0.0)
        assert any(
            "'FARP Merizo' stands in trees or buildings" in w and "keep_position" in w for w in result["warnings"]
        )

    def test_a_pad_already_on_clear_flat_ground_says_nothing(self, caucasus: Path) -> None:
        result = _add_at(caucasus, 800.0, 0.0)
        assert _pad_and_dump(caucasus)[0]["x"] == 800.0
        assert "warnings" not in result

    def test_a_pad_on_a_slope_warns_with_the_drop(self, caucasus: Path) -> None:
        # North of x=2000 the ground climbs 10 m per 100 m: 8 m over the 80 m of the ring.
        result = _add_at(caucasus, 3000.0, 0.0, keep_position=True)
        slope = [w for w in result["warnings"] if "is on a slope" in w]
        assert len(slope) == 1 and "8.0 m" in slope[0] and "farp-spot" in slope[0]

    def test_a_pad_with_nothing_to_check_it_says_what_was_not_checked(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        (folder / "src" / "mission" / "mission").write_text(
            _MISSION.replace("mission =\n{\n", 'mission =\n{\n  ["theatre"] = "MarianaIslands",\n', 1), encoding="utf-8"
        )
        result = _add_at(folder, -22300.0, -12450.0)
        unchecked = [w for w in result["warnings"] if "not checked for 'FARP Merizo'" in w]
        assert len(unchecked) == 1
        assert "trees" in unchecked[0] and "slope" in unchecked[0]
        assert "veaf-tools.exe dcs farp-spot MarianaIslands -22300 -12450" in unchecked[0]
