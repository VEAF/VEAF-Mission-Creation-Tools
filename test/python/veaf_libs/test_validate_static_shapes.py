"""`validate` warns on a static written without the `shape_name` its type has (FIX-IN-GAME-TEST-FINDINGS 01).

GermanyCW-v6, 2026-09-28: four objectives placed by the MCP before the fix carried no `shape_name`,
and DCS refused them at load (`unknown static shape_name, category Fortification, type: .Command
Center`). Nothing in the mission, the build or the validation said so; the missions already built
are caught here.
"""

import tempfile
from pathlib import Path
from typing import Any

from veaf_libs.mission_validator import WARNING, _check_static_shapes, validate_mission_content, validate_mission_folder


def _mission(units: list[dict[str, Any]]) -> dict[str, Any]:
    groups = [{"name": u["name"], "units": [u]} for u in units]
    return {"coalition": {"red": {"country": [{"id": 0, "static": {"group": groups}}]}}}


def _shape_warnings(units: list[dict[str, Any]]) -> list[str]:
    return [i.message for i in _check_static_shapes(_mission(units)) if i.level == WARNING]


def test_a_static_without_its_shape_is_reported_with_the_shape_to_write() -> None:
    messages = _shape_warnings([{"type": ".Command Center", "name": "CZ_Wunsdorf-HQ"}])
    assert len(messages) == 1
    assert "CZ_Wunsdorf-HQ" in messages[0] and "ComCenter" in messages[0]


def test_a_static_carrying_its_shape_is_not_reported() -> None:
    assert _shape_warnings([{"type": ".Command Center", "name": "HQ", "shape_name": "ComCenter"}]) == []


def test_a_type_with_no_known_shape_is_not_reported() -> None:
    assert _shape_warnings([{"type": "T-55", "name": "wreck"}, {"type": "SomeMod static", "name": "mod"}]) == []


def test_each_unit_is_reported() -> None:
    units = [{"type": ".Ammunition depot", "name": f"CZ_Torgau-depot {i}"} for i in (1, 2)]
    assert len(_shape_warnings(units)) == 2


_MISSION_LUA = """mission =
{
    ["coalition"] = { ["red"] = { ["country"] = { [1] = { ["id"] = 0, ["static"] = { ["group"] = {
        [1] = { ["name"] = "CZ_Wunsdorf-HQ", ["units"] = { [1] = { ["type"] = ".Command Center", ["name"] = "CZ_Wunsdorf-HQ" } } },
    } } } } } },
}
"""


def test_validate_runs_the_check() -> None:
    folder = Path(tempfile.mkdtemp())
    (folder / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    (folder / "src" / "mission").mkdir(parents=True)
    (folder / "src" / "mission" / "mission").write_text(_MISSION_LUA, encoding="utf-8")
    messages = [i.message for i in validate_mission_folder(folder) if i.level == WARNING]
    assert any("CZ_Wunsdorf-HQ" in m and "ComCenter" in m for m in messages)


def test_the_build_summary_does_not_carry_it() -> None:
    """The build prints validate_mission_content under a 'missing mission.yaml references' header."""
    issues = validate_mission_content({}, _mission([{"type": ".Command Center", "name": "HQ"}]))
    assert not any("shape_name" in i.message for i in issues)
