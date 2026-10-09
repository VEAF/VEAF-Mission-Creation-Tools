"""A QRA takes off from its airfield's runway by default (FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 04).

*Kolkhida* mission 1 put its three `QRA Senaki` groups in the air, at 4 572 m; David asked for the QRA to
roll from the runway, then decided: "QRA au sol, par défaut". An air start only when asked.
"""

from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_mission_mcp.airbase import set_airbase_coalition
from veaf_mission_mcp.composites import create_qra

#: Near Senaki, mission coordinates: the QRA zone of *Kolkhida*.
_SENAKI = {"x": -281903.0, "y": 648379.0}


def _folder(tmp_path: Path, red_fields: tuple[str, ...] = ("Senaki-Kolkhi",)) -> Path:
    for relative, content in generate_blank_mission("Caucasus").items():
        path = tmp_path / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (tmp_path / "mission.yaml").write_text("modules:\n  QRA: true\n", encoding="utf-8")
    for field in red_fields:
        set_airbase_coalition(tmp_path, name=field, coalition="red")
    return tmp_path


def _items(table: Any) -> list[Any]:
    return list(table.values()) if isinstance(table, dict) else list(table or [])


def _group(folder: Path, name: str) -> dict[str, Any]:
    content = read_mission_folder(folder).mission_content or {}
    for coalition in content["coalition"].values():
        for country in _items(coalition.get("country")):
            for group in _items((country.get("plane") or {}).get("group")):
                if group.get("name") == name:
                    return group
    raise AssertionError(f"no plane group named {name!r}")


def _qra(folder: Path, **spec: Any) -> dict[str, Any]:
    return create_qra(
        folder,
        name="QRA Senaki",
        coalition="red",
        trigger_zone="QRA Senaki",
        position=_SENAKI,
        radius=40000,
        groups=[{"name": "QRA Senaki MiG-29", "units": [{"type": "MiG-29S", "count": 2}], **spec}],
        country_id=81,
        country_name="CJTF Red",
    )


def test_without_a_word_on_the_start_it_rolls_from_its_sides_nearest_runway(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = _qra(folder)
    group = _group(folder, "QRA Senaki MiG-29")
    first = _items(group["route"]["points"])[0]
    assert (first["type"], first["action"]) == ("TakeOff", "From Runway")
    assert first["airdromeId"] == airdrome_id_for_name("Caucasus", "Senaki-Kolkhi")
    assert group["lateActivation"] is True
    assert not [w for w in result["warnings"] if "air start" in w["warning"]]


def test_an_airfield_named_wins(tmp_path: Path) -> None:
    folder = _folder(tmp_path, red_fields=("Senaki-Kolkhi", "Kutaisi"))
    _qra(folder, airfield="Kutaisi")
    first = _items(_group(folder, "QRA Senaki MiG-29")["route"]["points"])[0]
    assert first["airdromeId"] == airdrome_id_for_name("Caucasus", "Kutaisi")


def test_an_air_start_when_asked(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _qra(folder, start="air")
    first = _items(_group(folder, "QRA Senaki MiG-29")["route"]["points"])[0]
    assert first["type"] == "Turning Point"
    assert first["alt"] > 0


def test_with_no_airfield_of_its_side_it_starts_in_the_air_and_says_why(tmp_path: Path) -> None:
    folder = _folder(tmp_path, red_fields=())
    result = _qra(folder)
    first = _items(_group(folder, "QRA Senaki MiG-29")["route"]["points"])[0]
    assert first["type"] == "Turning Point"
    assert any("air start" in warning["warning"] for warning in result["warnings"])


def test_a_runway_start_asked_where_none_can_be_is_refused(tmp_path: Path) -> None:
    folder = _folder(tmp_path, red_fields=())
    with pytest.raises(ValueError, match="airfield"):
        _qra(folder, start="runway")


def test_an_unknown_airfield_named_is_refused_not_put_in_the_air(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="Senakii"):
        _qra(folder, airfield="Senakii")
