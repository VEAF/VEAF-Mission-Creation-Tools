"""`edit_route` — the route surgery, and the invariant DCS enforces on it.

Ticket 04 of `FEAT-MCP-MUTATION-ACTIONS`, the largest of the three the exploration note named:
dcs-sms spends 27 verbs here, more than on units, which is a signal about where mission-editing
effort actually goes.

**The invariant that makes this surgery and not a list operation**: `FIX-WAYPOINTS-ETA-LOCKED`
established that DCS *refuses to save* a mission whose route has no waypoint with a locked time —
*"Route has no waypoints with locked time!"* — and that the fix is to lock the first, as DCS itself
does. So removing or reordering waypoints can produce a mission the editor rejects, long after and
far from here. Every operation restores the invariant, and the tests below check it on each one.

**Units.** The mission table stores metres and metres per second; a mission maker says feet and
knots. Following `set_unit_properties`' `heading_deg`, the parameters are named `altitude_ft` and
`speed_kt` so the unit is impossible to mistake, and the conversions have tests pinning their
direction rather than their existence.

**Tasks are a named set, not a free-form table.** Each signature here was read out of a real
mission, and two of them are traps a generic writer would fall into:

- **`SetFrequency` takes HERTZ** (`31000000` for 31 MHz) while a *group's* frequency — ticket 03 —
  is in MHz. Two units for the same notion in one file.
- **`EngageTargetsInZone` duplicates its own target list** into a serialised `value` string
  (`"Air;Cruise missiles;"`) beside the `targetTypes` array. Writing the array alone leaves the two
  disagreeing, so both are written from one source.
- **`Land` is a point on the ground plus a duration**, not an airfield reference.
"""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.edit_route import edit_route

_MISSION_LUA = b"""
mission = {
  ["coalition"] = {
    ["blue"] = {
      ["country"] = {
        [1] = {
          ["name"] = "USA",
          ["plane"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Colt 1-1",
                ["groupId"] = 10,
                ["x"] = -300000.0,
                ["y"] = 600000.0,
                ["units"] = {
                  [1] = {
                    ["name"] = "Colt 1-1-1",
                    ["type"] = "FA-18C_hornet",
                    ["x"] = -300000.0,
                    ["y"] = 600000.0,
                  },
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {
                      ["name"] = "Takeoff",
                      ["type"] = "TakeOffParking",
                      ["action"] = "From Parking Area",
                      ["x"] = -300000.0,
                      ["y"] = 600000.0,
                      ["alt"] = 43,
                      ["speed"] = 138.88888888889,
                      ["ETA"] = 0,
                      ["ETA_locked"] = true,
                      ["speed_locked"] = true,
                    },
                    [2] = {
                      ["name"] = "Push",
                      ["type"] = "Turning Point",
                      ["action"] = "Turning Point",
                      ["x"] = -290000.0,
                      ["y"] = 610000.0,
                      ["alt"] = 6096,
                      ["speed"] = 220.0,
                      ["ETA_locked"] = false,
                      ["speed_locked"] = true,
                    },
                    [3] = {
                      ["name"] = "Target",
                      ["type"] = "Turning Point",
                      ["action"] = "Turning Point",
                      ["x"] = -280000.0,
                      ["y"] = 620000.0,
                      ["alt"] = 6096,
                      ["speed"] = 220.0,
                      ["ETA_locked"] = false,
                      ["speed_locked"] = true,
                    },
                  },
                },
              },
            },
          },
          ["vehicle"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Static Convoy",
                ["groupId"] = 20,
                ["x"] = -320000.0,
                ["y"] = 620000.0,
                ["units"] = {
                  [1] = {
                    ["name"] = "Convoy-1",
                    ["type"] = "M-1 Abrams",
                    ["x"] = -320000.0,
                    ["y"] = 620000.0,
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
    """A `.miz` with a three-waypoint route whose first point is the only locked one."""
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _values(container: object) -> list:
    """Return a DCS table's entries whether it came back as a 1-based dict or a list."""
    if isinstance(container, dict):
        return list(container.values())
    return list(container) if isinstance(container, list) else []


def _points(miz_path: Path, group_name: str = "Colt 1-1") -> list[dict]:
    """Return the group's waypoints as written to disk."""
    content = read_miz(miz_path).mission_content
    assert content is not None
    for coalition in _values(content.get("coalition")):
        for country in _values(coalition.get("country")):
            for category in ("plane", "helicopter", "vehicle", "ship"):
                for group in _values((country.get(category) or {}).get("group")):
                    if group.get("name") == group_name:
                        return _values((group.get("route") or {}).get("points"))
    raise AssertionError(f"group not found: {group_name}")


def _tasks(point: dict) -> list[dict]:
    """Return a waypoint's task entries."""
    return _values(((point.get("task") or {}).get("params") or {}).get("tasks"))


class TestRouteOperations:
    """Add, insert, remove and reorder — mostly a list operation on `route.points`."""

    def test_add_appends_at_the_end(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -270000.0, "y": 630000.0})
        assert len(_points(miz)) == 4

    def test_add_keeps_the_coordinates_it_was_given(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -270000.0, "y": 630000.0})
        assert (_points(miz)[-1]["x"], _points(miz)[-1]["y"]) == (-270000.0, 630000.0)

    def test_insert_puts_the_waypoint_at_the_index_asked_for(self, miz: Path) -> None:
        """1-based, because that is how a mission maker counts and how describe_units reports."""
        edit_route(miz, group_name="Colt 1-1", operation="insert", index=2, position={"x": -295000.0, "y": 605000.0})
        assert (_points(miz)[1]["x"], _points(miz)[1]["y"]) == (-295000.0, 605000.0)

    def test_insert_pushes_the_others_down(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="insert", index=2, position={"x": -295000.0, "y": 605000.0})
        assert [point["name"] for point in _points(miz)] == [
            "Takeoff",
            "WP2",
            "Push",
            "Target",
        ]

    def test_remove_takes_out_the_index_asked_for(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="remove", index=2)
        assert [point["name"] for point in _points(miz)] == ["Takeoff", "Target"]

    def test_reorder_moves_a_waypoint_to_a_new_index(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="reorder", index=3, to_index=2)
        assert [point["name"] for point in _points(miz)] == ["Takeoff", "Target", "Push"]

    def test_an_index_out_of_range_is_refused_naming_the_range(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="1..3"):
            edit_route(miz, group_name="Colt 1-1", operation="remove", index=9)

    def test_removing_the_last_waypoint_is_refused(self, miz: Path) -> None:
        """A route with no waypoints is not a route, and DCS will not fly it."""
        edit_route(miz, group_name="Colt 1-1", operation="remove", index=3)
        edit_route(miz, group_name="Colt 1-1", operation="remove", index=2)
        with pytest.raises(ValueError, match="last waypoint"):
            edit_route(miz, group_name="Colt 1-1", operation="remove", index=1)

    def test_add_without_a_position_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="position"):
            edit_route(miz, group_name="Colt 1-1", operation="add")

    def test_an_unknown_operation_is_refused_naming_the_set(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="reorder"):
            edit_route(miz, group_name="Colt 1-1", operation="teleport", index=1)


class TestTheEtaLockInvariant:
    """DCS refuses to save a route with no locked-time waypoint. Every operation restores that."""

    def test_removing_the_only_locked_waypoint_relocks_the_first(self, miz: Path) -> None:
        """The first point is the only locked one, so removing it would leave none.

        `FIX-WAYPOINTS-ETA-LOCKED`: the editor then refuses to save the mission, with an error
        naming the route and not the edit that broke it.
        """
        edit_route(miz, group_name="Colt 1-1", operation="remove", index=1)
        assert _points(miz)[0]["ETA_locked"] is True

    def test_the_result_says_it_relocked_a_waypoint(self, miz: Path) -> None:
        result = edit_route(miz, group_name="Colt 1-1", operation="remove", index=1)
        assert any("locked" in warning for warning in result["warnings"])

    def test_an_already_locked_route_is_left_alone(self, miz: Path) -> None:
        """No gratuitous rewriting: the invariant holds, so nothing is touched."""
        result = edit_route(miz, group_name="Colt 1-1", operation="remove", index=3)
        assert not any("locked" in warning for warning in result["warnings"])

    def test_a_lock_on_a_later_waypoint_counts(self, miz: Path) -> None:
        """The invariant is "at least one", not "the first" — an authored lock must survive."""
        edit_route(miz, group_name="Colt 1-1", operation="set", index=3, eta_locked=True)
        edit_route(miz, group_name="Colt 1-1", operation="remove", index=1)
        assert [bool(point.get("ETA_locked")) for point in _points(miz)] == [False, True]


class TestWaypointFields:
    """Feet and knots in, metres and m/s out — with the direction pinned."""

    def test_twenty_thousand_feet_is_stored_in_metres(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="set", index=2, altitude_ft=20000)
        assert _points(miz)[1]["alt"] == pytest.approx(6096.0)

    def test_three_hundred_knots_is_stored_in_metres_per_second(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="set", index=2, speed_kt=300)
        assert _points(miz)[1]["speed"] == pytest.approx(154.3333, abs=0.01)

    def test_the_result_reports_both_units(self, miz: Path) -> None:
        """An agent telling the mission maker "now at 20 000 ft" must not have to convert back."""
        result = edit_route(miz, group_name="Colt 1-1", operation="set", index=2, altitude_ft=20000)
        assert result["changed"]["altitude"]["to_ft"] == pytest.approx(20000)

    def test_a_waypoint_can_be_renamed(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="set", index=2, name="IP")
        assert _points(miz)[1]["name"] == "IP"

    def test_the_waypoint_type_carries_its_action_with_it(self, miz: Path) -> None:
        """`type` and `action` are a pair in every real mission; setting one alone is a broken point."""
        edit_route(miz, group_name="Colt 1-1", operation="set", index=2, waypoint_type="Land")
        assert (_points(miz)[1]["type"], _points(miz)[1]["action"]) == ("Land", "Landing")

    def test_an_unknown_waypoint_type_is_refused_naming_the_known_ones(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Turning Point"):
            edit_route(miz, group_name="Colt 1-1", operation="set", index=2, waypoint_type="Hover")

    def test_a_new_waypoint_inherits_the_previous_altitude_and_speed(self, miz: Path) -> None:
        """Otherwise an added waypoint sits at altitude 0 and the flight dives into the ground."""
        edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -270000.0, "y": 630000.0})
        assert (_points(miz)[-1]["alt"], _points(miz)[-1]["speed"]) == (
            _points(miz)[-2]["alt"],
            _points(miz)[-2]["speed"],
        )

    def test_an_added_waypoint_is_a_turning_point_by_default(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -270000.0, "y": 630000.0})
        assert (_points(miz)[-1]["type"], _points(miz)[-1]["action"]) == ("Turning Point", "Turning Point")

    def test_add_honours_the_altitude_and_speed_it_is_given(self, miz: Path) -> None:
        # Regression: `add` used to accept altitude_ft/speed_kt and silently drop them, inheriting the
        # neighbour's — wrong in a plausible way, since the value looks reasonable.
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add",
            position={"x": -270000.0, "y": 630000.0},
            altitude_ft=18000,
            speed_kt=350,
        )
        wp = _points(miz)[-1]
        assert wp["alt"] == pytest.approx(5486.4)  # 18000 ft
        assert wp["speed"] == pytest.approx(180.0554)  # 350 kt

    def test_insert_honours_the_altitude_and_speed_it_is_given(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="insert",
            index=2,
            position={"x": -270000.0, "y": 630000.0},
            altitude_ft=12000,
        )
        assert _points(miz)[1]["alt"] == pytest.approx(3657.6)  # 12000 ft

    def test_add_without_altitude_still_inherits(self, miz: Path) -> None:
        # The inheritance default must survive the fix — omitting the params still copies the neighbour.
        edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -270000.0, "y": 630000.0})
        assert (_points(miz)[-1]["alt"], _points(miz)[-1]["speed"]) == (
            _points(miz)[-2]["alt"],
            _points(miz)[-2]["speed"],
        )


class TestWaypointTasks:
    """A named set with validated signatures, each shape read out of a real mission."""

    def test_orbit_is_written_with_its_pattern(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="orbit",
            task_params={"pattern": "Race-Track", "altitude_ft": 20000, "speed_kt": 300},
        )
        task = _tasks(_points(miz)[1])[0]
        assert (task["id"], task["params"]["pattern"]) == ("Orbit", "Race-Track")

    def test_orbit_converts_its_altitude_to_metres(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="orbit",
            task_params={"pattern": "Circle", "altitude_ft": 20000, "speed_kt": 300},
        )
        assert _tasks(_points(miz)[1])[0]["params"]["altitude"] == pytest.approx(6096.0)

    def test_an_unknown_orbit_pattern_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Race-Track"):
            edit_route(
                miz,
                group_name="Colt 1-1",
                operation="add_task",
                index=2,
                task="orbit",
                task_params={"pattern": "Figure-Eight"},
            )

    def test_set_frequency_converts_megahertz_to_hertz(self, miz: Path) -> None:
        """The trap: a *group's* frequency is MHz, this one is Hz — 31 MHz is written 31000000."""
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="set_frequency",
            task_params={"frequency_mhz": 31, "modulation": "FM"},
        )
        action = _tasks(_points(miz)[1])[0]["params"]["action"]
        assert action["params"]["frequency"] == 31000000

    def test_set_frequency_is_wrapped_as_an_action(self, miz: Path) -> None:
        """DCS carries it inside a `WrappedAction`, not as a task of its own."""
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="set_frequency",
            task_params={"frequency_mhz": 251},
        )
        task = _tasks(_points(miz)[1])[0]
        assert (task["id"], task["params"]["action"]["id"]) == ("WrappedAction", "SetFrequency")

    def test_engage_targets_in_zone_keeps_its_two_target_lists_in_step(self, miz: Path) -> None:
        """DCS duplicates the list into a serialised `value` string; writing one alone desyncs them."""
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="engage_targets_in_zone",
            task_params={"position": {"x": -280000.0, "y": 620000.0}, "radius_m": 60000, "target_types": ["Air"]},
        )
        params = _tasks(_points(miz)[1])[0]["params"]
        assert (params["targetTypes"], params["value"]) == (["Air"], "Air;")

    def test_land_is_a_point_and_a_duration(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="land",
            task_params={"position": {"x": -279000.0, "y": 619000.0}, "duration_s": 300},
        )
        params = _tasks(_points(miz)[2])[0]["params"]
        assert (params["x"], params["duration"]) == (-279000.0, 300)

    def test_attack_group_targets_a_group_id(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="attack_group",
            task_params={"group_id": 18},
        )
        assert _tasks(_points(miz)[1])[0]["params"]["groupId"] == 18

    def test_switch_waypoint_loops_the_route(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="switch_waypoint",
            task_params={"to_index": 2},
        )
        action = _tasks(_points(miz)[2])[0]["params"]["action"]
        assert (action["id"], action["params"]["goToWaypointIndex"]) == ("SwitchWaypoint", 2)

    def test_bombing_takes_a_ground_point(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="bombing",
            task_params={"position": {"x": -281000.0, "y": 621000.0}, "expend": "All"},
        )
        assert _tasks(_points(miz)[2])[0]["params"]["expend"] == "All"

    def test_bombing_carries_the_full_field_set_the_editor_keeps(self, miz: Path) -> None:
        # Written without these, the editor discarded the task on save (measured 2026-08-15). The set
        # is what a real Bombing carries; weaponType defaults to the editor's measured Auto value.
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="bombing",
            task_params={"position": {"x": -281000.0, "y": 621000.0}},
        )
        params = _tasks(_points(miz)[2])[0]["params"]
        assert params["weaponType"] == 2032
        assert params["altitudeEnabled"] is False and params["altitude"] == 0.0
        assert params["directionEnabled"] is False and params["direction"] == 0.0
        assert set(params) >= {"x", "y", "expend", "attackQty", "attackQtyLimit", "groupAttack"}

    def test_attack_group_carries_the_full_field_set(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="attack_group",
            task_params={"group_id": 18},
        )
        params = _tasks(_points(miz)[1])[0]["params"]
        assert params["groupId"] == 18
        assert params["weaponType"] == 9659482112  # the measured AttackGroup Auto value
        assert {"expend", "attackQty", "attackQtyLimit", "groupAttack", "altitudeEnabled", "directionEnabled"} <= set(
            params
        )

    def test_attack_altitude_and_direction_turn_their_flags_on(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="bombing",
            task_params={"position": {"x": -281000.0, "y": 621000.0}, "altitude_ft": 10000, "direction_deg": 90},
        )
        params = _tasks(_points(miz)[2])[0]["params"]
        assert params["altitudeEnabled"] is True and params["altitude"] == pytest.approx(3048.0)
        assert params["directionEnabled"] is True and params["direction"] == pytest.approx(1.5707963)

    def test_a_caller_can_override_the_weapon_type(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=3,
            task="bombing",
            task_params={"position": {"x": -281000.0, "y": 621000.0}, "weapon_type": 2147485694},
        )
        assert _tasks(_points(miz)[2])[0]["params"]["weaponType"] == 2147485694

    def test_engage_targets_in_zone_carries_a_no_target_list(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="engage_targets_in_zone",
            task_params={"position": {"x": -281000.0, "y": 621000.0}, "radius_m": 30000, "target_types": ["Air"]},
        )
        params = _tasks(_points(miz)[1])[0]["params"]
        assert params["targetTypes"] == ["Air"]
        assert params["value"] == "Air;"
        # The key is present and empty (nothing excluded) — an empty Lua table round-trips as `{}`.
        assert "noTargetTypes" in params and not params["noTargetTypes"]

    def test_an_unknown_task_is_refused_naming_the_set(self, miz: Path) -> None:
        """The escape hatch starts closed: a plausible task table DCS ignores is a silent failure."""
        with pytest.raises(ValueError, match="orbit"):
            edit_route(miz, group_name="Colt 1-1", operation="add_task", index=2, task="carpet_bomb")

    def test_a_missing_required_task_parameter_is_refused_by_name(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="group_id"):
            edit_route(miz, group_name="Colt 1-1", operation="add_task", index=2, task="attack_group")

    def test_tasks_are_numbered_in_order(self, miz: Path) -> None:
        """DCS reads `number`; two tasks sharing one is a route the editor renumbers unpredictably."""
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="attack_group",
            task_params={"group_id": 18},
        )
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="switch_waypoint",
            task_params={"to_index": 1},
        )
        assert [task["number"] for task in _tasks(_points(miz)[1])] == [1, 2]

    def test_a_task_is_authored_not_auto(self, miz: Path) -> None:
        """`auto = true` marks the editor's own options; ours must not pretend to be one."""
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="attack_group",
            task_params={"group_id": 18},
        )
        assert _tasks(_points(miz)[1])[0]["auto"] is False

    def test_clear_tasks_empties_the_waypoint(self, miz: Path) -> None:
        edit_route(
            miz,
            group_name="Colt 1-1",
            operation="add_task",
            index=2,
            task="attack_group",
            task_params={"group_id": 18},
        )
        edit_route(miz, group_name="Colt 1-1", operation="clear_tasks", index=2)
        assert _tasks(_points(miz)[1]) == []


class TestResultAndBackup:
    """The route comes back, so an agent can see what it just edited."""

    def test_the_result_carries_the_resulting_route(self, miz: Path) -> None:
        result = edit_route(miz, group_name="Colt 1-1", operation="add", position={"x": -1.0, "y": 2.0})
        assert len(result["route"]) == 4

    def test_the_route_entries_report_feet_and_knots(self, miz: Path) -> None:
        result = edit_route(miz, group_name="Colt 1-1", operation="set", index=2, altitude_ft=15000)
        assert result["route"][1]["altitude_ft"] == pytest.approx(15000, abs=1)

    def test_a_group_without_a_route_is_refused_clearly(self, miz: Path) -> None:
        """A ground group that was never given waypoints: say so, rather than raising on an index."""
        with pytest.raises(ValueError, match="no route"):
            edit_route(miz, group_name="Static Convoy", operation="remove", index=1)

    def test_a_backup_is_taken_before_the_write(self, miz: Path) -> None:
        edit_route(miz, group_name="Colt 1-1", operation="set", index=2, altitude_ft=15000)
        assert len([path for path in miz.parent.glob("*.miz") if path != miz]) == 1

    def test_a_refused_edit_leaves_the_mission_untouched(self, miz: Path) -> None:
        before = miz.read_bytes()
        with pytest.raises(ValueError):
            edit_route(miz, group_name="Colt 1-1", operation="remove", index=99)
        assert miz.read_bytes() == before

    def test_an_unknown_group_names_what_exists(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="Colt 1-1"):
            edit_route(miz, group_name="Nope", operation="remove", index=1)
