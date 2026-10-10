"""Reading and validating `campaign.yaml` (FEAT-MULTI-MISSION-CAMPAIGN ticket 01)."""

from __future__ import annotations

import copy
from typing import Any

import pytest
from campaign_fixture import VALID
from campaign_manager.campaign_manager import parse_campaign
from campaign_manager.models import DEFAULT_SIZE_CLASSES, CampaignRules
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR


def _with(**changes: Any) -> dict[str, Any]:
    """Return a deep copy of VALID with top-level keys replaced."""
    raw = copy.deepcopy(VALID)
    raw.update(changes)
    return raw


def _errors(raw: dict[str, Any]) -> list[str]:
    _, issues = parse_campaign(raw)
    return [issue.message for issue in issues if issue.level == ERROR]


class TestAValidCampaign:
    def test_parses_without_any_issue(self) -> None:
        campaign, issues = parse_campaign(copy.deepcopy(VALID))
        assert issues == []
        assert campaign is not None
        assert campaign.name == "Caucasus Front"
        assert campaign.missions == 8
        assert [zone.name for zone in campaign.zones] == ["Kobuleti", "Senaki", "Gudauta depot"]

    def test_an_airfield_zone_keeps_its_airfield_and_a_point_zone_its_coordinates(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        assert campaign.zone("Senaki").location.airfield == "Senaki-Kolkhi"
        depot = campaign.zone("Gudauta depot").location
        assert (depot.airfield, depot.lat, depot.lon) == (None, 43.10, 40.58)

    def test_a_size_class_override_keeps_the_shipped_values_it_does_not_name(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        outpost = campaign.size_classes["outpost"]
        assert outpost.size == 2
        assert outpost.defense == DEFAULT_SIZE_CLASSES["outpost"].defense
        assert campaign.size_classes["airfield"] == DEFAULT_SIZE_CLASSES["airfield"]

    def test_missions_defaults_to_ten_and_player_side_to_blue(self) -> None:
        raw = copy.deepcopy(VALID)
        del raw["campaign"]["missions"]
        campaign, issues = parse_campaign(raw)
        assert issues == []
        assert campaign is not None
        assert campaign.missions == 10
        assert campaign.player_side == "blue"

    def test_objectives_are_read_in_order(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        capture, destroy = campaign.objectives
        assert (capture.kind, capture.zones) == ("capture", ("Senaki",))
        assert (destroy.kind, destroy.zones, destroy.target_kind) == ("destroy", ("Gudauta depot",), "logistics")

    def test_an_explicit_garrison_is_kept_as_written(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        assert campaign.zone("Gudauta depot").garrison == ("sa8", "shilka", "T-72B")
        assert campaign.zone("Kobuleti").garrison is None

    def test_neighbours_follow_the_connections_both_ways(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        assert campaign.neighbours("Senaki") == ("Kobuleti", "Gudauta depot")
        assert campaign.neighbours("Kobuleti") == ("Senaki",)


class TestTheCampaignBlock:
    def test_a_missing_campaign_block_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        del raw["campaign"]
        assert _errors(raw) == [t("campaign.issue.missing_block", block="campaign")]

    def test_a_missing_name_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        del raw["campaign"]["name"]
        assert t("campaign.issue.missing_name") in _errors(raw)

    def test_an_unknown_theatre_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["theatre"] = "Atlantis"
        assert t("campaign.issue.unknown_theatre", theatre="Atlantis") in _errors(raw)

    def test_an_unknown_era_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["era"] = "VIKING"
        assert t("campaign.issue.unknown_era", era="VIKING", known="MODERN, COLD_WAR, WW2") in _errors(raw)

    @pytest.mark.parametrize("missions", [0, -3, "ten", True])
    def test_a_mission_count_that_is_not_a_positive_integer_is_reported(self, missions: Any) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["missions"] = missions
        assert t("campaign.issue.bad_missions", value=missions) in _errors(raw)

    def test_a_player_side_that_is_not_a_coalition_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["player_side"] = "neutral"
        assert t("campaign.issue.bad_player_side", side="neutral") in _errors(raw)


class TestZones:
    def test_no_zone_at_all_is_reported(self) -> None:
        assert t("campaign.issue.no_zones") in _errors(
            _with(zones=[], connections=[], campaign={**VALID["campaign"], "objectives": []})
        )

    def test_a_duplicate_zone_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"].append(copy.deepcopy(raw["zones"][0]))
        assert t("campaign.issue.duplicate_zone", zone="Kobuleti") in _errors(raw)

    def test_a_zone_without_a_name_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        del raw["zones"][0]["name"]
        assert t("campaign.issue.zone_without_name", index=1) in _errors(raw)

    def test_an_unknown_airfield_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["at"] = {"airfield": "Gotham"}
        assert t("campaign.issue.unknown_airfield", zone="Kobuleti", airfield="Gotham", theatre="Caucasus") in _errors(
            raw
        )

    def test_the_airfield_name_is_matched_regardless_of_case_and_kept_as_dcs_spells_it(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["at"] = {"airfield": "kobuleti"}
        campaign, issues = parse_campaign(raw)
        assert issues == []
        assert campaign is not None
        assert campaign.zone("Kobuleti").location.airfield == "Kobuleti"

    @pytest.mark.parametrize(
        "at",
        [
            {},
            {"lat": 43.1},
            {"lat": 95, "lon": 40},
            {"lat": 43, "lon": 200},
            {"lat": "north", "lon": 40},
            {"airfield": "Kobuleti", "lat": 43, "lon": 40},
            "Kobuleti",
        ],
    )
    def test_a_location_that_is_neither_an_airfield_nor_valid_coordinates_is_reported(self, at: Any) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["at"] = at
        assert t("campaign.issue.bad_location", zone="Gudauta depot") in _errors(raw)

    def test_an_unknown_size_class_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["size"] = "megabase"
        assert t("campaign.issue.unknown_size", zone="Kobuleti", size="megabase", known="airfield, outpost") in _errors(
            raw
        )

    def test_an_unknown_side_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["side"] = "green"
        assert t("campaign.issue.unknown_side", zone="Kobuleti", side="green") in _errors(raw)

    def test_a_neutral_zone_is_accepted(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["side"] = "neutral"
        assert _errors(raw) == []

    def test_an_unknown_kind_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["kind"] = "casino"
        assert t("campaign.issue.unknown_kind", zone="Kobuleti", kind="casino", known="logistics") in _errors(raw)

    def test_an_unknown_garrison_entry_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["garrison"] = ["sa8", "deathstar"]
        assert t("campaign.issue.unknown_garrison_entry", zone="Gudauta depot", entry="deathstar") in _errors(raw)

    def test_a_garrison_entry_may_be_a_unit_alias_a_group_alias_or_a_dcs_type(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["garrison"] = ["sa8", "hq7", "T-72B"]
        assert _errors(raw) == []

    def test_the_radius_defaults_to_two_kilometres_and_can_be_set(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][1]["radius"] = 3500
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        assert (campaign.zone("Kobuleti").radius, campaign.zone("Senaki").radius) == (2000, 3500)

    @pytest.mark.parametrize("radius", [50, 50000, "big"])
    def test_a_radius_out_of_range_is_reported(self, radius: Any) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0]["radius"] = radius
        assert t("campaign.issue.bad_radius", zone="Kobuleti", value=radius, low=200, high=20000) in _errors(raw)

    def test_a_zone_can_be_named_for_the_players_and_carry_its_intelligence(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["display_name"] = "Dépôt de Gudauta"
        raw["zones"][2]["intel"] = "Dépôt actif, gardé."
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        depot = campaign.zone("Gudauta depot")
        assert (depot.label, depot.intel) == ("Dépôt de Gudauta", "Dépôt actif, gardé.")
        assert campaign.zone("Kobuleti").label == "Kobuleti"

    @pytest.mark.parametrize("key", ["display_name", "intel"])
    def test_a_display_name_or_intel_that_is_not_text_is_reported(self, key: str) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][0][key] = ["not", "text"]
        assert t("campaign.issue.bad_zone_text", zone="Kobuleti", field=key) in _errors(raw)

    def test_an_empty_garrison_list_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["garrison"] = []
        assert t("campaign.issue.empty_garrison", zone="Gudauta depot") in _errors(raw)


class TestSizeClasses:
    @pytest.mark.parametrize(
        ("field", "value"),
        [("size", 0), ("size", 6), ("defense", -1), ("defense", 6), ("armor", 9), ("armor", "lots")],
    )
    def test_a_parameter_out_of_its_generator_range_is_reported(self, field: str, value: Any) -> None:
        raw = _with(size_classes={"outpost": {field: value}})
        low = 1 if field == "size" else 0
        assert t(
            "campaign.issue.bad_size_parameter", size="outpost", field=field, value=value, low=low, high=5
        ) in _errors(raw)

    def test_an_unknown_parameter_is_reported(self) -> None:
        raw = _with(size_classes={"outpost": {"tanks": 3}})
        assert t("campaign.issue.unknown_size_parameter", size="outpost", field="tanks") in _errors(raw)

    def test_a_long_range_sam_flag_that_is_not_a_boolean_is_reported(self) -> None:
        raw = _with(size_classes={"outpost": {"long_range_sam": "yes"}})
        assert t("campaign.issue.bad_long_range_sam", size="outpost") in _errors(raw)

    def test_a_new_size_class_must_name_every_generator_parameter(self) -> None:
        raw = _with(size_classes={"fortress": {"size": 5}})
        assert t("campaign.issue.incomplete_size_class", size="fortress", missing="armor, defense") in _errors(raw)


class TestConnections:
    def test_a_connection_to_an_unknown_zone_is_reported(self) -> None:
        raw = _with(connections=[["Kobuleti", "Senaki"], ["Senaki", "Gudauta depot"], ["Senaki", "Mordor"]])
        assert t("campaign.issue.connection_unknown_zone", zone="Mordor") in _errors(raw)

    @pytest.mark.parametrize("connection", [["Kobuleti"], ["Kobuleti", "Senaki", "Gudauta depot"], "Kobuleti-Senaki"])
    def test_a_connection_that_is_not_a_pair_is_reported(self, connection: Any) -> None:
        raw = _with(connections=[*VALID["connections"], connection])
        assert t("campaign.issue.bad_connection", connection=connection) in _errors(raw)

    def test_a_zone_connected_to_itself_is_reported(self) -> None:
        raw = _with(connections=[*VALID["connections"], ["Senaki", "Senaki"]])
        assert t("campaign.issue.self_connection", zone="Senaki") in _errors(raw)

    def test_a_graph_that_is_not_connected_is_reported(self) -> None:
        raw = _with(connections=[["Kobuleti", "Senaki"]])
        assert t("campaign.issue.disconnected", zones="Gudauta depot") in _errors(raw)

    def test_a_single_zone_needs_no_connection(self) -> None:
        raw = _with(zones=[VALID["zones"][0]], connections=[], campaign={**VALID["campaign"], "objectives": []})
        assert _errors(raw) == []


class TestObjectives:
    def test_an_objective_naming_an_unknown_zone_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["objectives"] = [{"capture": ["Senaki", "Atlantis"]}]
        assert t("campaign.issue.objective_unknown_zone", zone="Atlantis") in _errors(raw)

    def test_an_unknown_objective_kind_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["objectives"] = [{"bribe": ["Senaki"]}]
        assert t("campaign.issue.bad_objective", index=1) in _errors(raw)

    def test_a_destroy_objective_whose_kind_does_not_match_its_zone_is_reported(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["objectives"] = [{"destroy": {"zone": "Senaki", "kind": "logistics"}}]
        assert t("campaign.issue.objective_kind_mismatch", zone="Senaki", kind="logistics") in _errors(raw)

    def test_a_campaign_without_objectives_is_a_warning_not_an_error(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["objectives"] = []
        campaign, issues = parse_campaign(raw)
        assert campaign is not None
        assert [issue.message for issue in issues] == [t("campaign.issue.no_objectives")]
        assert issues[0].level != ERROR


class TestReservesRulesAndSettings:
    def test_reserves_default_to_zero_in_every_category(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        assert campaign.reserves == {
            "blue": {"armor": 0, "air_defense": 0, "transport": 0},
            "red": {"armor": 0, "air_defense": 0, "transport": 0},
        }

    def test_a_declared_reserve_is_read(self) -> None:
        campaign, issues = parse_campaign(_with(sides={"red": {"reserve": {"armor": 12, "transport": 3}}}))
        assert issues == []
        assert campaign is not None
        assert campaign.reserves["red"] == {"armor": 12, "air_defense": 0, "transport": 3}

    def test_an_unknown_side_in_sides_is_reported(self) -> None:
        raw = _with(sides={"green": {"reserve": {}}})
        assert t("campaign.issue.unknown_coalition", side="green") in _errors(raw)

    @pytest.mark.parametrize(("category", "value"), [("armour", 3), ("armor", -1), ("armor", "lots")])
    def test_a_bad_reserve_entry_is_reported(self, category: str, value: Any) -> None:
        raw = _with(sides={"red": {"reserve": {category: value}}})
        assert t("campaign.issue.bad_reserve", side="red", category=category, value=value) in _errors(raw)

    def test_rules_default_to_the_shipped_ones(self) -> None:
        campaign, _ = parse_campaign(copy.deepcopy(VALID))
        assert campaign is not None
        assert campaign.rules == CampaignRules()

    def test_rules_are_overridden_one_by_one(self) -> None:
        raw = _with(rules={"repairs_per_mission": 0, "counter_attack": False, "logistics_output": {"armor": 5}})
        campaign, issues = parse_campaign(raw)
        assert issues == []
        assert campaign is not None
        assert campaign.rules.repairs_per_mission == 0
        assert campaign.rules.counter_attack is False
        assert campaign.rules.logistics_output == {"armor": 5, "air_defense": 0, "transport": 0}

    @pytest.mark.parametrize(
        "rules",
        [{"repairs_per_mission": -1}, {"counter_attack": "yes"}, {"logistics_output": {"tanks": 1}}, {"bribes": 2}],
    )
    def test_a_bad_rule_is_reported(self, rules: dict[str, Any]) -> None:
        ((name, _),) = rules.items()
        assert t("campaign.issue.bad_rule", rule=name) in _errors(_with(rules=rules))

    def test_capture_and_write_intervals_are_read(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["capture_seconds"] = 300
        raw["campaign"]["state_write_seconds"] = 30
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        assert (campaign.capture_seconds, campaign.state_write_seconds) == (300, 30)

    @pytest.mark.parametrize("setting", ["capture_seconds", "state_write_seconds"])
    def test_an_interval_that_is_not_a_positive_integer_is_reported(self, setting: str) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"][setting] = 0
        assert t("campaign.issue.bad_seconds", setting=setting, value=0) in _errors(raw)


class TestTheParserNeverRaises:
    @pytest.mark.parametrize("raw", [None, [], "campaign", {"campaign": "x"}, {"campaign": {}, "zones": "x"}])
    def test_any_malformed_input_yields_issues_and_no_campaign(self, raw: Any) -> None:
        campaign, issues = parse_campaign(raw)
        assert campaign is None
        assert any(issue.level == ERROR for issue in issues)
