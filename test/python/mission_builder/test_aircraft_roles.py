"""What a QRA or an air wave will do with each editor aircraft group it deploys (FEAT-AIRCRAFT-ROLES).

The runtime rule lives in `veafAircraftSpawn.lua`; the build mirrors it to tell the mission maker, before
he flies, which of his routes will be flown as written and which will be replaced. The last suite reads
the Lua tables and compares them with the Python ones, so the two cannot drift.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any
from unittest.mock import patch

from mission_builder.aircraft_roles import (
    AIR_TARGET_TYPES,
    ENGAGE_TASK_IDS,
    ROUTE_ENGAGES_AIR,
    ROUTE_REPLACED,
    ROUTE_ZONE_DEFENSE,
    ZONE_DEFENSE_TASKS,
    classify_deployed_group,
    find_deployed_aircraft_routes,
    is_empty_route,
    route_engages_air,
)

LUA_MODULE = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf" / "veafAircraftSpawn.lua"


def _combo(*tasks: dict[str, Any]) -> dict[str, Any]:
    return {"id": "ComboTask", "params": {"tasks": list(tasks)}}


def _engage(target_types: list[str], task_id: str = "EngageTargets", enabled: bool = True) -> dict[str, Any]:
    return {"id": task_id, "enabled": enabled, "auto": True, "params": {"targetTypes": target_types, "priority": 0}}


def _option() -> dict[str, Any]:
    return {
        "id": "WrappedAction",
        "enabled": True,
        "params": {"action": {"id": "Option", "params": {"name": 0, "value": 2}}},
    }


def _point(task: dict[str, Any] | None = None, wp_type: str = "Turning Point") -> dict[str, Any]:
    return {"type": wp_type, "x": 0, "y": 0, "alt": 5000, "task": task if task is not None else _combo()}


def _group(name: str, task: str, points: list[dict[str, Any]]) -> dict[str, Any]:
    return {"name": name, "task": task, "route": {"points": points}}


class TestRouteEngagesAir:
    def test_no_route_engages_nothing(self) -> None:
        assert route_engages_air([]) is False

    def test_the_create_qra_single_point_engages_nothing(self) -> None:
        assert route_engages_air([_point()]) is False

    def test_the_editor_cap_auto_task_engages_air(self) -> None:
        assert route_engages_air([_point(_combo(_engage(["Air"]), _option()))]) is True

    def test_an_engagement_in_zone_on_the_second_point_engages_air(self) -> None:
        points = [_point(_combo(_option())), _point(_combo(_engage(["Air"], "EngageTargetsInZone")))]
        assert route_engages_air(points) is True

    def test_a_task_outside_a_combo_task_is_read_too(self) -> None:
        assert route_engages_air([_point(_engage(["Fighters"]))]) is True

    def test_a_disabled_engagement_does_not_count(self) -> None:
        assert route_engages_air([_point(_combo(_engage(["Air"], enabled=False)))]) is False

    def test_ground_targets_are_no_air_engagement(self) -> None:
        assert route_engages_air([_point(_combo(_engage(["Ground Units"])))]) is False

    def test_a_lua_table_arriving_as_a_dict_is_read(self) -> None:
        # the parser keeps a 1-based table as a dict when its keys are not contiguous
        points = {1: _point({"id": "ComboTask", "params": {"tasks": {1: _engage(["Air"])}}})}
        assert route_engages_air(points) is True


class TestIsEmptyRoute:
    def test_a_single_point_with_options_only_is_empty(self) -> None:
        assert is_empty_route([_point(_combo(_option()))]) is True

    def test_a_single_take_off_point_is_empty(self) -> None:
        assert is_empty_route([_point(wp_type="TakeOffParking")]) is True

    def test_two_points_are_a_route(self) -> None:
        assert is_empty_route([_point(), _point()]) is False

    def test_a_single_point_with_a_real_task_is_a_route(self) -> None:
        assert is_empty_route([_point(_combo({"id": "Orbit", "params": {"pattern": "Circle"}}))]) is False


class TestClassifyDeployedGroup:
    def test_an_empty_interceptor_is_given_zone_defense(self) -> None:
        # the Sayqal QRA of *Ligne rouge d'At Tanf*: the group this lot was opened for, and the build
        # has to say what the script will make of it
        assert classify_deployed_group(_group("QRA", "Intercept", [_point()])) == ROUTE_ZONE_DEFENSE

    def test_a_written_cap_route_without_engagement_is_replaced(self) -> None:
        assert classify_deployed_group(_group("Wave", "CAP", [_point(), _point()])) == ROUTE_REPLACED

    def test_an_interceptor_that_engages_air_is_flown_as_written(self) -> None:
        assert (
            classify_deployed_group(_group("QRA", "Intercept", [_point(_combo(_engage(["Air"])))])) == ROUTE_ENGAGES_AIR
        )

    def test_any_other_task_says_nothing(self) -> None:
        for task in ("Ground Attack", "CAS", "Fighter Sweep", "Escort", "Nothing"):
            assert classify_deployed_group(_group("Wave", task, [_point(), _point()])) is None, task


def _mission(groups: list[dict[str, Any]], category: str = "plane") -> dict[str, Any]:
    return {"coalition": {"red": {"country": [{"name": "Russia", category: {"group": groups}}]}}}


class TestFindDeployedAircraftRoutes:
    def test_qra_and_wave_groups_are_classified(self) -> None:
        mission = _mission(
            [
                _group("QRA-written", "Intercept", [_point(), _point()]),
                _group("Wave-engages", "CAP", [_point(_combo(_engage(["Air"])))]),
                _group("QRA-empty", "Intercept", [_point()]),
            ]
        )
        yaml_data = {
            "modules": {
                "QRA": {"definitions": [{"simple_groups": ["QRA-written", "QRA-empty", "-cap mig29"]}]},
                "AIRWAVES": {"airwave_zones": [{"waves": [{"groups": ["Wave-engages"]}]}]},
            }
        }
        assert find_deployed_aircraft_routes(yaml_data, mission) == [
            ("QRA", "QRA-written", ROUTE_REPLACED),
            ("QRA", "QRA-empty", ROUTE_ZONE_DEFENSE),
            ("AIRWAVES", "Wave-engages", ROUTE_ENGAGES_AIR),
        ]

    def test_a_ground_group_is_not_concerned(self) -> None:
        mission = _mission([_group("QRA-tanks", "CAP", [_point(), _point()])], category="vehicle")
        yaml_data = {"modules": {"QRA": {"definitions": [{"simple_groups": ["QRA-tanks"]}]}}}
        assert find_deployed_aircraft_routes(yaml_data, mission) == []

    def test_a_group_deployed_twice_is_reported_once(self) -> None:
        mission = _mission([_group("QRA-written", "CAP", [_point(), _point()])])
        qra = {"simple_groups": ["QRA-written"], "groups_by_enemy_count": [{"groups": ["QRA-written"]}]}
        yaml_data = {"modules": {"QRA": {"definitions": [qra]}}}
        assert find_deployed_aircraft_routes(yaml_data, mission) == [("QRA", "QRA-written", ROUTE_REPLACED)]


class _FakeMission:
    def __init__(self, content: dict[str, Any]) -> None:
        self.mission_content = content


_WIRED_MISSION = _mission(
    [
        _group("QRA-written", "Intercept", [_point(), _point()]),
        _group("QRA-engages", "Intercept", [_point(_combo(_engage(["Air"])))]),
        _group("QRA-empty", "Intercept", [_point()]),
    ]
)
_WIRED_YAML = {"modules": {"QRA": {"definitions": [{"simple_groups": ["QRA-written", "QRA-engages", "QRA-empty"]}]}}}


class TestTheBuildAndValidateSayIt:
    def test_the_build_warns_on_a_replaced_route_and_informs_on_an_engaging_one(self) -> None:
        from mission_builder_factory import make_worker

        worker = make_worker(mission_yaml=_WIRED_YAML, dcs_mission=_FakeMission(_WIRED_MISSION))
        with patch("mission_builder.mission_builder_worker.logger") as logger:
            worker.report_deployed_aircraft_routes()
        warnings = [str(c.args[0]) for c in logger.warning.call_args_list]
        infos = [str(c.args[0]) for c in logger.info.call_args_list]
        assert len(warnings) == 1 and "QRA-written" in warnings[0]
        assert len(infos) == 2 and "QRA-engages" in infos[0] and "QRA-empty" in infos[1]
        assert "zone_defense" in infos[1]

    def test_validate_warns_on_a_replaced_route_only(self) -> None:
        from veaf_libs.mission_validator import WARNING, _check_deployed_aircraft_routes

        issues = _check_deployed_aircraft_routes(_WIRED_YAML, _WIRED_MISSION)
        assert [i.level for i in issues] == [WARNING]
        assert "QRA-written" in issues[0].message


def _lua_table(name: str) -> set[str]:
    """The string keys or values of `veafAircraftSpawn.<name> = { … }`, read from the Lua source."""
    source = LUA_MODULE.read_text(encoding="utf-8")
    # a table written on one line, else one closed by a `}` at the start of a line
    match = re.search(rf"^veafAircraftSpawn\.{name} = \{{([^\n]*)\}}$", source, re.M) or re.search(
        rf"^veafAircraftSpawn\.{name} = \{{\n(.*?)^\}}", source, re.M | re.S
    )
    assert match, f"veafAircraftSpawn.{name} not found in {LUA_MODULE.name}"
    body = match.group(1)
    # `"Air",` in a list, `CAP = true` in a set
    return set(re.findall(r'"([^"]+)"', body)) | set(re.findall(r"\b(\w+)\s*=\s*true", body))


class TestTheBuildMirrorsTheRuntime:
    def test_air_target_types(self) -> None:
        assert set(AIR_TARGET_TYPES) == _lua_table("AIR_TARGET_TYPES")

    def test_engagement_task_ids(self) -> None:
        assert set(ENGAGE_TASK_IDS) == _lua_table("ENGAGE_TASK_IDS")

    def test_zone_defense_tasks(self) -> None:
        assert set(ZONE_DEFENSE_TASKS) == _lua_table("ZONE_DEFENSE_TASKS")
