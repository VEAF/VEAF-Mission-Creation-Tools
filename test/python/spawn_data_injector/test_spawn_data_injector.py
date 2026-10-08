"""Tests for the spawn-data injector worker (SPAWN-EXTERNALIZE-003/004)."""

from __future__ import annotations

import zipfile
from pathlib import Path
from unittest.mock import patch

from mission_tools.miz_tools import DcsMission, read_miz
from spawn_data_injector import SpawnDataInjectorWorker, inject_spawn_data, merge_spawn_data
from spawn_data_injector.spawn_data_injector_worker import _MAP_KEY, _RESOURCE_FILENAME
from veaf_libs.i18n import t

_RESOURCE_ARCNAME = f"l10n/DEFAULT/{_RESOURCE_FILENAME}"


def _mission_with_triggers() -> DcsMission:
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "trigrules": {1: {"comment": "a"}, 2: {"comment": "b"}},
            "trig": {
                "actions": {1: "x();", 2: "y();"},
                "conditions": {1: "return true", 2: "return true"},
                "flag": {1: True, 2: True},
                "funcStartup": {1: "...", 2: "..."},
            },
        },
        map_resource_content={},
    )


# ---------------------------------------------------------------------------
# inject_spawn_data
# ---------------------------------------------------------------------------


class TestInjectSpawnData:
    def test_adds_map_resource_entry(self) -> None:
        mission = _mission_with_triggers()
        inject_spawn_data(mission, "-- lua")
        assert mission.map_resource_content[_MAP_KEY] == _RESOURCE_FILENAME

    def test_appends_trigger_after_existing(self) -> None:
        mission = _mission_with_triggers()
        inject_spawn_data(mission, "-- lua")
        # existing max index is 2 -> spawn-data lands at 3
        assert 3 in mission.mission_content["trigrules"]
        assert mission.mission_content["trig"]["actions"][3] == (
            f'a_do_script_file(getValueResourceByKey("{_MAP_KEY}"));'
        )
        assert mission.mission_content["trig"]["conditions"][3] == "return true"
        assert mission.mission_content["trig"]["flag"][3] is True
        # funcStartup is what DCS actually runs at mission start
        assert mission.mission_content["trig"]["funcStartup"][3] == (
            "if mission.trig.conditions[3]() then mission.trig.actions[3]() end"
        )

    def test_trigrule_uses_a_do_script_file(self) -> None:
        mission = _mission_with_triggers()
        inject_spawn_data(mission, "-- lua")
        rule = mission.mission_content["trigrules"][3]
        assert rule["actions"][0] == {"predicate": "a_do_script_file", "file": _MAP_KEY}

    def test_first_trigger_when_none_exist(self) -> None:
        mission = DcsMission(file_path=Path("d.miz"), mission_content={}, map_resource_content=None)
        inject_spawn_data(mission, "-- lua")
        assert 1 in mission.mission_content["trigrules"]
        assert mission.mission_content["trig"]["actions"][1].startswith("a_do_script_file")

    def test_returns_resource_bytes(self) -> None:
        mission = _mission_with_triggers()
        files = inject_spawn_data(mission, "veafUnits.UnitsDatabase = {}")
        assert files[_RESOURCE_ARCNAME] == b"veafUnits.UnitsDatabase = {}"


# ---------------------------------------------------------------------------
# FIX-SPAWN-DATA-LOAD-ORDER — the database loads with the framework, before veaf-config.lua: the
# campaign draws its garrisons while veaf-config.lua runs, and a database loaded by a last trigger
# was still empty then — every garrison came out without its air defence.
# ---------------------------------------------------------------------------

_LOAD_DATA = {"predicate": "a_do_script_file", "file": _MAP_KEY}
_LOAD_DATA_CALL = f'a_do_script_file(getValueResourceByKey("{_MAP_KEY}"));'


def _mission_with_framework_triggers() -> DcsMission:
    """The VEAF load triggers as the builder writes them: dynamic framework 3, static 4, config 6."""
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "trigrules": {
                3: {
                    "comment": "VEAF scripts loading - dynamic",
                    "actions": {1: {"predicate": "a_do_script", "text": "load()"}},
                },
                4: {
                    "comment": "VEAF scripts loading - static",
                    "actions": {1: {"predicate": "a_do_script_file", "file": "VEAF_MapKey_ActionText_10004"}},
                },
                6: {
                    "comment": "Mission scripts loading - static",
                    "actions": {1: {"predicate": "a_do_script_file", "file": "VEAF_MapKey_ActionText_10005"}},
                },
            },
            "trig": {
                "actions": {3: 'a_do_script("load()");', 4: "scripts();", 6: "config();"},
                "conditions": {3: "return false", 4: "return true", 6: "return true"},
                "flag": {3: True, 4: True, 6: True},
                "funcStartup": {3: "...", 4: "...", 6: "..."},
            },
        },
        map_resource_content={},
    )


class TestSpawnDataLoadsWithTheFramework:
    def test_both_framework_triggers_load_it_last(self) -> None:
        mission = _mission_with_framework_triggers()
        inject_spawn_data(mission, "-- lua")
        rules = mission.mission_content["trigrules"]
        for index in (3, 4):
            actions = rules[index]["actions"]
            assert actions[max(actions)] == _LOAD_DATA
            assert mission.mission_content["trig"]["actions"][index].endswith(_LOAD_DATA_CALL)
        assert mission.mission_content["trig"]["actions"][4] == "scripts();" + _LOAD_DATA_CALL

    def test_no_trigger_of_its_own_and_the_mission_scripts_untouched(self) -> None:
        mission = _mission_with_framework_triggers()
        inject_spawn_data(mission, "-- lua")
        assert set(mission.mission_content["trigrules"]) == {3, 4, 6}
        assert mission.mission_content["trig"]["actions"][6] == "config();"

    def test_a_list_of_actions_is_extended_too(self) -> None:
        mission = _mission_with_framework_triggers()
        mission.mission_content["trigrules"][4]["actions"] = [{"predicate": "a_do_script", "text": "x"}]
        inject_spawn_data(mission, "-- lua")
        assert mission.mission_content["trigrules"][4]["actions"][-1] == _LOAD_DATA

    def test_injected_twice_it_loads_once(self) -> None:
        mission = _mission_with_framework_triggers()
        inject_spawn_data(mission, "-- lua")
        inject_spawn_data(mission, "-- lua")
        assert list(mission.mission_content["trigrules"][4]["actions"].values()).count(_LOAD_DATA) == 1
        assert mission.mission_content["trig"]["actions"][4].count(_LOAD_DATA_CALL) == 1

    def test_no_warning_when_it_loads_with_the_framework(self) -> None:
        with patch("spawn_data_injector.spawn_data_injector_worker.logger") as mock_logger:
            inject_spawn_data(_mission_with_framework_triggers(), "-- lua")
        mock_logger.warning.assert_not_called()

    def test_without_framework_triggers_it_warns_and_keeps_the_trailing_trigger(self) -> None:
        mission = _mission_with_triggers()
        with patch("spawn_data_injector.spawn_data_injector_worker.logger") as mock_logger:
            inject_spawn_data(mission, "-- lua")
        mock_logger.warning.assert_called_once_with(t("pipeline.console.spawn_data_no_framework_trigger"))
        assert mission.mission_content["trigrules"][3]["comment"] == "VEAF spawn-data loading"


# ---------------------------------------------------------------------------
# merge_spawn_data
# ---------------------------------------------------------------------------


class TestMergeSpawnData:
    def test_none_mission_returns_framework_copy(self) -> None:
        fw = {"units": [{"aliases": ["a"], "unitType": "A"}], "groups": []}
        merged = merge_spawn_data(fw, None)
        assert merged["units"] == fw["units"]
        merged["units"].append({"aliases": ["z"]})
        assert len(fw["units"]) == 1  # original not mutated

    def test_new_alias_is_appended(self) -> None:
        fw = {"units": [{"aliases": ["a"], "unitType": "A"}], "groups": []}
        mission = {"units": [{"aliases": ["b"], "unitType": "B"}]}
        merged = merge_spawn_data(fw, mission)
        assert [u["unitType"] for u in merged["units"]] == ["A", "B"]

    def test_alias_collision_overrides(self) -> None:
        fw = {"units": [{"aliases": ["a"], "unitType": "A"}], "groups": []}
        mission = {"units": [{"aliases": ["A"], "unitType": "OVERRIDDEN"}]}  # case-insensitive
        merged = merge_spawn_data(fw, mission)
        assert len(merged["units"]) == 1
        assert merged["units"][0]["unitType"] == "OVERRIDDEN"

    def test_group_override_by_shared_alias(self) -> None:
        fw = {"units": [], "groups": [{"aliases": ["sa2", "sa-2"], "description": "orig"}]}
        mission = {"groups": [{"aliases": ["sa-2"], "description": "custom"}]}
        merged = merge_spawn_data(fw, mission)
        assert len(merged["groups"]) == 1
        assert merged["groups"][0]["description"] == "custom"


# ---------------------------------------------------------------------------
# Worker end-to-end
# ---------------------------------------------------------------------------


def _make_miz(tmp_path: Path) -> Path:
    miz = tmp_path / "m.miz"
    with zipfile.ZipFile(miz, "w") as zf:
        zf.writestr("mission", b'mission = {\n  ["name"] = "T",\n}\n')
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return miz


class TestWorkerEndToEnd:
    def test_embeds_resource_and_populates_tables(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)
        result = SpawnDataInjectorWorker(input_mission=miz, output_mission=miz).work()
        assert result.units == 21
        assert result.groups == 94

        with zipfile.ZipFile(miz) as zf:
            assert _RESOURCE_ARCNAME in zf.namelist()
            lua = zf.read(_RESOURCE_ARCNAME).decode("utf-8")
        assert "veafUnits.UnitsDatabase = {" in lua
        assert "veafUnits.GroupsDatabase = {" in lua
        assert '"shilka"' in lua

    def test_map_resource_and_trigger_present(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)
        SpawnDataInjectorWorker(input_mission=miz, output_mission=miz).work()
        mission = read_miz(miz)
        assert mission.map_resource_content[_MAP_KEY] == _RESOURCE_FILENAME
        actions = mission.mission_content["trig"]["actions"]
        assert any(_MAP_KEY in str(v) for v in actions.values())

    def test_per_mission_override(self, tmp_path: Path) -> None:
        miz = _make_miz(tmp_path)
        mission_yaml = tmp_path / "spawn-groups.yaml"
        mission_yaml.write_text("units:\n  - {aliases: [shilka], unitType: CUSTOM_SHILKA}\n", encoding="utf-8")
        SpawnDataInjectorWorker(input_mission=miz, output_mission=miz, mission_data_file=mission_yaml).work()
        with zipfile.ZipFile(miz) as zf:
            lua = zf.read(_RESOURCE_ARCNAME).decode("utf-8")
        assert "CUSTOM_SHILKA" in lua


# --------------------------------------------------------------------------------------------
# SECREV-2 / VMR-056 — `int(k) for k in trigrules` raised ValueError on the first non-numeric
# key, crashing on a mission we can otherwise handle. A key that is not an index cannot
# contribute to "the next index", so it is ignored rather than fatal.
# --------------------------------------------------------------------------------------------


def test_a_non_numeric_trigger_key_does_not_crash_the_index_search() -> None:
    from spawn_data_injector.spawn_data_injector_worker import _next_trigger_index

    content = {
        "trigrules": {"1": {}, "2": {}, "somethingElse": {}},
        "trig": {"func": {"1": "x", "notAnIndex": "y"}},
    }

    assert _next_trigger_index(content) == 3


def test_the_next_index_is_still_one_past_the_maximum() -> None:
    from spawn_data_injector.spawn_data_injector_worker import _next_trigger_index

    assert _next_trigger_index({"trigrules": {"4": {}, "7": {}}}) == 8


def test_an_empty_mission_starts_at_one() -> None:
    from spawn_data_injector.spawn_data_injector_worker import _next_trigger_index

    assert _next_trigger_index({}) == 1


def test_only_non_numeric_keys_still_starts_at_one() -> None:
    # The degenerate case: ignoring them all must not leave max() on an empty list.
    from spawn_data_injector.spawn_data_injector_worker import _next_trigger_index

    assert _next_trigger_index({"trigrules": {"a": {}, "b": {}}}) == 1
