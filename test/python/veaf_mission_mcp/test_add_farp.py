"""`add_farp` — a complete FARP, FIX-SCRATCH-MISSION-FINDINGS ticket 19.

`add_group` in category `static` placed the object alone: no heliport frequency, no callsign, and no
warehouse entry, so no helicopter could rearm or refuel there. GermanyCW-v6 fell back on
`#veafInterpreter["-farp <name>"]`, a runtime spawn. The shape here is measured on the 372 heliports of
the missions under D:\\dev\\_VEAF (2026-09-24): `shape_name` per type (`FARP` → `FARPS`, `Invisible
FARP` → `invisiblefarp`, `SINGLE_HELIPAD` → `FARP`), 127.5 MHz AM in 288 of 369, and a warehouse entry
keyed by the unit id with the coalition in lower case (292 of 300).
"""

from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
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
