"""Tests for the spawn-data Lua emitter (SPAWN-EXTERNALIZE-002).

The emitter renders ``veaf-units.yaml`` to a Lua module assigning
``veafUnits.UnitsDatabase`` / ``veafUnits.GroupsDatabase``. These tests prove the
render is faithful by parsing the output back with the pure-Python ``luadata``
parser (an independent code path) and comparing to the YAML source.
"""

from __future__ import annotations

from typing import Any

import luadata
import pytest
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


def test_render_collapses_integral_floats() -> None:
    """User YAML numbers may parse as floats (e.g. ``size: 10.0``); render as ints."""
    data = {
        "units": [],
        "groups": [
            {
                "aliases": ["g"],
                "disposition": {"h": 3, "w": 3},
                "units": [{"type": "U", "cell": 8.0, "size": 10.0}],
            }
        ],
    }
    lua = render_spawn_data_lua(data)
    parsed = _extract_table(lua, "GroupsDatabase")
    unit = parsed[0]["group"]["units"][0]
    assert unit["cell"] == 8
    assert unit["size"] == 10


def test_render_escapes_special_chars() -> None:
    """Quotes and backslashes in strings round-trip safely."""
    data = {
        "units": [
            {"aliases": [r'a"b\c']},
        ],
        "groups": [],
    }
    data["units"][0]["unitType"] = r'Weird "Name" \ thing'
    lua = render_spawn_data_lua(data)
    parsed = _extract_table(lua, "UnitsDatabase")
    assert parsed[0]["unitType"] == r'Weird "Name" \ thing'
    assert parsed[0]["aliases"][0] == r'a"b\c'


# --------------------------------------------------------------------------------------------
# SECREV-2 / VMR-055 — half of this data is hand-written per mission, and the renderers index
# required keys directly. A typo used to surface as a bare `KeyError: 'type'` with a Python
# traceback and nothing to say which entry was at fault.
# --------------------------------------------------------------------------------------------


def test_a_unit_entry_missing_its_type_names_the_entry() -> None:
    data = {"units": [], "groups": [{"aliases": ["x"], "disposition": {"h": 1, "w": 1}, "units": [{"cell": 1}]}]}

    with pytest.raises(ValueError) as caught:
        render_spawn_data_lua(data)

    message = str(caught.value)
    assert "type" in message, message
    assert "groups" in message and "0" in message, f"the message must locate the entry: {message}"


def test_a_group_entry_missing_its_disposition_names_the_entry() -> None:
    data = {"units": [], "groups": [{"aliases": ["a"]}, {"aliases": ["b"]}]}

    with pytest.raises(ValueError) as caught:
        render_spawn_data_lua(data)

    assert "disposition" in str(caught.value)


def test_a_unusable_value_is_reported_rather_than_raising_a_bare_valueerror() -> None:
    # `int("many")` used to escape as ValueError with no context at all.
    data = {"units": [], "groups": [{"aliases": ["x"], "disposition": {"h": "many", "w": 1}, "units": []}]}

    with pytest.raises(ValueError) as caught:
        render_spawn_data_lua(data)

    assert "groups" in str(caught.value)


def test_a_well_formed_entry_is_untouched() -> None:
    data = {"units": [], "groups": [{"aliases": ["x"], "disposition": {"h": 1, "w": 1}, "units": [{"type": "T-72B"}]}]}

    lua = render_spawn_data_lua(data)

    # A unit with only a type comes back as a positional list: `{ "T-72B" }`.
    assert _extract_table(lua, "GroupsDatabase")[0]["group"]["units"][0] == ["T-72B"]
