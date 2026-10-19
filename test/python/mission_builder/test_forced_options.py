"""``mission.forced_options`` → the mission's ``forcedOptions`` (FEAT-FORCED-MISSION-OPTIONS tickets 01-02)."""

from __future__ import annotations

from types import SimpleNamespace

import pytest
import typer
from mission_builder.forced_options import (
    LAYER_CATEGORIES,
    LAYER_SIDES,
    OPTIONS,
    apply_forced_options,
    forced_options_errors,
)
from mission_builder_factory import make_worker


class TestApplyForcedOptions:
    def test_each_name_is_written_under_its_dcs_key(self) -> None:
        mission: dict = {}

        apply_forced_options(
            mission,
            {
                "external_views": False,
                "f10_marks": True,
                "wake_turbulence": True,
                "birds": 300,
                "g_effects": "realistic",
            },
        )

        assert mission["forcedOptions"] == {
            "externalViews": False,
            "userMarks": True,
            "wakeTurbulence": True,
            "birds": 300,
            "geffect": "realistic",
        }

    @pytest.mark.parametrize(
        ("name", "value", "dcs_key", "dcs_value"),
        [
            ("labels", "full", "labels", 1),
            ("labels", "abbreviated", "labels", 2),
            ("labels", "symbol_only", "labels", 3),
            ("labels", "dot_neutral", "labels", 4),
            ("labels", "none", "labels", 0),
            ("spotting_dot", "off", "spottingDot", 0),
            ("spotting_dot", "auto", "spottingDot", 3),
            ("spotting_dot", "one_pixel", "spottingDot", 1),
            ("spotting_dot", "two_pixels", "spottingDot", 2),
            ("f10_view", "all", "optionsView", "optview_all"),
            ("f10_view", "fog_of_war", "optionsView", "optview_allies"),
            ("f10_view", "allies_only", "optionsView", "optview_onlyallies"),
            ("f10_view", "map_only", "optionsView", "optview_onlymap"),
            ("f10_view", "my_aircraft", "optionsView", "optview_myaircraft"),
            ("civil_traffic", "off", "civTraffic", ""),
            ("civil_traffic", "high", "civTraffic", "high"),
        ],
    )
    def test_a_coded_value_is_translated(self, name: str, value: str, dcs_key: str, dcs_value: object) -> None:
        mission: dict = {}

        apply_forced_options(mission, {name: value})

        assert mission["forcedOptions"] == {dcs_key: dcs_value}

    def test_an_option_the_block_does_not_name_keeps_its_value(self) -> None:
        mission = {"forcedOptions": {"labels": 0, "civTraffic": "low"}}

        apply_forced_options(mission, {"labels": "full"})

        assert mission["forcedOptions"] == {"labels": 1, "civTraffic": "low"}

    def test_every_dcs_key_is_distinct(self) -> None:
        keys = [option.dcs_key for option in OPTIONS.values()]

        assert len(keys) == len(set(keys))


class TestF10ViewByRole:
    def test_it_switches_the_view_to_extended_and_fills_the_six_roles(self) -> None:
        mission: dict = {}

        apply_forced_options(mission, {"f10_view_by_role": {"pilot": "fog_of_war"}})

        forced = mission["forcedOptions"]
        assert forced["optionsView"] == "optview_extended"
        extended = forced["optionsViewExtended"]
        assert sorted(extended) == [1, 2, 3, 4, 5, 6]
        assert extended[1]["f10ViewOption"] == "optview_allies"
        assert extended[5] == {"f10ViewOption": "optview_all", "visibleUnitLayersMask": dict.fromkeys(range(15), True)}

    def test_the_role_numbers_are_the_editors(self) -> None:
        mission: dict = {}
        roles = {
            "pilot": "map_only",
            "jtac": "all",
            "tactical_commander": "allies_only",
            "observer": "fog_of_war",
            "spectator": "my_aircraft",
            "airboss": "all",
        }

        apply_forced_options(mission, {"f10_view_by_role": roles})

        views = {
            role: entry["f10ViewOption"] for role, entry in mission["forcedOptions"]["optionsViewExtended"].items()
        }
        assert views == {
            1: "optview_onlymap",
            2: "optview_all",
            3: "optview_onlyallies",
            4: "optview_allies",
            5: "optview_myaircraft",
            6: "optview_all",
        }

    def test_hidden_layers_are_bit_row_times_three_plus_column(self) -> None:
        """Bits as the editor's dialog lays them out: rows planes…weapons, columns allies, enemies, neutral."""
        mission: dict = {}

        apply_forced_options(
            mission,
            {
                "f10_view_by_role": {
                    "pilot": {"view": "all", "hide": ["allies_planes", "enemies_ground", "neutral_weapons"]}
                }
            },
        )

        mask = mission["forcedOptions"]["optionsViewExtended"][1]["visibleUnitLayersMask"]
        assert [bit for bit, shown in mask.items() if not shown] == [0, 7, 14]

    def test_the_layer_vocabulary_covers_the_fifteen_bits(self) -> None:
        assert len(LAYER_SIDES) * len(LAYER_CATEGORIES) == 15


class TestForcedOptionsErrors:
    def test_a_valid_block_has_no_error(self) -> None:
        block = {
            "labels": "none",
            "f10_view": "fog_of_war",
            "external_views": False,
            "birds": 0,
            "civil_traffic": "off",
        }

        assert forced_options_errors(block) == []

    def test_a_valid_role_block_has_no_error(self) -> None:
        block = {"f10_view_by_role": {"pilot": "fog_of_war", "jtac": {"view": "all", "hide": ["enemies_weapons"]}}}

        assert forced_options_errors(block) == []

    def test_an_unknown_option_is_refused(self) -> None:
        errors = forced_options_errors({"external_view": False})

        assert len(errors) == 1
        assert "external_view" in errors[0]

    @pytest.mark.parametrize(
        ("name", "value"),
        [
            ("external_views", "no"),
            ("external_views", 0),
            ("labels", "short"),
            ("labels", 1),
            ("birds", -1),
            ("birds", 1001),
            ("birds", True),
            ("f10_view", "by_role"),
        ],
    )
    def test_a_wrong_value_is_refused(self, name: str, value: object) -> None:
        errors = forced_options_errors({name: value})

        assert len(errors) == 1
        assert name in errors[0]

    def test_f10_view_and_f10_view_by_role_together_are_refused(self) -> None:
        errors = forced_options_errors({"f10_view": "all", "f10_view_by_role": {"pilot": "all"}})

        assert len(errors) == 1
        assert "f10_view_by_role" in errors[0]

    @pytest.mark.parametrize(
        "roles",
        [
            {"pilots": "all"},
            {"pilot": "everything"},
            {"pilot": {"view": "all", "hide": ["enemy_weapons"]}},
            {"pilot": {"hide": ["enemies_weapons"]}},
            {"pilot": {"view": "all", "show": []}},
            ["pilot"],
        ],
    )
    def test_a_wrong_role_block_is_refused(self, roles: object) -> None:
        assert len(forced_options_errors({"f10_view_by_role": roles})) == 1

    def test_a_block_that_is_not_a_mapping_is_refused(self) -> None:
        assert len(forced_options_errors(["labels"])) == 1


class TestApplyForcedOptionsWiring:
    def _worker(self, mission_content: dict, mission_yaml: dict):
        return make_worker(dcs_mission=SimpleNamespace(mission_content=mission_content), mission_yaml=mission_yaml)

    def test_the_build_applies_the_block(self) -> None:
        content: dict = {"forcedOptions": {}}

        self._worker(content, {"mission": {"forced_options": {"labels": "none"}}}).apply_forced_options()

        assert content["forcedOptions"] == {"labels": 0}

    def test_absent_the_build_leaves_the_mission_alone(self) -> None:
        content = {"forcedOptions": {"labels": 3}}

        self._worker(content, {"mission": {"name": "X"}}).apply_forced_options()

        assert content == {"forcedOptions": {"labels": 3}}

    def test_an_invalid_block_stops_the_build(self) -> None:
        content: dict = {"forcedOptions": {}}

        with pytest.raises(typer.Abort, match="external_view"):
            self._worker(content, {"mission": {"forced_options": {"external_view": False}}}).apply_forced_options()

    def test_no_dcs_mission_is_a_noop(self) -> None:
        make_worker(
            dcs_mission=None, mission_yaml={"mission": {"forced_options": {"labels": "none"}}}
        ).apply_forced_options()
