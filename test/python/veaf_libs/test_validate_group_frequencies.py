"""`validate` warns on an aircraft group whose frequency its airframe cannot tune (FIX-OPEN-TRAINING-NORMANDY-FINDINGS 13).

The Mission Editor refused to save the Normandy Open Training: a P-51D and two Fw 190 groups were written with
251 MHz. The build, `validate` and the tests never opened the file in the editor and said nothing.
"""

import tempfile
from pathlib import Path
from typing import Any

import pytest
from veaf_libs.mission_validator import WARNING, _check_group_frequencies, validate_mission_folder


def _mission(unit_type: str, frequency: Any, name: str = "Flight") -> dict[str, Any]:
    group = {"name": name, "frequency": frequency, "units": [{"type": unit_type, "name": f"{name}-1"}]}
    return {"coalition": {"blue": {"country": [{"id": 2, "plane": {"group": [group]}}]}}}


@pytest.mark.parametrize(("unit_type", "frequency"), [("P-51D", 251), ("FW-190A8", 251.0), ("FW-190D9", 124)])
def test_a_group_its_airframe_cannot_tune_is_reported(unit_type: str, frequency: float) -> None:
    issues = _check_group_frequencies(_mission(unit_type, frequency))
    assert [i.level for i in issues] == [WARNING]
    assert "Flight" in issues[0].message and unit_type in issues[0].message


@pytest.mark.parametrize(
    ("unit_type", "frequency"),
    [("P-51D", 124.0), ("FW-190A8", 38.4), ("F-16C_50", 251), ("NoSuchModType", 251), ("P-51D", None)],
)
def test_a_tunable_unknown_or_missing_frequency_is_not_reported(unit_type: str, frequency: Any) -> None:
    assert _check_group_frequencies(_mission(unit_type, frequency)) == []


def test_validate_runs_the_check() -> None:
    folder = Path(tempfile.mkdtemp())
    (folder / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    (folder / "src" / "mission").mkdir(parents=True)
    lua = (
        'mission = { ["coalition"] = { ["blue"] = { ["country"] = { [1] = { ["id"] = 2, ["plane"] = { ["group"] = {'
        ' [1] = { ["name"] = "TEST P-51D", ["frequency"] = 251, ["units"] = { [1] = { ["type"] = "P-51D",'
        ' ["name"] = "TEST P-51D-1" } } } } } } } } } }'
    )
    (folder / "src" / "mission" / "mission").write_text(lua, encoding="utf-8")
    messages = [i.message for i in validate_mission_folder(folder) if i.level == WARNING]
    assert any("TEST P-51D" in m and "251" in m for m in messages)
