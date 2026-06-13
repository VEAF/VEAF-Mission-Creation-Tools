"""Tests for the spawn-data Lua emitter (SPAWN-EXTERNALIZE-002).

The emitter renders ``veaf-units.yaml`` to a Lua module assigning
``veafUnits.UnitsDatabase`` / ``veafUnits.GroupsDatabase``. These tests prove the
render is faithful by parsing the output back with the pure-Python ``luadata``
parser (an independent code path) and comparing to the YAML source.
"""

from __future__ import annotations

from typing import Any

import luadata

from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data, render_spawn_data_lua


def _extract_table(lua: str, name: str) -> dict:
    """Pull the ``{...}`` literal assigned to ``veafUnits.<name>`` and parse it."""
    marker = f"veafUnits.{name} = "
    start = lua.index(marker) + len(marker)
    # find the matching closing brace for the opening one at `start`
    depth = 0
    for i in range(start, len(lua)):
        ch = lua[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return luadata.unserialize(lua[start : i + 1])
    raise AssertionError(f"unbalanced braces for {name}")


def _expected_unit_db(units: list[dict]) -> list:
    """YAML unit rows -> luadata shape (pure arrays become Python lists)."""
    return [{"aliases": list(u["aliases"]), "unitType": u["unitType"]} for u in units]


def _expected_unit_entry(unit: dict) -> dict:
    """YAML group-unit -> luadata shape: positional [1]=type + named keys."""
    entry: dict[Any, Any] = {1: unit["type"]}
    for key in ("cell", "hdg", "number", "size", "random", "fitToUnit"):
        if key not in unit:
            continue
        val = unit[key]
        if key == "number" and isinstance(val, dict):
            entry[key] = {"min": int(val["min"]), "max": int(val["max"])}
        else:
            entry[key] = val
    return entry


def _expected_groups_db(groups: list[dict]) -> list:
    out: list = []
    for g in groups:
        group: dict[str, Any] = {
            "disposition": {"h": g["disposition"]["h"], "w": g["disposition"]["w"]},
            "units": [_expected_unit_entry(u) for u in g["units"]],
        }
        if "description" in g:
            group["description"] = g["description"]
        if "groupName" in g:
            group["groupName"] = g["groupName"]
        entry: dict[str, Any] = {"aliases": list(g["aliases"]), "group": group}
        if g.get("hidden"):
            entry["hidden"] = True
        out.append(entry)
    return out


def test_load_framework_spawn_data_shape() -> None:
    data = load_framework_spawn_data()
    assert len(data["units"]) == 13
    assert len(data["groups"]) == 78
    # hidden groups preserved (the generateAirDefenseGroup-* entries)
    hidden = [g for g in data["groups"] if g.get("hidden")]
    assert len(hidden) == 12


def test_units_database_roundtrip() -> None:
    data = load_framework_spawn_data()
    lua = render_spawn_data_lua(data)
    parsed = _extract_table(lua, "UnitsDatabase")
    assert parsed == _expected_unit_db(data["units"])


def test_groups_database_roundtrip() -> None:
    data = load_framework_spawn_data()
    lua = render_spawn_data_lua(data)
    parsed = _extract_table(lua, "GroupsDatabase")
    assert parsed == _expected_groups_db(data["groups"])


def test_render_field_variants() -> None:
    """Each unit field shape renders and parses back identically."""
    data = {
        "units": [{"aliases": ["a"], "unitType": "TYPE A"}],
        "groups": [
            {
                "aliases": ["g1"],
                "hidden": True,
                "disposition": {"h": 3, "w": 4},
                "units": [
                    {"type": "U1", "cell": 8},
                    {"type": "U2", "number": 4},
                    {"type": "U3", "number": {"min": 1, "max": 2}, "random": True},
                    {"type": "U4", "size": 10, "hdg": 90},
                    {"type": "U5", "fitToUnit": True},
                ],
                "description": "desc",
                "groupName": "name",
            }
        ],
    }
    lua = render_spawn_data_lua(data)
    assert _extract_table(lua, "UnitsDatabase") == _expected_unit_db(data["units"])
    assert _extract_table(lua, "GroupsDatabase") == _expected_groups_db(data["groups"])


def test_render_escapes_special_chars() -> None:
    """Quotes and backslashes in strings round-trip safely."""
    data = {
        "units": [{"aliases": [r'a"b\c']}, ],
        "groups": [],
    }
    data["units"][0]["unitType"] = r'Weird "Name" \ thing'
    lua = render_spawn_data_lua(data)
    parsed = _extract_table(lua, "UnitsDatabase")
    assert parsed[0]["unitType"] == r'Weird "Name" \ thing'
    assert parsed[0]["aliases"][0] == r'a"b\c'
