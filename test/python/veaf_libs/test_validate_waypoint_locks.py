"""Tests that `validate` names a route the DCS Mission Editor refuses to save.

`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`. On 2026-08-22 `veaf-tools mission validate` reported
"✓ no defect" on `verify-mission-a`, and seconds later the editor refused to open it:

    SmokeZone-SmokeArmor:
    All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!

`ETA_locked` appeared nowhere in the validator. The bad data was a hand-copied waypoint rather than a
tooling bug — and an enumerated sweep of both verification missions found exactly one offender — so the
defect was the **silence**: a mission that will not open costs a session, and the tool whose whole job is
to say "this mission is sound" said it was.

The fixture below is that real route, not a synthetic one.
"""

from __future__ import annotations

from veaf_libs.mission_validator import WARNING, validate_mission_content


def _mission(points: list[dict]) -> dict:
    """A minimal mission table carrying one vehicle group with the given route points."""
    return {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "vehicle": {"group": [{"name": "SmokeZone-SmokeArmor", "route": {"points": points}}]},
                    }
                ]
            }
        }
    }


def _locks(*, eta: bool, speed: bool, x: float = 0.0) -> dict:
    return {"ETA_locked": eta, "speed_locked": speed, "x": x, "y": x, "speed": 5.5, "type": "Turning Point"}


def _warnings(mission: dict) -> list[str]:
    return [i.message for i in validate_mission_content({}, mission) if i.level == WARNING]


class TestTheRealRouteThatBrokeTheEditor:
    def test_two_locked_times_around_a_locked_speed_is_reported(self) -> None:
        # Exactly what verify-mission-a carried: both waypoints with ETA_locked *and* speed_locked.
        mission = _mission([_locks(eta=True, speed=True), _locks(eta=True, speed=True, x=2000)])
        found = _warnings(mission)
        assert any("SmokeZone-SmokeArmor" in m for m in found), found

    def test_the_repair_that_was_applied_makes_it_quiet(self) -> None:
        # The fix was to clear ETA_locked on the second waypoint. One locked departure with locked
        # speeds after it is the normal shape — every other route in both missions has it — so a check
        # that still complained here would be useless.
        mission = _mission([_locks(eta=True, speed=True), _locks(eta=False, speed=True, x=2000)])
        assert _warnings(mission) == []

    def test_the_message_names_the_group_and_the_waypoint(self) -> None:
        # DCS names the route and leaves you to find the flag. Doing the same would add nothing.
        mission = _mission([_locks(eta=True, speed=True), _locks(eta=True, speed=True, x=2000)])
        message = next(m for m in _warnings(mission) if "SmokeZone-SmokeArmor" in m)
        assert "2" in message
        assert "speed" in message.lower()


class TestTheSymmetricCase:
    def test_a_route_with_no_locked_time_is_reported(self) -> None:
        # DCS: "Route has no waypoints with locked time!". FIX-WAYPOINTS-ETA-LOCKED taught the MCP to
        # repair this on its own edits and left the validator blind to it in data it did not write.
        mission = _mission([_locks(eta=False, speed=True), _locks(eta=False, speed=True, x=2000)])
        found = _warnings(mission)
        assert any("SmokeZone-SmokeArmor" in m for m in found), found

    def test_a_single_locked_departure_is_the_normal_shape(self) -> None:
        mission = _mission([_locks(eta=True, speed=False), _locks(eta=False, speed=False, x=2000)])
        assert _warnings(mission) == []


class TestItSurvivesRealMissionData:
    def test_a_group_with_no_route_is_skipped(self) -> None:
        mission = {"coalition": {"blue": {"country": [{"name": "USA", "vehicle": {"group": [{"name": "Static"}]}}]}}}
        assert _warnings(mission) == []

    def test_an_oddly_shaped_mission_reports_nothing_rather_than_raising(self) -> None:
        # A validator that dies on unexpected data reports nothing about the rest of the mission, which
        # is the failure mode this whole file exists to remove.
        for mission in ({}, {"coalition": None}, {"coalition": {"blue": []}}):
            assert _warnings(mission) == []

    def test_a_single_waypoint_route_needs_its_departure_locked(self) -> None:
        # A one-point route is what most static groups have. DCS still wants the departure locked, and
        # the mission that shipped had it, so this must not be excused.
        assert _warnings(_mission([_locks(eta=False, speed=False)])) != []
        assert _warnings(_mission([_locks(eta=True, speed=False)])) == []
