"""Tests for the wave-8 `create_combat_zone` composite builder."""

from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml
from mission_tools.miz_tools import read_mission_folder
from veaf_mission_mcp.composites import create_combat_zone

_MISSION = """\
mission =
{
  ["coalition"] =
  {
    ["red"] =
    {
      ["country"] =
      {
      },
    },
  },
  ["triggers"] =
  {
    ["zones"] =
    {
    },
  },
}
"""

_YAML = """\
# mission config
modules:
  COMBATMISSION: true
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text(_YAML, encoding="utf-8")
    return tmp_path


def _zone_names(content: dict[str, Any]) -> list[str]:
    zones = content.get("triggers", {}).get("zones", [])
    values = zones.values() if isinstance(zones, dict) else zones
    return [z["name"] for z in values if isinstance(z, dict) and "name" in z]


def _group_names(content: dict[str, Any]) -> list[str]:
    names: list[str] = []
    for coalition in content.get("coalition", {}).values():
        countries = coalition.get("country", {})
        for country in countries.values() if isinstance(countries, dict) else countries:
            for cat in (v for v in country.values() if isinstance(v, dict) and "group" in v):
                groups = cat["group"]
                for group in groups.values() if isinstance(groups, dict) else groups:
                    if isinstance(group, dict) and "name" in group:
                        names.append(group["name"])
    return names


def test_create_combat_zone_lays_down_both_worlds(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = create_combat_zone(
        folder,
        zone_name="CZ-North",
        position={"x": 1000.0, "y": 2000.0},
        radius=3000,
        groups=[{"name": "armor", "units": [{"type": "T-72B", "count": 2}]}],
        coalition="red",
        country_id=0,
        country_name="Russia",
    )

    assert result["zone_name"] == "CZ-North"
    assert result["groups"] == ["CZ-North-armor"]

    content = read_mission_folder(folder).mission_content or {}
    assert "CZ-North" in _zone_names(content)  # trigger zone written to src/mission
    assert "CZ-North-armor" in _group_names(content)  # group written, zone-prefixed

    modules = load_yaml(folder / "mission.yaml")["modules"]
    zones = modules["COMBATZONE"]["combat_zones"]
    assert any(z["zone_name"] == "CZ-North" for z in zones)  # COMBATZONE block appended


def test_create_combat_zone_assigns_the_country_to_its_side(tmp_path: Path) -> None:
    # The composite routes through the same writer as add_group, so coalitions is populated for it too
    # — without this a combat zone's groups live in a side DCS refuses to load.
    folder = _folder(tmp_path)
    create_combat_zone(
        folder,
        zone_name="CZ-North",
        position={"x": 1000.0, "y": 2000.0},
        radius=3000,
        groups=[{"name": "armor", "units": [{"type": "T-72B", "count": 2}]}],
        coalition="red",
        country_id=0,
        country_name="Russia",
    )

    content = read_mission_folder(folder).mission_content or {}
    assert content["coalitions"]["red"] == [0]


def test_create_combat_zone_appends_to_existing(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    common: dict[str, Any] = {
        "position": {"x": 0.0, "y": 0.0},
        "radius": 1000,
        "groups": [{"name": "g", "units": [{"type": "T-72B", "count": 1}]}],
        "coalition": "red",
        "country_id": 0,
        "country_name": "Russia",
    }
    create_combat_zone(folder, zone_name="CZ-A", **common)
    create_combat_zone(folder, zone_name="CZ-B", **common)

    zones = load_yaml(folder / "mission.yaml")["modules"]["COMBATZONE"]["combat_zones"]
    names = {z["zone_name"] for z in zones}
    assert {"CZ-A", "CZ-B"} <= names  # second call appended, didn't clobber the first
