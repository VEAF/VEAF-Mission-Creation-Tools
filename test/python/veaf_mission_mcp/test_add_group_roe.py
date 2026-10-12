r"""A ground group that holds fire and does not disperse (FIX-OPEN-TRAINING-MARIANAS-FINDINGS ticket 06).

The Open Training wants its easy-level targets warm, weapons hold and not dispersing under fire; GermanyCW,
Syria and Marianas each wrote a script rewriting the first waypoint's task in the mission table.
The shape below is the editor's, measured over 606 missions under D:\dev\_VEAF on 2026-10-12: ROE is
`Option` 0 (2 open fire, 3 return fire, 4 weapon hold) and an unchecked « Disperse under fire » is `Option` 8
with no value (2 151 occurrences).
"""

from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs.blank_mission import generate_blank_mission
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.composites import create_combat_zone

_RED = {"coalition": "red", "country_id": 81, "country_name": "CJTF Red"}


def _folder(tmp_path: Path) -> Path:
    for relative, content in generate_blank_mission("Caucasus").items():
        path = tmp_path / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


def _items(table: Any) -> list[Any]:
    return list(table.values()) if isinstance(table, dict) else list(table or [])


def _first_tasks(folder: Path, fragment: str) -> list[dict[str, Any]]:
    content = read_mission_folder(folder).mission_content or {}
    for country in _items(content["coalition"]["red"]["country"]):
        for group in _items((country.get("vehicle") or {}).get("group")):
            if fragment in group["name"]:
                return _items(_items(group["route"]["points"])[0]["task"]["params"]["tasks"])
    raise AssertionError(f"no vehicle group named like {fragment!r}")


def _target(folder: Path, **options: Any) -> None:
    add_group(
        folder,
        category="vehicle",
        name="Target",
        position={"x": -280000.0, "y": 640000.0},
        units=[{"type": "T-55", "count": 1}],
        keep_position=True,
        **_RED,
        **options,
    )


def test_weapons_hold_and_no_dispersal_are_written_as_the_editor_writes_them(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _target(folder, roe="weapons_hold", disperse=False)
    assert _first_tasks(folder, "Target") == [
        {
            "id": "WrappedAction",
            "auto": False,
            "enabled": True,
            "number": 1,
            "params": {"action": {"id": "Option", "params": {"name": 0, "value": 4}}},
        },
        {
            "id": "WrappedAction",
            "auto": False,
            "enabled": True,
            "number": 2,
            "params": {"action": {"id": "Option", "params": {"name": 8}}},
        },
    ]


@pytest.mark.parametrize(("roe", "value"), [("weapons_free", 2), ("return_fire", 3)])
def test_each_roe_has_its_value(tmp_path: Path, roe: str, value: int) -> None:
    folder = _folder(tmp_path)
    _target(folder, roe=roe)
    [task] = _first_tasks(folder, "Target")
    assert task["params"]["action"]["params"] == {"name": 0, "value": value}


def test_a_group_without_the_options_is_unchanged(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _target(folder, disperse=True)  # DCS's own default: nothing to write
    assert _first_tasks(folder, "Target") == []


def test_an_unknown_roe_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="roe"):
        _target(_folder(tmp_path), roe="hold_fire")


def test_the_options_are_for_a_vehicle_group(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="vehicle"):
        add_group(
            folder,
            category="static",
            name="Depot",
            position={"x": -280000.0, "y": 640000.0},
            units=[{"type": "Shelter", "count": 1}],
            roe="weapons_hold",
            **_RED,
        )


def test_a_combat_zone_group_takes_them(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    create_combat_zone(
        folder,
        zone_name="combatZone_Range",
        position={"x": -280000.0, "y": 640000.0},
        radius=2000,
        groups=[
            {"name": "Inert", "units": [{"type": "T-55"}], "roe": "weapons_hold", "disperse": False},
            {"name": "Live", "units": [{"type": "T-55"}]},
        ],
        **_RED,
    )
    assert len(_first_tasks(folder, "Inert")) == 2
    assert _first_tasks(folder, "Live") == []
