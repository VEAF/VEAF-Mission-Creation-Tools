"""`edit_route` support-flight tasks — FIX-SCRATCH-MISSION-FINDINGS ticket 07.

The closed task set had no `Tanker`, `AWACS`, `ActivateBeacon`, `EPLRS`, `SetUnlimitedFuel` nor
`Escort`: a "tanker" made by `add_air_group` refueled nobody, and GermanyCW-v6 patched its tankers by
Lua and dropped its escorts. Every shape below was read out of 401 missions under `D:\\dev\\_VEAF`
(2026-09-24): `Tanker` 855 times, `AWACS` 560, `ActivateBeacon` 874, `EPLRS` 12 772,
`SetUnlimitedFuel` 1 390, `Escort` 599 — and the TACAN frequency rule from every beacon they carry.
"""

import zipfile
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.edit_route import edit_route

_MISSION = b"""
mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Texaco",
                ["groupId"] = 7,
                ["units"] = {
                  [1] = {["name"] = "Texaco-1", ["type"] = "KC-135", ["unitId"] = 71},
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {["type"] = "Turning Point", ["action"] = "Turning Point", ["x"] = 0, ["y"] = 0,
                           ["alt"] = 6096, ["speed"] = 200, ["ETA_locked"] = true},
                    [2] = {["type"] = "Turning Point", ["action"] = "Turning Point", ["x"] = 50000, ["y"] = 0,
                           ["alt"] = 6096, ["speed"] = 200, ["ETA_locked"] = false},
                  },
                },
              },
              [2] = {
                ["name"] = "Colt",
                ["groupId"] = 8,
                ["units"] = {
                  [1] = {["name"] = "Colt-1", ["type"] = "F-15C", ["unitId"] = 81},
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {["type"] = "Turning Point", ["action"] = "Turning Point", ["x"] = 0, ["y"] = 0,
                           ["alt"] = 6096, ["speed"] = 200, ["ETA_locked"] = true},
                  },
                },
              },
            },
          },
          ["ship"] = {
            ["group"] = {
              [1] = {
                ["name"] = "CVN",
                ["groupId"] = 9,
                ["units"] = {
                  [1] = {["name"] = "CVN-71", ["type"] = "CVN_71", ["unitId"] = 91},
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {["type"] = "Turning Point", ["action"] = "Turning Point", ["x"] = 0, ["y"] = 0,
                           ["alt"] = 0, ["speed"] = 13, ["ETA_locked"] = true},
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
"""


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _values(container: Any) -> list:
    return list(container.values()) if isinstance(container, dict) else list(container or [])


def _first_task(miz: Path, group_name: str) -> dict[str, Any]:
    content = read_miz(miz).mission_content or {}
    for coalition in _values(content.get("coalition")):
        for country in _values(coalition.get("country")):
            for category in ("plane", "ship"):
                for group in _values((country.get(category) or {}).get("group")):
                    if group.get("name") == group_name:
                        point = _values(group["route"]["points"])[0]
                        return _values(point["task"]["params"]["tasks"])[-1]
    raise AssertionError(group_name)


def _add(miz: Path, group: str, task: str, **params: Any) -> dict[str, Any]:
    edit_route(miz, group_name=group, operation="add_task", index=1, task=task, task_params=params)
    return _first_task(miz, group)


class TestEnrouteTasks:
    def test_tanker(self, miz: Path) -> None:
        entry = _add(miz, "Texaco", "tanker")
        assert (entry["id"], entry["params"]) == ("Tanker", {})

    def test_awacs(self, miz: Path) -> None:
        entry = _add(miz, "Texaco", "awacs")
        assert (entry["id"], entry["params"]) == ("AWACS", {})


class TestActions:
    def test_unlimited_fuel(self, miz: Path) -> None:
        entry = _add(miz, "Texaco", "set_unlimited_fuel")
        assert entry["id"] == "WrappedAction"
        assert entry["params"]["action"] == {"id": "SetUnlimitedFuel", "params": {"value": True}}

    def test_eplrs_names_its_own_group(self, miz: Path) -> None:
        entry = _add(miz, "Colt", "eplrs")
        assert entry["params"]["action"] == {"id": "EPLRS", "params": {"value": True, "groupId": 8}}


class TestActivateBeacon:
    def test_a_tanker_tacan(self, miz: Path) -> None:
        action = _add(miz, "Texaco", "activate_beacon", channel=30, mode="Y", callsign="TXO")["params"]["action"]
        assert action["id"] == "ActivateBeacon"
        params = action["params"]
        assert params["frequency"] == 1117000000, "30Y is 1117 MHz, as the missions store it"
        assert (params["system"], params["type"], params["unitId"]) == (5, 4, 71)
        assert (params["channel"], params["modeChannel"], params["callsign"]) == (30, "Y", "TXO")
        assert params["bearing"] is True

    def test_the_frequency_rule_both_ways(self, miz: Path) -> None:
        """X 1-63 and Y 64-126: 961 + channel MHz; X 64-126 and Y 1-63: 1087 + channel MHz."""
        cases = {(20, "X"): 981, (71, "X"): 1158, (30, "Y"): 1117, (100, "Y"): 1061}
        for (channel, mode), mhz in cases.items():
            action = _add(miz, "Texaco", "activate_beacon", channel=channel, mode=mode, callsign="TXO")
            assert action["params"]["action"]["params"]["frequency"] == mhz * 1_000_000, (channel, mode)

    def test_a_ship_uses_the_ship_system(self, miz: Path) -> None:
        params = _add(miz, "CVN", "activate_beacon", channel=71, mode="X", callsign="TEO")["params"]["action"]["params"]
        assert params["system"] == 3

    def test_a_bad_channel_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="channel"):
            _add(miz, "Texaco", "activate_beacon", channel=127, mode="X", callsign="TXO")

    def test_a_bad_mode_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="mode"):
            _add(miz, "Texaco", "activate_beacon", channel=30, mode="Z", callsign="TXO")

    def test_a_bad_callsign_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="callsign"):
            _add(miz, "Texaco", "activate_beacon", channel=30, mode="X", callsign="TEXACO")


class TestEscort:
    def test_the_escorted_group_is_named_by_its_name(self, miz: Path) -> None:
        entry = _add(miz, "Colt", "escort", group_name="Texaco")
        assert entry["id"] == "Escort"
        assert entry["params"]["groupId"] == 7
        assert entry["params"]["targetTypes"] == ["Planes"]
        assert entry["params"]["value"] == "Planes;"

    def test_an_unknown_escorted_group_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Nobody"):
            _add(miz, "Colt", "escort", group_name="Nobody")
