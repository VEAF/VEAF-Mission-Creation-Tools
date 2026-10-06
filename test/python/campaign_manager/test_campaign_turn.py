"""Between two missions: merge the state file, play the turn, judge the objectives (ticket 08)."""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest
from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.models import CampaignDefinition, CampaignState
from campaign_manager.turn_manager import (
    describe_change,
    evaluate_objectives,
    merge_state_file,
    outcome,
    play_turn,
    read_state_file,
    reserve_category,
    validate_state_file,
)
from lua_runner import run_lua
from veaf_libs.i18n import language, t
from veaf_libs.mission_validator import ERROR

REPO = Path(__file__).resolve().parents[3]


def _campaign(**changes: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw.update(changes)
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _garrison(
    name: str, *alive: bool, types: tuple[str, ...] = ("T-72B", "Osa 9A33 ln", "Ural-375")
) -> list[dict[str, Any]]:
    units = [{"type": types[i % len(types)], "x": i, "z": i, "heading": 0, "alive": a} for i, a in enumerate(alive)]
    return [{"name": f"{name} garrison", "units": units}]


def _flown(current: CampaignState, **zones: dict[str, Any]) -> CampaignState:
    """The state file of the next mission: the current state, with some zones changed."""
    flown = copy.deepcopy(current)
    flown.mission = current.mission + 1
    for name, changes in zones.items():
        for key, value in changes.items():
            setattr(flown.zones[name.replace("_", " ")], key, value)
    return flown


# ---------------------------------------------------------------------------
# The state file written by the mission
# ---------------------------------------------------------------------------


def _lua_state_file(tmp_path: Path, data: str) -> Path:
    """Run veafCampaign's own serializer under the DCS mocks and write what it produces."""
    src = (REPO / "src" / "scripts" / "veaf").as_posix()
    mocks = (REPO / "test" / "lua").as_posix()
    target = (tmp_path / "mission-01.state").as_posix()
    chunk = f"""
dofile("{mocks}/dcs_mocks.lua")
for _, m in ipairs({{"veaf","veafI18n","veafScheduler","veafMath","veafGeo","veafMissionDb","veafDcsSpawner",
  "dcsUnits","veafUnits","veafCasMission","veafEventHandler","veafCampaign"}}) do dofile("{src}/" .. m .. ".lua") end
veafCampaign.data = {data}
veafCampaign.initialize()
local f = assert(io.open("{target}", "w"))
f:write("return " .. veafCampaign.serialize(veafCampaign.stateTable()) .. "\\n")
f:close()
"""
    result = run_lua(chunk)
    assert result.returncode == 0, result.stderr
    return tmp_path / "mission-01.state"


class TestReadingTheStateFile:
    def test_a_state_file_written_by_the_mission_reads_as_a_campaign_state(self, tmp_path: Path) -> None:
        path = _lua_state_file(
            tmp_path,
            """{ format_version = 1, campaign = "Caucasus Front", mission = 1,
              sides = { blue = { reserve = {} }, red = { reserve = { armor = 3 } } },
              zones = {
                { name = "Senaki", x = 0, z = 0, owner = "red", garrison = { { name = "Senaki garrison",
                  units = { { type = "T-72B", x = 1.5, z = 2.25, heading = 0.5, alive = false } } } } },
                { name = "Poti", x = 0, z = 0, owner = "neutral" },
              } }""",
        )
        state, issues = read_state_file(path)
        assert issues == []
        assert state is not None
        assert state.mission == 1
        assert state.zones["Senaki"].garrison == [
            {
                "name": "Senaki garrison",
                "units": [{"type": "T-72B", "x": 1.5, "z": 2.25, "heading": 0.5, "alive": False}],
            }
        ]
        assert state.zones["Poti"].owner == "neutral"
        assert state.zones["Poti"].garrison is None
        # an empty Lua table is a dict to luadata: lists come back as lists
        assert state.sides["blue"].reserve == {}
        assert state.scenery_destroyed == []

    def test_a_file_that_is_not_lua_is_reported(self, tmp_path: Path) -> None:
        path = tmp_path / "mission-01.state"
        path.write_text("return { unclosed", encoding="utf-8")
        state, issues = read_state_file(path)
        assert state is None
        assert [i.message for i in issues] == [t("campaign.issue.state_file_unreadable", path=path)]

    def test_a_file_cut_short_falls_back_on_its_complete_temporary(self, tmp_path: Path) -> None:
        """Without `os` the mission writes the temporary, then the file: a crash between keeps one whole."""
        whole = _lua_state_file(tmp_path, '{ format_version = 1, campaign = "C", mission = 1, zones = {} }')
        temporary = whole.with_name(whole.name + ".tmp")
        whole.rename(temporary)
        whole.write_text("return { format_version = 1, camp", encoding="utf-8")
        state, issues = read_state_file(whole)
        assert state is not None
        assert state.mission == 1
        assert [i.message for i in issues] == [t("campaign.issue.state_file_from_temporary", path=temporary)]
        assert issues[0].level != ERROR

    def test_a_missing_file_is_said_to_be_missing_not_unreadable(self, tmp_path: Path) -> None:
        """David, 2026-10-06: a mistyped path read as a corrupt file sends you looking for the wrong defect."""
        state, issues = read_state_file(tmp_path / "nope.state")
        assert state is None
        assert [i.message for i in issues] == [t("campaign.issue.state_file_missing", path=tmp_path / "nope.state")]

    def test_a_missing_file_whose_temporary_is_there_falls_back_on_it(self, tmp_path: Path) -> None:
        whole = _lua_state_file(tmp_path, '{ format_version = 1, campaign = "C", mission = 1, zones = {} }')
        temporary = whole.with_name(whole.name + ".tmp")
        whole.rename(temporary)
        state, issues = read_state_file(whole)
        assert state is not None
        assert [i.message for i in issues] == [t("campaign.issue.state_file_from_temporary", path=temporary)]


# ---------------------------------------------------------------------------
# Validation against the campaign
# ---------------------------------------------------------------------------


class TestValidatingTheStateFile:
    def test_the_next_mission_is_accepted(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        assert validate_state_file(campaign, current, _flown(current)) == []

    def test_applying_the_same_mission_twice_is_refused(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        current.mission = 3
        flown = _flown(current)
        flown.mission = 3
        assert [i.message for i in validate_state_file(campaign, current, flown)] == [
            t("campaign.issue.state_file_already_applied", mission=3)
        ]

    def test_a_mission_that_skips_one_is_refused(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        flown = _flown(current)
        flown.mission = 3
        assert [i.message for i in validate_state_file(campaign, current, flown)] == [
            t("campaign.issue.state_file_skips", mission=3, expected=1)
        ]

    def test_a_state_file_of_another_campaign_is_refused(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        flown = _flown(current)
        flown.campaign = "Syria Front"
        messages = [i.message for i in validate_state_file(campaign, current, flown)]
        assert messages == [t("campaign.issue.state_other_campaign", found="Syria Front", expected="Caucasus Front")]

    def test_a_state_file_missing_a_zone_is_refused(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        flown = _flown(current)
        del flown.zones["Senaki"]
        assert t("campaign.issue.state_zone_missing", zone="Senaki") in [
            i.message for i in validate_state_file(campaign, current, flown)
        ]


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------


class TestMerging:
    def test_zones_take_what_the_flight_left(self) -> None:
        current = initial_state(_campaign())
        garrison = _garrison("Senaki", True, False, True)
        flown = _flown(current, Senaki={"owner": "red", "garrison": garrison}, Kobuleti={"warehouse": {"weapon": {}}})
        merged, changes = merge_state_file(current, flown)
        assert merged.zones["Senaki"].garrison == garrison
        assert merged.zones["Kobuleti"].warehouse == {"weapon": {}}
        assert merged.mission == 1
        assert {"kind": "losses", "zone": "Senaki", "lost": 1} in changes

    def test_a_capture_in_progress_at_mission_end_is_dropped(self) -> None:
        current = initial_state(_campaign())
        flown = _flown(current, Senaki={"capture": {"side": "blue", "seconds": 40}})
        merged, _ = merge_state_file(current, flown)
        assert merged.zones["Senaki"].capture is None

    def test_a_change_of_owner_is_reported(self) -> None:
        current = initial_state(_campaign())
        flown = _flown(current, Senaki={"owner": "blue", "garrison": _garrison("Senaki", True)})
        _, changes = merge_state_file(current, flown)
        assert {"kind": "owner", "zone": "Senaki", "from": "red", "to": "blue"} in changes

    def test_scenery_comes_from_the_state_file(self) -> None:
        current = initial_state(_campaign())
        flown = _flown(current)
        flown.scenery_destroyed = [{"id": 1, "x": 0, "z": 0}, {"id": 2, "x": 0, "z": 0}]
        merged, changes = merge_state_file(current, flown)
        assert merged.scenery_destroyed == flown.scenery_destroyed
        assert {"kind": "scenery", "destroyed": 2} in changes

    def test_reserves_are_taken_as_the_mission_left_them(self) -> None:
        current = initial_state(_campaign(sides={"red": {"reserve": {"armor": 5, "transport": 2}}}))
        flown = _flown(current)
        flown.sides["red"].reserve = {"armor": 3}  # a garrison drawn in flight took two
        merged, _ = merge_state_file(current, flown)
        # a category the file does not carry keeps the campaign's count
        assert merged.sides["red"].reserve == {"armor": 3, "air_defense": 0, "transport": 2}

    def test_the_current_state_is_left_untouched(self) -> None:
        current = initial_state(_campaign())
        before = copy.deepcopy(current)
        merge_state_file(current, _flown(current, Senaki={"owner": "neutral"}))
        assert current == before


# ---------------------------------------------------------------------------
# The turn between missions
# ---------------------------------------------------------------------------


class TestTheTurn:
    def test_a_logistics_zone_feeds_its_owners_reserve(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        changes = play_turn(campaign, state)
        assert state.sides["red"].reserve == {"armor": 2, "air_defense": 1, "transport": 1}
        assert state.sides["blue"].reserve == {"armor": 0, "air_defense": 0, "transport": 0}
        assert {
            "kind": "logistics",
            "zone": "Gudauta depot",
            "side": "red",
            "added": {"armor": 2, "air_defense": 1, "transport": 1},
        } in changes

    def test_a_logistics_zone_no_longer_held_feeds_nobody(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Gudauta depot"].owner = "neutral"
        play_turn(campaign, state)
        assert state.sides["red"].reserve == {"armor": 0, "air_defense": 0, "transport": 0}

    def test_lost_units_are_repaired_from_the_reserve_up_to_the_limit(self) -> None:
        campaign = _campaign(rules={"repairs_per_mission": 2, "logistics_output": {}})
        state = initial_state(campaign)
        state.sides["red"].reserve = {"armor": 5, "air_defense": 0, "transport": 5}
        state.zones["Senaki"].garrison = _garrison("Senaki", False, False, False, False)
        changes = play_turn(campaign, state)
        units = state.zones["Senaki"].garrison[0]["units"]
        # T-72B repaired from armor; the Osa has no air-defence reserve; the Ural from transport; then the limit
        assert [u["alive"] for u in units] == [True, False, True, False]
        assert state.sides["red"].reserve == {"armor": 4, "air_defense": 0, "transport": 4}
        assert {"kind": "repaired", "zone": "Senaki", "units": 2} in changes

    def test_a_repaired_unit_comes_back_with_a_full_load(self) -> None:
        campaign = _campaign(rules={"logistics_output": {}})
        state = initial_state(campaign)
        state.sides["red"].reserve["air_defense"] = 1
        state.zones["Senaki"].garrison = _garrison("Senaki", False, types=("Osa 9A33 ln",))
        state.zones["Senaki"].garrison[0]["units"][0]["missiles"] = 0
        play_turn(campaign, state)
        unit = state.zones["Senaki"].garrison[0]["units"][0]
        assert unit["alive"] is True
        assert "missiles" not in unit

    def test_a_neutral_zone_bordered_by_one_side_only_is_retaken_by_it(self) -> None:
        campaign = _campaign(rules={"logistics_output": {}})
        state = initial_state(campaign)
        state.zones["Gudauta depot"].owner = "neutral"  # its only neighbour, Senaki, is red
        changes = play_turn(campaign, state)
        assert state.zones["Gudauta depot"].owner == "red"
        assert state.zones["Gudauta depot"].garrison is None  # drawn by the next mission
        assert {"kind": "counter_attack", "zone": "Gudauta depot", "side": "red"} in changes

    def test_a_neutral_zone_bordered_by_both_sides_stays_neutral(self) -> None:
        campaign = _campaign(rules={"logistics_output": {}})
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "neutral"  # between blue Kobuleti and red Gudauta depot
        play_turn(campaign, state)
        assert state.zones["Senaki"].owner == "neutral"

    def test_counter_attacks_do_not_cascade_within_one_turn(self) -> None:
        campaign = _campaign(rules={"logistics_output": {}})
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "neutral"
        state.zones["Gudauta depot"].owner = "neutral"
        play_turn(campaign, state)
        # Senaki has only blue Kobuleti as a held neighbour; Gudauta depot only neutral Senaki
        assert state.zones["Senaki"].owner == "blue"
        assert state.zones["Gudauta depot"].owner == "neutral"

    def test_counter_attacks_can_be_turned_off(self) -> None:
        campaign = _campaign(rules={"counter_attack": False})
        state = initial_state(campaign)
        state.zones["Gudauta depot"].owner = "neutral"
        play_turn(campaign, state)
        assert state.zones["Gudauta depot"].owner == "neutral"


class TestSayingAChange:
    """David, 2026-10-06: `Poti : neutral → red` and `réserve red : armor +2` read half in English."""

    def test_sides_and_categories_are_said_in_french(self) -> None:
        with language("fr"):
            owner = describe_change({"kind": "owner", "zone": "Poti", "from": "neutral", "to": "red"})
            logistics = describe_change(
                {
                    "kind": "logistics",
                    "zone": "Sochi",
                    "side": "red",
                    "added": {"armor": 2, "air_defense": 1, "transport": 0},
                }
            )
        assert owner == "Poti : neutre → rouge"
        assert logistics == "Sochi alimente la réserve rouge : blindés +2, défense aérienne +1"

    def test_and_in_english(self) -> None:
        with language("en"):
            owner = describe_change({"kind": "counter_attack", "zone": "Gali", "side": "blue"})
            logistics = describe_change(
                {
                    "kind": "logistics",
                    "zone": "Sochi",
                    "side": "red",
                    "added": {"armor": 2, "air_defense": 0, "transport": 1},
                }
            )
        assert owner == "Gali retaken by blue between missions"
        assert logistics == "Sochi feeds the red reserve: armour +2, transport +1"


@pytest.mark.parametrize(
    ("unit_type", "category"),
    [
        ("T-72B", "armor"),
        ("Paratrooper RPG-16", "armor"),
        ("Osa 9A33 ln", "air_defense"),
        ("Ural-375", "transport"),
        ("Mod X", "armor"),
    ],
)
def test_a_unit_type_falls_in_one_reserve_category(unit_type: str, category: str) -> None:
    assert reserve_category(unit_type) == category


# ---------------------------------------------------------------------------
# Victory
# ---------------------------------------------------------------------------


class TestObjectives:
    def test_nothing_met_at_the_start(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        assert [met for _, met in evaluate_objectives(campaign, state)] == [False, False]
        assert outcome(campaign, state) == "running"

    def test_a_capture_is_met_when_every_zone_is_the_players(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "blue"
        assert [met for _, met in evaluate_objectives(campaign, state)] == [True, False]

    def test_a_destroy_is_met_when_the_enemy_no_longer_holds_the_zone(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Gudauta depot"].owner = "neutral"
        assert [met for _, met in evaluate_objectives(campaign, state)] == [False, True]

    def test_every_objective_met_wins(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "blue"
        state.zones["Gudauta depot"].owner = "blue"
        assert outcome(campaign, state) == "won"

    def test_the_mission_count_reached_without_them_is_said(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.mission = campaign.missions
        assert outcome(campaign, state) == "out_of_missions"

    def test_a_red_player_side_turns_the_objectives_around(self) -> None:
        raw_campaign = _campaign()
        campaign = CampaignDefinition(**{**raw_campaign.__dict__, "player_side": "red"})
        state = initial_state(campaign)
        state.zones["Gudauta depot"].owner = "neutral"
        # Senaki is red already: captured for a red player; Gudauta depot is not held by blue
        assert [met for _, met in evaluate_objectives(campaign, state)] == [True, True]


def test_errors_are_errors() -> None:
    campaign = _campaign()
    current = initial_state(campaign)
    flown = _flown(current)
    flown.format_version = 99
    assert all(i.level == ERROR for i in validate_state_file(campaign, current, flown))
