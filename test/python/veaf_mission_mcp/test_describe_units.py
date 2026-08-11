"""`describe_units` — the read the mutation actions are blind without.

`describe_mission` returns groups (name, coalition, country, category) and zones. That is all: no
units, no loadout, no skill, no livery, no route, no waypoint, no task. So "give Colt flight an
air-to-ground loadout" and "add a waypoint after the third" cannot be attempted without guessing,
and a mission mutated on a guess opens in the editor and flies wrong (`FEAT-MCP-MUTATION-ACTIONS`
ticket 05, from the triage in its PRD).

**Every shape asserted here was read out of a real mission** (Foothold Caucasus 4.4.1, 357 armed
units), not assumed. The one that matters most: `payload.pylons` is indexed **by pylon number**, and
those numbers are **not contiguous** — a real FA-18C carries pylons 1, 4, 5, 6 and 9. In that
mission 170 of 357 units have a gapped layout and 187 happen to be contiguous, so a reader that
treats pylons as an ordered list is right half the time and silently wrong the rest, which is how a
future setter would hang a weapon on the wrong station.
"""

import zipfile
from pathlib import Path

import pytest
from veaf_mission_mcp.describe_units import describe_units

#: A mission holding what the mutation tickets have to be able to read: a two-ship with gapped
#: pylons, a route with a real task among the editor's auto options, a late-activated group, and a
#: ground group with neither loadout nor route.
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
                ["task"] = "CAS",
                ["frequency"] = 251,
                ["modulation"] = 0,
                ["uncontrolled"] = true,
                ["hidden"] = false,
                ["hiddenOnMFD"] = true,
                ["start_time"] = 120,
                ["x"] = 1000.5,
                ["y"] = 2000.5,
                ["units"] = {
                  [1] = {
                    ["name"] = "Colt 1-1-1",
                    ["type"] = "FA-18C_hornet",
                    ["skill"] = "High",
                    ["livery_id"] = "vfa-106 (grey)",
                    ["onboard_num"] = "101",
                    ["heading"] = 1.57,
                    ["alt"] = 6096,
                    ["alt_type"] = "BARO",
                    ["speed"] = 220.0,
                    ["parking"] = "12",
                    ["x"] = 1000.5,
                    ["y"] = 2000.5,
                    ["callsign"] = { [1] = 1, [2] = 1, [3] = 1, ["name"] = "Enfield11" },
                    ["payload"] = {
                      ["fuel"] = 4900,
                      ["chaff"] = 60,
                      ["flare"] = 30,
                      ["gun"] = 100,
                      ["pylons"] = {
                        [1] = { ["CLSID"] = "{AIM-9M}" },
                        [4] = { ["CLSID"] = "{GBU-12}" },
                        [5] = { ["CLSID"] = "{FPU_8A_FUEL_TANK}" },
                        [6] = { ["CLSID"] = "{GBU-12}" },
                        [9] = { ["CLSID"] = "{AIM-9M}" },
                      },
                    },
                  },
                  [2] = {
                    ["name"] = "Colt 1-1-2",
                    ["type"] = "FA-18C_hornet",
                    ["skill"] = "Average",
                    ["x"] = 1100.0,
                    ["y"] = 2100.0,
                  },
                },
                ["route"] = {
                  ["points"] = {
                    [1] = {
                      ["name"] = "Takeoff",
                      ["type"] = "TakeOffParking",
                      ["action"] = "From Parking Area",
                      ["airdromeId"] = 21,
                      ["alt"] = 15,
                      ["alt_type"] = "BARO",
                      ["speed"] = 0,
                      ["ETA"] = 0,
                      ["ETA_locked"] = true,
                      ["speed_locked"] = false,
                      ["x"] = 1000.5,
                      ["y"] = 2000.5,
                    },
                    [2] = {
                      ["name"] = "Target",
                      ["type"] = "Turning Point",
                      ["action"] = "Turning Point",
                      ["alt"] = 6096,
                      ["speed"] = 220.0,
                      ["x"] = 5000.0,
                      ["y"] = 6000.0,
                      ["task"] = {
                        ["id"] = "ComboTask",
                        ["params"] = {
                          ["tasks"] = {
                            [1] = {
                              ["number"] = 1,
                              ["id"] = "WrappedAction",
                              ["enabled"] = true,
                              ["auto"] = true,
                              ["params"] = {
                                ["action"] = { ["id"] = "Option", ["params"] = { ["name"] = 17, ["value"] = true } },
                              },
                            },
                            [2] = {
                              ["number"] = 2,
                              ["id"] = "Bombing",
                              ["enabled"] = true,
                              ["auto"] = false,
                              ["params"] = { ["x"] = 5100.0, ["y"] = 6100.0, ["attackQty"] = 2 },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
              [2] = {
                ["name"] = "Reserve Flight",
                ["groupId"] = 11,
                ["lateActivation"] = true,
                ["units"] = { [1] = { ["name"] = "Reserve-1", ["type"] = "F-16C_50" } },
              },
            },
          },
        },
      },
    },
    ["red"] = {
      ["country"] = {
        [1] = {
          ["name"] = "Russia",
          ["vehicle"] = {
            ["group"] = {
              [1] = {
                ["name"] = "Red Armor",
                ["groupId"] = 20,
                ["units"] = { [1] = { ["name"] = "Armor-1", ["type"] = "T-72B", ["skill"] = "Good" } },
              },
            },
          },
        },
      },
    },
  },
  ["triggers"] = { ["zones"] = {} },
}
"""


@pytest.fixture
def rich_miz(tmp_path: Path) -> Path:
    """A `.miz` carrying a loadout, a route with a real task, and a late-activated group."""
    miz_path = tmp_path / "rich.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return miz_path


def _group(result: dict, name: str) -> dict:
    return next(group for group in result["groups"] if group["name"] == name)


class TestPylonNumbersSurvive:
    """The finding that shaped this action, and the one a setter depends on."""

    def test_pylons_are_keyed_by_their_number(self, rich_miz: Path) -> None:
        unit = _group(describe_units(rich_miz), "Colt 1-1")["units"][0]
        assert unit["pylons"] == {
            1: "{AIM-9M}",
            4: "{GBU-12}",
            5: "{FPU_8A_FUEL_TANK}",
            6: "{GBU-12}",
            9: "{AIM-9M}",
        }

    def test_a_gap_is_a_gap_and_not_a_shifted_list(self, rich_miz: Path) -> None:
        # The whole point: station 2 and 3 are empty. A list would report the GBU on pylon 2.
        pylons = _group(describe_units(rich_miz), "Colt 1-1")["units"][0]["pylons"]
        assert 2 not in pylons
        assert 3 not in pylons
        assert pylons[4] == "{GBU-12}"

    def test_a_unit_with_no_payload_has_no_pylons(self, rich_miz: Path) -> None:
        assert _group(describe_units(rich_miz), "Colt 1-1")["units"][1]["pylons"] == {}


class TestUnitFields:
    """Everything ticket 02 wants to mutate has to be readable first."""

    def test_the_fields_a_setter_will_change_are_all_present(self, rich_miz: Path) -> None:
        unit = _group(describe_units(rich_miz), "Colt 1-1")["units"][0]
        assert unit["type"] == "FA-18C_hornet"
        assert unit["skill"] == "High"
        assert unit["livery"] == "vfa-106 (grey)"
        assert unit["onboard_num"] == "101"
        assert unit["heading"] == 1.57
        assert unit["alt"] == 6096
        assert unit["parking"] == "12"
        assert unit["fuel"] == 4900

    def test_the_callsign_is_reported_by_its_readable_name(self, rich_miz: Path) -> None:
        # DCS stores a callsign as a table of indices plus a name; the name is the part a mission
        # maker says out loud.
        assert _group(describe_units(rich_miz), "Colt 1-1")["units"][0]["callsign"] == "Enfield11"

    def test_defensive_counters_are_reported(self, rich_miz: Path) -> None:
        unit = _group(describe_units(rich_miz), "Colt 1-1")["units"][0]
        assert (unit["chaff"], unit["flare"], unit["gun"]) == (60, 30, 100)

    def test_a_ground_unit_reports_what_it_has(self, rich_miz: Path) -> None:
        unit = _group(describe_units(rich_miz), "Red Armor")["units"][0]
        assert unit["type"] == "T-72B"
        assert unit["skill"] == "Good"
        assert unit["pylons"] == {}


class TestGroupFields:
    """The group properties `describe_mission` does not report, which ticket 03 mutates."""

    def test_the_properties_a_setter_will_change_are_present(self, rich_miz: Path) -> None:
        group = _group(describe_units(rich_miz), "Colt 1-1")
        assert group["task"] == "CAS"
        assert group["frequency"] == 251
        assert group["uncontrolled"] is True
        assert group["hidden_on_mfd"] is True
        assert group["start_time"] == 120

    def test_late_activation_is_reported_when_set(self, rich_miz: Path) -> None:
        assert _group(describe_units(rich_miz), "Reserve Flight")["late_activation"] is True

    def test_late_activation_is_false_when_absent_not_missing(self, rich_miz: Path) -> None:
        # DCS omits the key when it is off, and an agent reading `None` cannot tell "off" from
        # "unknown". A boolean is what the question deserves.
        assert _group(describe_units(rich_miz), "Colt 1-1")["late_activation"] is False

    def test_the_identity_describe_mission_gives_is_still_there(self, rich_miz: Path) -> None:
        group = _group(describe_units(rich_miz), "Red Armor")
        assert (group["coalition"], group["country"], group["category"]) == ("red", "Russia", "vehicle")


class TestRoute:
    """Ticket 04 edits waypoints, so it has to see them."""

    def test_waypoints_come_back_in_order_with_their_index(self, rich_miz: Path) -> None:
        route = _group(describe_units(rich_miz), "Colt 1-1")["route"]
        assert [point["index"] for point in route] == [1, 2]
        assert [point["name"] for point in route] == ["Takeoff", "Target"]

    def test_a_waypoint_reports_what_a_setter_changes(self, rich_miz: Path) -> None:
        point = _group(describe_units(rich_miz), "Colt 1-1")["route"][0]
        assert point["type"] == "TakeOffParking"
        assert point["action"] == "From Parking Area"
        assert point["airdrome_id"] == 21
        assert point["eta_locked"] is True
        assert (point["x"], point["y"]) == (1000.5, 2000.5)

    def test_a_group_with_no_route_reports_an_empty_one(self, rich_miz: Path) -> None:
        assert _group(describe_units(rich_miz), "Red Armor")["route"] == []


class TestWaypointTasks:
    """A ComboTask is mostly the editor's own auto options; the mission maker's task is in there."""

    def test_a_real_task_is_reported_with_its_parameters(self, rich_miz: Path) -> None:
        tasks = _group(describe_units(rich_miz), "Colt 1-1")["route"][1]["tasks"]
        bombing = next(task for task in tasks if task["id"] == "Bombing")
        assert bombing["auto"] is False
        assert bombing["enabled"] is True
        assert bombing["params"] == {"x": 5100.0, "y": 6100.0, "attackQty": 2}

    def test_an_auto_option_is_reported_but_flagged_and_stripped(self, rich_miz: Path) -> None:
        # Reported, because hiding it would misrepresent the mission; flagged and without its
        # params, because forty ROE options would bury the one task that was authored on purpose.
        tasks = _group(describe_units(rich_miz), "Colt 1-1")["route"][1]["tasks"]
        option = next(task for task in tasks if task["auto"])
        assert option["id"] == "WrappedAction"
        assert "params" not in option

    def test_tasks_keep_their_declared_order(self, rich_miz: Path) -> None:
        tasks = _group(describe_units(rich_miz), "Colt 1-1")["route"][1]["tasks"]
        assert [task["number"] for task in tasks] == [1, 2]

    def test_a_waypoint_without_a_task_reports_none(self, rich_miz: Path) -> None:
        assert _group(describe_units(rich_miz), "Colt 1-1")["route"][0]["tasks"] == []


class TestFiltering:
    """A Foothold mission has thousands of units; unfiltered output would be unusable."""

    def test_a_group_name_filter_returns_that_group_alone(self, rich_miz: Path) -> None:
        result = describe_units(rich_miz, group_name="Colt 1-1")
        assert [group["name"] for group in result["groups"]] == ["Colt 1-1"]

    def test_the_group_name_filter_matches_a_fragment(self, rich_miz: Path) -> None:
        # A mission maker says "Colt", not the full generated name.
        assert [group["name"] for group in describe_units(rich_miz, group_name="colt")["groups"]] == ["Colt 1-1"]

    def test_a_coalition_filter_excludes_the_other_side(self, rich_miz: Path) -> None:
        names = [group["name"] for group in describe_units(rich_miz, coalition="red")["groups"]]
        assert names == ["Red Armor"]

    def test_a_category_filter_narrows_to_that_category(self, rich_miz: Path) -> None:
        result = describe_units(rich_miz, category="vehicle")
        assert [group["name"] for group in result["groups"]] == ["Red Armor"]

    def test_filters_combine(self, rich_miz: Path) -> None:
        assert describe_units(rich_miz, coalition="blue", category="vehicle")["groups"] == []

    def test_a_filter_matching_nothing_is_not_an_error(self, rich_miz: Path) -> None:
        # An agent probing for a group it is not sure about should get an answer, not an exception.
        result = describe_units(rich_miz, group_name="no-such-flight")
        assert result["groups"] == []
        assert result["matched"] == 0

    def test_the_count_says_how_many_matched(self, rich_miz: Path) -> None:
        assert describe_units(rich_miz)["matched"] == 3


class TestTruncation:
    """A cap the caller is told about, rather than a wall of JSON or a silent cut."""

    def test_a_limit_caps_the_groups_returned(self, rich_miz: Path) -> None:
        result = describe_units(rich_miz, limit=1)
        assert len(result["groups"]) == 1
        assert result["truncated"] is True
        assert result["matched"] == 3

    def test_nothing_is_truncated_when_everything_fits(self, rich_miz: Path) -> None:
        assert describe_units(rich_miz)["truncated"] is False


class TestErrors:
    def test_an_archive_without_a_mission_is_refused(self, tmp_path: Path) -> None:
        miz_path = tmp_path / "empty.miz"
        with zipfile.ZipFile(miz_path, "w") as zf:
            zf.writestr("options", b"options = {\n}\n")
        with pytest.raises(ValueError, match="Not a valid DCS mission"):
            describe_units(miz_path)

    def test_a_missing_file_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            describe_units(tmp_path / "nope.miz")


class TestRouteCanBeLeftOut:
    """Measured, not guessed: one 62-waypoint Foothold group is 18 KB with its route.

    A caller asking about loadouts should not pay for routes. The whole mission is 1.9 MB, which is
    also why the default limit exists.
    """

    def test_the_route_key_is_absent_rather_than_empty(self, rich_miz: Path) -> None:
        # Absent, not `[]`: an empty list would say "this group has no route", which is a different
        # fact from "you did not ask".
        group = _group(describe_units(rich_miz, include_route=False), "Colt 1-1")
        assert "route" not in group

    def test_units_are_still_described(self, rich_miz: Path) -> None:
        group = _group(describe_units(rich_miz, include_route=False), "Colt 1-1")
        assert group["units"][0]["pylons"][4] == "{GBU-12}"

    def test_the_route_is_there_by_default(self, rich_miz: Path) -> None:
        assert len(_group(describe_units(rich_miz), "Colt 1-1")["route"]) == 2


class TestCallsignShapes:
    """A callsign is a table for aircraft and a plain number for a ground unit (Sourcery, #724).

    The first version returned a value only for a dict or a non-empty `str`, so a numeric callsign
    came back as `None` — the docstring promised one thing and the code did another. A dropped
    callsign is invisible: the field is simply absent, and nothing says it was there.
    """

    def test_an_aircraft_callsign_uses_its_name(self, rich_miz: Path) -> None:
        assert _group(describe_units(rich_miz), "Colt 1-1")["units"][0]["callsign"] == "Enfield11"

    def test_a_numeric_callsign_is_kept_as_text(self) -> None:
        from veaf_mission_mcp.describe_units import _callsign

        assert _callsign(101) == "101"

    def test_a_string_callsign_is_kept(self) -> None:
        from veaf_mission_mcp.describe_units import _callsign

        assert _callsign("Springfield") == "Springfield"

    def test_absent_and_empty_are_none(self) -> None:
        from veaf_mission_mcp.describe_units import _callsign

        assert _callsign(None) is None
        assert _callsign("") is None

    def test_a_table_without_a_name_is_none(self) -> None:
        from veaf_mission_mcp.describe_units import _callsign

        assert _callsign({1: 1, 2: 1}) is None
