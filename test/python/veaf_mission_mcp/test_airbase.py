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


def _mission(airports: Any = None) -> DcsMission:
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

    def test_a_list_shaped_table_does_not_break_the_lookup(self) -> None:
        # A mission declaring every airfield of its theatre parses `airports` as a list, and `.get()`
        # on a list raises AttributeError — `set_airbase_coalition` simply crashed on any real
        # mission (FIX-WAREHOUSES-LIST-FORM). The other airfields must also keep their ownership.
        mission = _mission(airports=[{"coalition": "RED"}, {"coalition": "BLUE"}])

        _airdrome_id, entry = _airbase_entry(mission, _AIRFIELD)

        airports = mission.warehouses_content["airports"]
        assert isinstance(airports, dict)
        assert airports[1]["coalition"] == "RED"
        assert airports[2]["coalition"] == "BLUE"
        assert entry is airports[airdrome_id_for_name(_THEATRE, _AIRFIELD)]

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


# FIX-SCRATCH-MISSION-FINDINGS ticket 15: `dynamic_spawn=false` wrote `dynamicSpawn = false` in the
# warehouses table, and the build turned it back on for every base of the side with no `airports:` list
# (61 airfields / 3 111 links on GermanyCW-v6 against 12 / 612). The action now records the base under
# `<side>.exclude_airports` in `src/warehouses.yaml`, which the build honours (worker tests).

_WAREHOUSES_YAML = """\
# Dynamic slots per coalition
blue:
  defaults:
    fuel: unlimited   # keep
red:
  defaults:
    fuel: unlimited
"""


def _folder(tmp_path: Path, warehouses_yaml: str | None = _WAREHOUSES_YAML) -> Path:
    (tmp_path / "src").mkdir()
    if warehouses_yaml is not None:
        (tmp_path / "src" / "warehouses.yaml").write_text(warehouses_yaml, encoding="utf-8")
    return tmp_path


def _yaml(folder: Path) -> Any:
    import yaml

    return yaml.safe_load((folder / "src" / "warehouses.yaml").read_text(encoding="utf-8"))


class TestExclusionList:
    @pytest.fixture(autouse=True)
    def _in_memory_mission(self, monkeypatch: pytest.MonkeyPatch) -> None:
        self.mission = _mission()
        monkeypatch.setattr(airbase, "load_folder_mission", lambda _p: self.mission)
        monkeypatch.setattr(airbase, "save_folder_mission", lambda _m, _p: {})

    def test_a_closed_base_is_recorded_for_the_build(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        assert _yaml(folder)["red"]["exclude_airports"] == [_AIRFIELD]
        assert result["excluded_in_warehouses_yaml"] is True

    def test_the_file_keeps_its_comments(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        text = (folder / "src" / "warehouses.yaml").read_text(encoding="utf-8")
        assert "# Dynamic slots per coalition" in text and "# keep" in text

    def test_reopening_the_base_removes_it(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=True)
        assert "exclude_airports" not in _yaml(folder)["red"]

    def test_changing_side_moves_the_exclusion(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="blue", dynamic_spawn=False)
        data = _yaml(folder)
        assert "exclude_airports" not in data["red"]
        assert data["blue"]["exclude_airports"] == [_AIRFIELD]

    def test_closing_twice_records_it_once(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        assert _yaml(folder)["red"]["exclude_airports"] == [_AIRFIELD]

    def test_no_warehouses_yaml_means_nothing_to_record(self, tmp_path: Path) -> None:
        """Without the file the build never opens a slot, so there is nothing to exclude from."""
        folder = _folder(tmp_path, warehouses_yaml=None)
        result = set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        assert not (folder / "src" / "warehouses.yaml").exists()
        assert result["excluded_in_warehouses_yaml"] is False

    def test_an_undeclared_side_is_not_created(self, tmp_path: Path) -> None:
        """Writing `red:` into a file that only declares blue would open every red base at build."""
        folder = _folder(tmp_path, warehouses_yaml="blue:\n  defaults: {}\n")
        result = set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        assert "red" not in _yaml(folder)
        assert result["excluded_in_warehouses_yaml"] is False

    def test_the_build_keeps_the_recorded_base_closed(self, tmp_path: Path) -> None:
        """End to end: the action's record is what the build reads."""
        from warehouses_injector import apply_warehouses

        folder = _folder(tmp_path)
        expected_id = airdrome_id_for_name(_THEATRE, _AIRFIELD)
        set_airbase_coalition(folder, name=_AIRFIELD, coalition="red", dynamic_spawn=False)
        set_airbase_coalition(folder, name="Kobuleti", coalition="red")
        apply_warehouses(self.mission, _yaml(folder))
        airports = self.mission.warehouses_content["airports"]
        assert airports[expected_id]["dynamicSpawn"] is False
        assert airports[airdrome_id_for_name(_THEATRE, "Kobuleti")]["dynamicSpawn"] is True
