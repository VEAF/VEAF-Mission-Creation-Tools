"""A mission nobody can fly must not pass `validate` in silence.

The mission built for the 2026-08-14 DCS session passed `validate` and built cleanly, and DCS then
refused to load it: `coalitions` was empty, so every country sat unassigned and the units lived in a
side that did not exist. `blank_mission` ships that table empty on the stated assumption that
`add_group` fills it in, and nothing does — the guard below is what would have caught it.

Two checks, deliberately different severities:

- units in a side whose coalition owns no country is an **error**: DCS cannot load it;
- no player slot anywhere is a **warning**: a server-side scenario or a template library legitimately
  has none, so refusing the build would be wrong.

The error case is an **inclusion**, not an emptiness test: DCS wants every country owning units under
`coalition.<side>.country` listed in `coalitions.<side>`. Checking only for an empty list left one
country assigned out of three passing `validate` while DCS still refused the mission —
`TestPartiallyAssignedSide` is what closes that.
"""

from __future__ import annotations

from typing import Any

from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, WARNING, _check_has_player_slot, validate_mission_content


def _mission(*, coalitions: Any, with_player: bool = True, side: str = "blue") -> dict[str, Any]:
    """A minimal mission table with one aircraft group on *side*."""
    unit = {"name": "u1", "type": "A-10C_2", "skill": "Client" if with_player else "High"}
    return {
        "theatre": "Caucasus",
        "coalitions": coalitions,
        "coalition": {
            side: {
                "country": [
                    {
                        "id": 2,
                        "name": "USA",
                        "plane": {"group": [{"name": "g1", "units": [unit]}]},
                    }
                ]
            }
        },
    }


def _messages(issues: list[Any], level: str) -> list[str]:
    return [issue.message for issue in issues if issue.level == level]


class TestSideWithoutCountry:
    def test_units_in_a_side_owning_no_country_is_an_error(self) -> None:
        # Exactly the state of the session mission: blue holds a group, coalitions.blue is empty.
        issues = validate_mission_content({}, _mission(coalitions={"blue": {}, "red": {}, "neutrals": {}}))
        errors = _messages(issues, ERROR)
        assert any("blue" in m for m in errors), f"the side must be named in the message: {errors}"

    def test_an_assigned_side_passes(self) -> None:
        issues = validate_mission_content({}, _mission(coalitions={"blue": [2], "red": [0], "neutrals": []}))
        assert _messages(issues, ERROR) == []

    def test_a_side_with_no_units_is_not_reported(self) -> None:
        # An empty red side owning no country is coherent — there is nothing in it.
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []})
        assert _messages(validate_mission_content({}, mission), ERROR) == []

    def test_a_side_missing_from_coalitions_entirely_is_an_error(self) -> None:
        # Not the same input as an empty container: here `assigned.get("blue")` is None. A mission
        # declaring only red and neutrals is a shape a hand-edited file can reach, and the units are
        # just as unreachable.
        mission = _mission(coalitions={"red": [], "neutrals": []})
        errors = _messages(validate_mission_content({}, mission), ERROR)
        assert any("blue" in m for m in errors), f"an absent side is as broken as an empty one: {errors}"

    def test_the_dict_shape_of_coalitions_is_understood(self) -> None:
        # A Lua table with non-contiguous keys deserialises as a dict, not a list. Reading only one
        # shape is how a check passes on half its inputs.
        mission = _mission(coalitions={"blue": {1: 2}, "red": {}, "neutrals": {}})
        assert _messages(validate_mission_content({}, mission), ERROR) == []


def _country(country_id: int, *, with_units: bool) -> dict[str, Any]:
    """One entry of ``coalition.<side>.country``, owning a plane group or nothing at all."""
    country: dict[str, Any] = {"id": country_id, "name": f"C{country_id}"}
    if with_units:
        unit = {"name": f"u{country_id}", "type": "A-10C_2", "skill": "Client"}
        country["plane"] = {"group": {1: {"name": f"g{country_id}", "units": {1: unit}}}}
    return country


def _multi_country_mission(*, listed: Any, owners: list[int], idle: list[int] | None = None) -> dict[str, Any]:
    """A blue side where the *owners* countries field units and the *idle* ones field none.

    The tables are dict-keyed and 1-based, the shape a real ``.miz`` deserialises to — testing only
    the list shape would exercise a form the game does not always write.
    """
    countries = [_country(cid, with_units=True) for cid in owners]
    countries += [_country(cid, with_units=False) for cid in idle or []]
    return {
        "theatre": "Caucasus",
        "coalitions": {"blue": listed, "red": {}, "neutrals": {}},
        "coalition": {"blue": {"country": dict(enumerate(countries, start=1))}},
    }


class TestPartiallyAssignedSide:
    """DCS requires *every* unit-owning country to be listed, not merely one of them.

    The defect PR #868 fixed produced six unit-owning countries and no assignment. Had it been
    "fixed" by declaring a single country, a check that only looks for an empty list would have gone
    quiet while DCS kept refusing the mission — hiding the very bug it exists to catch.
    """

    def test_a_partially_assigned_side_is_reported_with_the_missing_ids(self) -> None:
        mission = _multi_country_mission(listed={1: 2}, owners=[2, 5, 80])
        errors = _messages(validate_mission_content({}, mission), ERROR)
        assert len(errors) == 1, f"exactly one error expected: {errors}"
        assert "5" in errors[0] and "80" in errors[0], f"the missing ids are what make it fixable: {errors[0]}"
        assert "coalitions.blue" in errors[0], f"the table to edit must be named: {errors[0]}"

    def test_a_fully_assigned_side_stays_silent(self) -> None:
        mission = _multi_country_mission(listed={1: 2, 2: 5, 3: 80}, owners=[2, 5, 80])
        assert _messages(validate_mission_content({}, mission), ERROR) == []

    def test_an_empty_list_keeps_the_original_message(self) -> None:
        # The empty case explains the consequence better than a list of ids would; it must survive.
        mission = _multi_country_mission(listed={}, owners=[2, 5, 80])
        errors = _messages(validate_mission_content({}, mission), ERROR)
        assert errors == [t("validate.side_without_country", side="blue")], errors

    def test_a_country_owning_no_units_is_never_required(self) -> None:
        # DCS does not care about an empty country, and demanding it would light up good missions.
        mission = _multi_country_mission(listed={1: 2}, owners=[2], idle=[5, 80])
        assert _messages(validate_mission_content({}, mission), ERROR) == []

    def test_a_listed_country_owning_nothing_is_not_reported(self) -> None:
        # The invariant is an inclusion, not an equality: listing a country that fields nothing yet
        # is exactly what a mission maker does before populating it.
        mission = _multi_country_mission(listed={1: 2, 2: 17}, owners=[2])
        assert _messages(validate_mission_content({}, mission), ERROR) == []

    def test_ids_are_compared_as_numbers_whatever_their_written_form(self) -> None:
        # The two tables are written by different producers; a hand-edited file can carry "2" where
        # the other carries 2, and reporting that as a missing country would be a pure false alarm.
        mission = _multi_country_mission(listed={1: "2", 2: 5.0}, owners=[2, 5])
        assert _messages(validate_mission_content({}, mission), ERROR) == []

    def test_an_unreadable_id_is_ignored_rather_than_reported(self) -> None:
        # Nothing can be said about a country whose id is not one, and a validator that invents an
        # error out of a shape it does not understand is worse than one that stays quiet.
        mission = _multi_country_mission(listed={1: 2, 2: object()}, owners=[2])
        mission["coalition"]["blue"]["country"][1]["id"] = "USA"
        assert _messages(validate_mission_content({}, mission), ERROR) == []


class TestPlayerSlot:
    def test_no_player_slot_warns_rather_than_errors(self) -> None:
        # Checked at the folder level rather than inside validate_mission_content, which the BUILD also
        # runs: a template library legitimately has no slot, and warning on every build of one is noise.
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []}, with_player=False)
        assert _messages(validate_mission_content({}, mission), ERROR) == []
        assert _messages(_check_has_player_slot(mission), WARNING), "but it is worth saying once"

    def test_a_mission_with_a_slot_says_nothing(self) -> None:
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []}, with_player=True)
        assert _check_has_player_slot(mission) == []
