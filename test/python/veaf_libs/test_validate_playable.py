"""A mission nobody can fly must not pass `validate` in silence.

The mission built for the 2026-08-14 DCS session passed `validate` and built cleanly, and DCS then
refused to load it: `coalitions` was empty, so every country sat unassigned and the units lived in a
side that did not exist. `blank_mission` ships that table empty on the stated assumption that
`add_group` fills it in, and nothing does — the guard below is what would have caught it.

Two checks, deliberately different severities:

- units in a side whose coalition owns no country is an **error**: DCS cannot load it;
- no player slot anywhere is a **warning**: a server-side scenario or a template library legitimately
  has none, so refusing the build would be wrong.
"""

from __future__ import annotations

from typing import Any

from veaf_libs.mission_validator import ERROR, WARNING, validate_mission_content


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

    def test_the_dict_shape_of_coalitions_is_understood(self) -> None:
        # A Lua table with non-contiguous keys deserialises as a dict, not a list. Reading only one
        # shape is how a check passes on half its inputs.
        mission = _mission(coalitions={"blue": {1: 2}, "red": {}, "neutrals": {}})
        assert _messages(validate_mission_content({}, mission), ERROR) == []


class TestPlayerSlot:
    def test_no_player_slot_warns_rather_than_errors(self) -> None:
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []}, with_player=False)
        issues = validate_mission_content({}, mission)
        assert _messages(issues, ERROR) == [], "a mission with no slot is legitimate — it must not refuse"
        assert _messages(issues, WARNING), "but it is worth saying once"

    def test_a_mission_with_a_slot_says_nothing(self) -> None:
        mission = _mission(coalitions={"blue": [2], "red": [], "neutrals": []}, with_player=True)
        warnings = _messages(validate_mission_content({}, mission), WARNING)
        assert not any("slot" in w.lower() or "pilote" in w.lower() for w in warnings)
