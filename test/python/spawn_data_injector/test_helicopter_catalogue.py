"""Tests for the helicopters of the spawn catalogue (FEAT-HELICOPTER-SPAWN ticket 03).

A helicopter spawned from a marker needs two things the runtime cannot find by itself: a fuel load
(nothing in the running mission knows a type's capacity, and an aircraft created with none falls out
of the sky) and, for an armed alias, its pylons. The build renders both, and these tests read the
rendered Lua back with ``luadata`` rather than trusting the renderer's own view of it.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import luadata
import yaml
from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data, render_spawn_data_lua
from veaf_libs.dcs_units_data import get_unit_fuel_capacity, get_unit_types_in_category

_REPO = Path(__file__).resolve().parents[3]
_DYNAMIC_SLOT_TEMPLATES = _REPO / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"

#: The shipped helicopter aliases, and whether each is armed (David, 2026-10-02: the alias decides).
_SHIPPED = {
    "mi8": ("Mi-8MT", False),
    "mi26": ("Mi-26", False),
    "uh1": ("UH-1H", False),
    "ch47": ("CH-47Fbl1", False),
    "mi24": ("Mi-24P", True),
    "ka50": ("Ka-50_3", True),
    "ah64": ("AH-64D_BLK_II", True),
    "gazelle": ("SA342M", True),
}


def _table(lua: str, name: str) -> Any:
    """Parse the ``{...}`` literal assigned to ``veafUnits.<name>``."""
    marker = f"veafUnits.{name} = "
    start = lua.index(marker) + len(marker)
    depth = 0
    for i in range(start, len(lua)):
        if lua[i] == "{":
            depth += 1
        elif lua[i] == "}":
            depth -= 1
            if depth == 0:
                return luadata.unserialize(lua[start : i + 1])
    raise AssertionError(f"unbalanced braces for {name}")


def _stations(pylons: Any) -> dict[int, str]:
    """Pylons as ``{station: CLSID}``, whether luadata read them as a list or a dict."""
    items = enumerate(pylons, start=1) if isinstance(pylons, list) else pylons.items()
    return {int(station): pylon["CLSID"] for station, pylon in items}


def _template_pylons(unit_type: str) -> dict[int, str]:
    """The pylons of the first shipped dynamic-slot template of this type."""
    found: list[dict[int, str]] = []

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            if node.get("type") == unit_type and isinstance(node.get("payload"), dict):
                found.append(_stations(node["payload"].get("pylons") or {}))
            for value in node.values():
                walk(value)

    walk(yaml.safe_load(_DYNAMIC_SLOT_TEMPLATES.read_text(encoding="utf-8"))["helicopters"])
    assert found, f"no dynamic-slot template of {unit_type}"
    return found[0]


def _shipped_entry(alias: str) -> dict[str, Any]:
    for entry in load_framework_spawn_data()["units"]:
        if alias in entry["aliases"]:
            return entry
    raise AssertionError(f"no shipped unit alias {alias}")


def test_helicopter_types_come_from_the_units_database() -> None:
    types = get_unit_types_in_category("Helicopter")
    assert "Mi-8MT" in types
    assert "AH-64D_BLK_II" in types
    assert "F-16C_50" not in types


def test_an_alias_with_pylons_renders_them() -> None:
    data = {
        "units": [{"aliases": ["armed"], "unitType": "Mi-24P", "pylons": {1: {"CLSID": "A"}, 4: {"CLSID": "B"}}}],
        "groups": [],
    }
    entry = _table(render_spawn_data_lua(data), "UnitsDatabase")[0]
    assert _stations(entry["pylons"]) == {1: "A", 4: "B"}


def test_an_alias_without_pylons_renders_none() -> None:
    data = {"units": [{"aliases": ["plain"], "unitType": "Mi-8MT"}], "groups": []}
    assert "pylons" not in _table(render_spawn_data_lua(data), "UnitsDatabase")[0]


def test_every_helicopter_type_gets_its_fuel_and_countermeasures() -> None:
    payloads = _table(render_spawn_data_lua({"units": [], "groups": []}), "AircraftPayloads")
    assert payloads["Mi-8MT"] == {"fuel": 1929, "chaff": 0, "flare": 128}
    for unit_type, payload in payloads.items():
        assert payload["fuel"] > 0, unit_type


def test_a_type_with_no_known_fuel_is_left_out_rather_than_given_none() -> None:
    payloads = _table(render_spawn_data_lua({"units": [], "groups": []}), "AircraftPayloads")
    for unit_type in get_unit_types_in_category("Helicopter"):
        assert (unit_type in payloads) == bool(get_unit_fuel_capacity(unit_type)), unit_type


def test_the_shipped_helicopter_aliases_name_their_type() -> None:
    for alias, (unit_type, _) in _SHIPPED.items():
        assert _shipped_entry(alias)["unitType"] == unit_type, alias


def test_an_armed_alias_carries_its_template_pylons_and_an_unarmed_one_none() -> None:
    for alias, (unit_type, armed) in _SHIPPED.items():
        entry = _shipped_entry(alias)
        if armed:
            assert _stations(entry["pylons"]) == _template_pylons(unit_type), alias
        else:
            assert not entry.get("pylons"), alias


def test_every_shipped_helicopter_alias_flies_with_fuel() -> None:
    payloads = _table(render_spawn_data_lua(load_framework_spawn_data()), "AircraftPayloads")
    for alias, (unit_type, _) in _SHIPPED.items():
        assert payloads[unit_type]["fuel"] > 0, alias


def test_the_helicopter_aliases_collide_with_no_other_alias() -> None:
    seen: dict[str, str] = {}
    for entry in load_framework_spawn_data()["units"]:
        for alias in entry["aliases"]:
            assert alias.lower() not in seen, f"{alias} is also {seen.get(alias.lower())}"
            seen[alias.lower()] = entry["unitType"]
