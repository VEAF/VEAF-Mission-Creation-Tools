"""``mission.ground_control`` → the mission's ``groundControl`` (FIX-OPEN-TRAINING-CAUCASUS-FINDINGS ticket 01)."""

from __future__ import annotations

from types import SimpleNamespace

import pytest
import typer
from mission_builder.ground_control import apply_ground_control, ground_control_errors
from mission_builder_factory import make_worker


def _blank_ground_control() -> dict:
    """The ``groundControl`` table ``blank_mission.py`` writes: no slot, no vehicle control."""
    return {
        "isPilotControlVehicles": False,
        "passwords": {},
        "roles": {
            role: {"blue": 0, "neutrals": 0, "red": 0}
            for role in ("artillery_commander", "forward_observer", "instructor", "observer")
        },
    }


class TestApplyGroundControl:
    def test_a_number_applies_to_both_sides(self) -> None:
        mission = {"groundControl": _blank_ground_control()}

        apply_ground_control(mission, {"game_master": 5, "jtac": 3, "pilot_control_vehicles": True})

        roles = mission["groundControl"]["roles"]
        assert roles["instructor"] == {"blue": 5, "neutrals": 0, "red": 5}
        assert roles["forward_observer"] == {"blue": 3, "neutrals": 0, "red": 3}
        assert mission["groundControl"]["isPilotControlVehicles"] is True

    def test_a_per_side_mapping_sets_the_sides_apart(self) -> None:
        mission = {"groundControl": _blank_ground_control()}

        apply_ground_control(mission, {"tactical_commander": {"blue": 5, "red": 0}, "observer": {"red": 2}})

        roles = mission["groundControl"]["roles"]
        assert roles["artillery_commander"] == {"blue": 5, "neutrals": 0, "red": 0}
        assert roles["observer"] == {"blue": 0, "neutrals": 0, "red": 2}

    def test_the_v5_open_training_values(self) -> None:
        mission = {"groundControl": _blank_ground_control()}

        apply_ground_control(
            mission,
            {"game_master": 5, "tactical_commander": 5, "jtac": 5, "observer": 5, "pilot_control_vehicles": True},
        )

        for role in ("artillery_commander", "forward_observer", "instructor", "observer"):
            assert mission["groundControl"]["roles"][role] == {"blue": 5, "neutrals": 0, "red": 5}

    def test_a_role_the_block_does_not_name_keeps_its_value(self) -> None:
        ground_control = _blank_ground_control()
        ground_control["roles"]["observer"] = {"blue": 7, "neutrals": 0, "red": 7}
        ground_control["isPilotControlVehicles"] = True
        mission = {"groundControl": ground_control}

        apply_ground_control(mission, {"game_master": 1})

        assert mission["groundControl"]["roles"]["observer"] == {"blue": 7, "neutrals": 0, "red": 7}
        assert mission["groundControl"]["isPilotControlVehicles"] is True

    def test_passwords_are_kept(self) -> None:
        ground_control = _blank_ground_control()
        ground_control["passwords"] = {"instructor": {"blue": "hash"}}
        mission = {"groundControl": ground_control}

        apply_ground_control(mission, {"game_master": 5})

        assert mission["groundControl"]["passwords"] == {"instructor": {"blue": "hash"}}

    def test_a_mission_without_ground_control_gets_one(self) -> None:
        mission: dict = {}

        apply_ground_control(mission, {"game_master": 2})

        assert mission["groundControl"]["roles"]["instructor"] == {"blue": 2, "neutrals": 0, "red": 2}
        assert mission["groundControl"]["roles"]["observer"] == {"blue": 0, "neutrals": 0, "red": 0}
        assert mission["groundControl"]["isPilotControlVehicles"] is False
        assert mission["groundControl"]["passwords"] == {}


class TestGroundControlErrors:
    def test_a_valid_block_has_no_error(self) -> None:
        assert ground_control_errors({"game_master": 5, "jtac": {"blue": 1}, "pilot_control_vehicles": False}) == []

    def test_an_unknown_role_is_refused(self) -> None:
        errors = ground_control_errors({"game_masters": 5})

        assert len(errors) == 1
        assert "game_masters" in errors[0]

    def test_an_unknown_side_is_refused(self) -> None:
        errors = ground_control_errors({"game_master": {"neutrals": 1}})

        assert len(errors) == 1
        assert "neutrals" in errors[0]

    @pytest.mark.parametrize("value", [-1, "5", 2.5, True, None])
    def test_a_count_that_is_not_a_natural_number_is_refused(self, value: object) -> None:
        assert len(ground_control_errors({"observer": value})) == 1

    def test_pilot_control_vehicles_must_be_a_boolean(self) -> None:
        assert len(ground_control_errors({"pilot_control_vehicles": "yes"})) == 1

    def test_a_block_that_is_not_a_mapping_is_refused(self) -> None:
        assert len(ground_control_errors([5])) == 1


class TestApplyGroundControlWiring:
    def _worker(self, mission_content: dict, mission_yaml: dict):
        return make_worker(dcs_mission=SimpleNamespace(mission_content=mission_content), mission_yaml=mission_yaml)

    def test_the_build_applies_the_block(self) -> None:
        content = {"groundControl": _blank_ground_control()}

        self._worker(content, {"mission": {"ground_control": {"game_master": 5}}}).apply_ground_control()

        assert content["groundControl"]["roles"]["instructor"] == {"blue": 5, "neutrals": 0, "red": 5}

    def test_absent_the_build_leaves_the_mission_alone(self) -> None:
        ground_control = _blank_ground_control()
        ground_control["roles"]["instructor"] = {"blue": 3, "neutrals": 1, "red": 4}
        content = {"groundControl": ground_control}
        before = repr(content)

        self._worker(content, {"mission": {"name": "X"}}).apply_ground_control()

        assert repr(content) == before

    def test_an_invalid_block_stops_the_build(self) -> None:
        content = {"groundControl": _blank_ground_control()}

        with pytest.raises(typer.Abort, match="game_masters"):
            self._worker(content, {"mission": {"ground_control": {"game_masters": 5}}}).apply_ground_control()

    def test_no_dcs_mission_is_a_noop(self) -> None:
        make_worker(
            dcs_mission=None, mission_yaml={"mission": {"ground_control": {"game_master": 5}}}
        ).apply_ground_control()
