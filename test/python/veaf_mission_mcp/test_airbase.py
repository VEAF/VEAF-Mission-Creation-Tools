"""Tests for set_airbase_coalition + the lazy airbase-entry helper (FEAT-MCP-AIRBASES-WAREHOUSES)."""

from pathlib import Path
from typing import Any

import pytest
from mission_builder.warehouses_bootstrap import DEFAULT_AIRPORT
from mission_tools.miz_tools import DcsMission
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_mission_mcp import airbase
from veaf_mission_mcp.airbase import _airbase_entry, set_airbase_coalition

_THEATRE = "Caucasus"
_AIRFIELD = "Batumi"  # a known Caucasus airfield


def _mission(airports: dict[Any, Any] | None = None) -> DcsMission:
    return DcsMission(
        file_path=Path("mission"),
        mission_content={},
        theatre_content=_THEATRE,
        warehouses_content={"airports": airports if airports is not None else {}, "warehouses": {}, "weapons": {}},
    )


class TestAirbaseEntry:
    def test_resolves_name_and_creates_entry_under_int_id(self) -> None:
        expected_id = airdrome_id_for_name(_THEATRE, _AIRFIELD)
        assert expected_id is not None  # sanity: airdrome data is present
        mission = _mission()

        airdrome_id, entry = _airbase_entry(mission, _AIRFIELD)

        assert airdrome_id == expected_id
        # keyed by the int id (matches the build's warehouses injector), created lazily
        assert mission.warehouses_content["airports"][expected_id] is entry

    def test_reuses_existing_entry_in_place(self) -> None:
        expected_id = airdrome_id_for_name(_THEATRE, _AIRFIELD)
        mission = _mission(airports={expected_id: {"coalition": "RED", "keep": 1}})

        _airdrome_id, entry = _airbase_entry(mission, _AIRFIELD)

        assert entry["keep"] == 1  # same entry, not a fresh one

    def test_unknown_airfield_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown airfield"):
            _airbase_entry(_mission(), "Nowheresville")


class TestSetAirbaseCoalition:
    def test_writes_coalition_and_enables_dynamic_spawn(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        expected_id = airdrome_id_for_name(_THEATRE, _AIRFIELD)
        mission = _mission()
        saved: dict[str, Any] = {}
        monkeypatch.setattr(airbase, "load_folder_mission", lambda _p: mission)
        monkeypatch.setattr(airbase, "save_folder_mission", lambda _m, _p: saved.update(done=True) or {})

        result = set_airbase_coalition(tmp_path, name=_AIRFIELD, coalition="blue")

        entry = mission.warehouses_content["airports"][expected_id]
        assert entry["coalition"] == "BLUE"
        assert entry["dynamicSpawn"] is True
        assert result["coalition"] == "BLUE"
        assert result["dynamic_spawn"] is True
        assert result["durable"] is True
        assert result["airdrome_id"] == expected_id
        assert saved["done"]  # persisted

    def test_rejects_unknown_coalition(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="coalition must be"):
            set_airbase_coalition(tmp_path, name=_AIRFIELD, coalition="green")


class TestTheEntryIsUsableByDcs:
    """A new airfield entry must carry the full shape, not just the two keys this action sets.

    Measured in game on 2026-08-16: an entry holding only `coalition` and `dynamicSpawn` (plus what
    the warehouses step adds) leaves the airfield unusable — its parked slots cannot be taken and
    its dynamic-slot catalogue shows zero aircraft of every type. Fifteen keys were missing,
    `unlimitedAircrafts` among them.
    """

    def test_a_new_entry_carries_the_full_airfield_shape(self) -> None:
        mission = _mission()
        _, entry = _airbase_entry(mission, "Batumi")
        assert set(DEFAULT_AIRPORT).issubset(set(entry)), sorted(set(DEFAULT_AIRPORT) - set(entry))
        assert entry["unlimitedAircrafts"] is True

    def test_an_existing_entry_keeps_its_own_values(self) -> None:
        airdrome_id = airdrome_id_for_name(_THEATRE, "Batumi")
        mine = {"coalition": "RED", "size": 42}
        mission = _mission({airdrome_id: mine})
        _, entry = _airbase_entry(mission, "Batumi")
        assert entry is mine
        assert entry["coalition"] == "RED"
        assert entry["size"] == 42
