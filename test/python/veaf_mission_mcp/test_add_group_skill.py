"""The opposition's level, and a static placed where the ground is not clear (FIX-COWORK-SESSION-FINDINGS 09, 12).

09: `add_group` wrote `"skill": "Average"` on every unit; the user could not choose the enemy's level.
12: six fuel tanks went into a zone with no word about clear ground, while a vehicle at the same spot was moved
625 m; the assistant then probed with a throw-away vehicle group.
"""

from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.clear_ground_placement import Placement
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


def _skills(folder: Path, fragment: str) -> list[str]:
    content = read_mission_folder(folder).mission_content or {}
    for country in _items(content["coalition"]["red"]["country"]):
        for group in _items((country.get("vehicle") or {}).get("group")):
            if fragment in group["name"]:
                return [unit["skill"] for unit in _items(group["units"])]
    raise AssertionError(f"no vehicle group named like {fragment!r}")


def _add(folder: Path, **options: Any) -> dict[str, Any]:
    return add_group(
        folder,
        category=options.pop("category", "vehicle"),
        name=options.pop("name", "Shilka"),
        position={"x": -280000.0, "y": 640000.0},
        units=options.pop("units", [{"type": "ZSU-23-4 Shilka", "count": 2}]),
        keep_position=True,
        **_RED,
        **options,
    )


def test_average_stays_the_default(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _add(folder)
    assert _skills(folder, "Shilka") == ["Average", "Average"]


def test_the_group_skill_goes_on_every_unit_and_a_units_own_wins(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _add(folder, skill="Excellent", units=[{"type": "ZSU-23-4 Shilka"}, {"type": "ZSU-23-4 Shilka", "skill": "Good"}])
    assert _skills(folder, "Shilka") == ["Excellent", "Good"]


@pytest.mark.parametrize("bad", ["Client", "Expert"])
def test_an_unknown_skill_is_refused(tmp_path: Path, bad: str) -> None:
    with pytest.raises(ValueError, match="skill must be one of"):
        _add(_folder(tmp_path), skill=bad)


def test_a_static_takes_no_skill(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="a static has no AI skill"):
        _add(_folder(tmp_path), category="static", name="Tank", units=[{"type": "Tank"}], skill="High")


def test_a_combat_zone_gives_its_skill_to_its_units_but_not_to_its_statics(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    create_combat_zone(
        folder,
        zone_name="Depot",
        position={"x": -280000.0, "y": 640000.0},
        radius=400,
        groups=[
            {"name": "-AAA", "units": [{"type": "ZSU-23-4 Shilka"}], "keep_position": True},
            {"name": "-Tank", "category": "static", "units": [{"type": "Tank", "name": "Depot Tank"}]},
        ],
        skill="High",
        **_RED,
    )
    assert _skills(folder, "Depot--AAA") == ["High"]


def test_a_static_on_ground_not_clear_is_warned_and_not_moved(tmp_path: Path, monkeypatch) -> None:
    import veaf_mission_mcp.add_group as module

    monkeypatch.setattr(module, "place_on_clear_ground", lambda *a, **k: Placement(300.0, -400.0, "moved 500 m"))
    folder = _folder(tmp_path)
    result = _add(folder, category="static", name="Tank", units=[{"type": "Tank", "name": "Depot Tank"}])
    warnings = [entry["warning"] for entry in result["warnings"] if "clear spot" in entry["warning"]]
    assert len(warnings) == 1
    assert "500 m away" in warnings[0] and "x=-279700, y=639600" in warnings[0] and "Not moved" in warnings[0]
    content = read_mission_folder(folder).mission_content or {}
    statics = [
        unit
        for country in _items(content["coalition"]["red"]["country"])
        for group in _items((country.get("static") or {}).get("group"))
        for unit in _items(group["units"])
    ]
    assert (statics[0]["x"], statics[0]["y"]) == (-280000.0, 640000.0)


def test_the_other_statics_of_a_depot_are_not_scenery(tmp_path: Path, monkeypatch) -> None:
    """Six tanks 20 m apart: only the scenery decides, or every tank after the first was warned."""
    import veaf_mission_mcp.add_group as module

    seen: list[Any] = []

    def placement(*args: Any, **kwargs: Any) -> Placement:
        seen.append(kwargs.get("occupied"))
        return Placement(0.0, 0.0, None)

    monkeypatch.setattr(module, "place_on_clear_ground", placement)
    folder = _folder(tmp_path)
    for n in (1, 2):
        _add(folder, category="static", name=f"Tank{n}", units=[{"type": "Tank", "name": f"Depot Tank {n}"}])
    assert seen == [None, None]


def test_a_static_where_no_catalogue_looks_says_so(tmp_path: Path, monkeypatch) -> None:
    import veaf_mission_mcp.add_group as module

    message = "no clear-ground catalogue covers this place on Caucasus"
    monkeypatch.setattr(module, "place_on_clear_ground", lambda *a, **k: Placement(0.0, 0.0, message, covered=False))
    result = _add(_folder(tmp_path), category="static", name="Tank", units=[{"type": "Tank"}])
    assert any(message in entry["warning"] for entry in result["warnings"])
