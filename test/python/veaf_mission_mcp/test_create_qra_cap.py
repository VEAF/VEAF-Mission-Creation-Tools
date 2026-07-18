"""Tests for the wave-8 `create_qra` and `create_cap_mission` composite builders."""

from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml
from mission_tools.miz_tools import read_mission_folder

from veaf_mission_mcp.composites import create_cap_mission, create_qra

_MISSION = """\
mission =
{
  ["coalition"] =
  {
    ["blue"] =
    {
      ["country"] =
      {
      },
    },
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

_YAML = "# config\nmodules:\n  COMBATMISSION: true\n"


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text(_YAML, encoding="utf-8")
    return tmp_path


def _find_group(content: dict[str, Any], name: str) -> dict[str, Any] | None:
    for coalition in content.get("coalition", {}).values():
        countries = coalition.get("country", {})
        for country in countries.values() if isinstance(countries, dict) else countries:
            for cat in (v for v in country.values() if isinstance(v, dict) and "group" in v):
                groups = cat["group"]
                for group in groups.values() if isinstance(groups, dict) else groups:
                    if isinstance(group, dict) and group.get("name") == name:
                        return group
    return None


def test_create_qra_lays_down_both_worlds(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = create_qra(
        folder,
        name="QRA-North",
        coalition="red",
        trigger_zone="ZONE-QRA",
        position={"x": 1.0, "y": 2.0},
        radius=50000,
        groups=[{"name": "MiG-29 North", "units": [{"type": "MiG-29S", "count": 2}]}],
        country_id=0,
        country_name="Russia",
    )
    assert result["groups"] == ["MiG-29 North"]

    content = read_mission_folder(folder).mission_content or {}
    group = _find_group(content, "MiG-29 North")
    assert group is not None
    assert group["lateActivation"] is True  # QRA interceptors must be late-activation

    definitions = load_yaml(folder / "mission.yaml")["modules"]["QRA"]["definitions"]
    definition = next(d for d in definitions if d["name"] == "QRA-North")
    assert definition["coalition"] == "RED"  # upper-cased for the YAML definition
    assert definition["trigger_zone"] == "ZONE-QRA"
    assert "MiG-29 North" in definition["simple_groups"]  # referenced by exact name


def test_create_cap_mission_lays_down_both_worlds(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = create_cap_mission(
        folder,
        mission_name="Escort",
        units=[{"type": "F-15C", "count": 2}],
        coalition="blue",
        country_id=2,
        country_name="USA",
        position={"x": 1.0, "y": 2.0},
    )
    assert result["group"] == "OnDemand-Escort"

    content = read_mission_folder(folder).mission_content or {}
    group = _find_group(content, "OnDemand-Escort")
    assert group is not None
    assert group["lateActivation"] is True  # CAP template is late-activation

    caps = load_yaml(folder / "mission.yaml")["cap_missions"]
    assert any(c["group_name"] == "Escort" for c in caps)  # yaml references the un-prefixed name
