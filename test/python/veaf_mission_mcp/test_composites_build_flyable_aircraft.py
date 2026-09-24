"""`create_qra` and `create_cap_mission` must build aircraft that can fly.

FIX-SCRATCH-MISSION-FINDINGS ticket 06: both composites built their groups with `add_group`'s
ground-vehicle builder, so on GermanyCW-v6 the QRA MiGs and the on-demand CAP were written as
`task = "Ground Nothing"`, first point `alt = 0`, `action = "Off Road"`, 5.5 m/s, no payload and no
fuel — a valid file whose aircraft appear at ground level at 20 km/h, empty, when activated.
"""

from pathlib import Path
from typing import Any

import pytest
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
        [1] =
        {
          ["id"] = 0,
          ["name"] = "Russia",
          ["plane"] =
          {
            ["group"] =
            {
              [1] =
              {
                ["name"] = "veafSpawn-MiG-23 CAP",
                ["units"] =
                {
                  [1] =
                  {
                    ["type"] = "MiG-23MLD",
                    ["name"] = "veafSpawn-MiG-23 CAP-1",
                    ["payload"] =
                    {
                      ["pylons"] =
                      {
                        [2] =
                        {
                          ["CLSID"] = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}",
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
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

_GROUND_KEYS = ("playerCanDrive", "coldAtStart")


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules:\n  QRA: true\n", encoding="utf-8")
    return tmp_path


def _items(table: Any) -> list[Any]:
    return list(table.values()) if isinstance(table, dict) else list(table or [])


def _plane_group(folder: Path, name: str) -> dict[str, Any]:
    content = read_mission_folder(folder).mission_content or {}
    for coalition in content["coalition"].values():
        for country in _items(coalition.get("country")):
            for group in _items((country.get("plane") or {}).get("group")):
                if group.get("name") == name:
                    return group
    raise AssertionError(f"no plane group named {name!r}")


def _assert_flyable(group: dict[str, Any]) -> None:
    assert group["task"] != "Ground Nothing"
    assert group["lateActivation"] is True
    first = _items(group["route"]["points"])[0]
    assert first["alt"] > 0, "an air start at ground level"
    assert first["type"] == "Turning Point"
    assert first["action"] == "Turning Point", "'Off Road' is a vehicle action"
    assert first["speed"] > 50, "a jet at 20 km/h stalls"
    for unit in _items(group["units"]):
        assert unit["alt"] > 0
        assert unit["payload"]["fuel"] > 0, "no fuel: the aircraft falls out of the sky"
        for key in _GROUND_KEYS:
            assert key not in unit


def _qra(folder: Path, **extra: Any) -> dict[str, Any]:
    spec = {"name": "QRA_Stendal-MiG21", "units": [{"type": "MiG-21Bis", "count": 2}]}
    spec.update(extra)
    return create_qra(
        folder,
        name="QRA_Stendal",
        coalition="red",
        trigger_zone="QRA_Stendal",
        position={"x": 1000.0, "y": 2000.0},
        radius=50000,
        groups=[spec],
        country_id=0,
        country_name="Russia",
    )


def test_a_qra_interceptor_can_fly(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _qra(folder)
    _assert_flyable(_plane_group(folder, "QRA_Stendal-MiG21"))


def test_a_qra_interceptor_carries_the_loadout_it_is_given(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    pylons = {1: {"CLSID": "{R-60M}"}}
    _qra(folder, pylons=pylons)
    unit = _items(_plane_group(folder, "QRA_Stendal-MiG21")["units"])[0]
    assert _items(unit["payload"]["pylons"])[0] == pylons[1]  # luadata reads [1] back as a list


def test_a_qra_interceptor_can_copy_the_loadout_of_a_template(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _qra(folder, loadout_from="veafSpawn-MiG-23 CAP")
    unit = _items(_plane_group(folder, "QRA_Stendal-MiG21")["units"])[0]
    assert _items(unit["payload"]["pylons"])[0]["CLSID"] == "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}"


def test_an_unknown_loadout_template_is_refused(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="nope"):
        _qra(folder, loadout_from="nope")


def test_a_mixed_type_flight_is_refused(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="one aircraft type"):
        _qra(folder, units=[{"type": "MiG-21Bis", "count": 1}, {"type": "MiG-23MLD", "count": 1}])


def _cap(folder: Path, **extra: Any) -> dict[str, Any]:
    return create_cap_mission(
        folder,
        mission_name="MiG23-Border-South",
        units=[{"type": "MiG-23MLD", "count": 2}],
        coalition="red",
        country_id=0,
        country_name="Russia",
        position={"x": 1000.0, "y": 2000.0},
        **extra,
    )


def test_a_cap_template_can_fly(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    _cap(folder)
    _assert_flyable(_plane_group(folder, "OnDemand-MiG23-Border-South"))


def test_a_cap_template_flies_a_race_track_between_its_two_points(tmp_path: Path) -> None:
    """Without a second point the template orbits nowhere."""
    folder = _folder(tmp_path)
    _cap(folder, route=[{"x": 51000.0, "y": 2000.0}])
    points = _items(_plane_group(folder, "OnDemand-MiG23-Border-South")["route"]["points"])
    assert len(points) == 2
    assert (points[1]["x"], points[1]["y"]) == (51000.0, 2000.0)
    tasks = _items(points[0]["task"]["params"]["tasks"])
    orbit = next(t for t in tasks if t["id"] == "Orbit")
    assert orbit["params"]["pattern"] == "Race-Track"
