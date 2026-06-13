"""Tests for the spawn-data injector worker (SPAWN-EXTERNALIZE-003/004)."""

from __future__ import annotations

import zipfile
from pathlib import Path

from mission_tools.miz_tools import DcsMission, read_miz

from spawn_data_injector import SpawnDataInjectorWorker, inject_spawn_data, merge_spawn_data
from spawn_data_injector.spawn_data_injector_worker import _MAP_KEY, _RESOURCE_FILENAME

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
        assert result.units == 13
        assert result.groups == 78

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
        mission_yaml.write_text(
            "units:\n  - {aliases: [shilka], unitType: CUSTOM_SHILKA}\n", encoding="utf-8"
        )
        SpawnDataInjectorWorker(
            input_mission=miz, output_mission=miz, mission_data_file=mission_yaml
        ).work()
        with zipfile.ZipFile(miz) as zf:
            lua = zf.read(_RESOURCE_ARCNAME).decode("utf-8")
        assert "CUSTOM_SHILKA" in lua
