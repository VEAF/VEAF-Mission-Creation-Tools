"""The persistent mode of a campaign and its live play settings (FEAT-DYNAMIC-CAMPAIGN ticket 01).

A persistent campaign is one mission that saves and reloads itself. Its `campaign.yaml` says so with
`mode: persistent`, and sets the live play in `dynamic:`. The tools check that block, resolve each
aircraft's loadout by name into pylons, and pass the rest on to the runtime, whose defaults fill in
what the block leaves out.
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest
import yaml
from campaign_fixture import VALID, mission_template
from campaign_manager.campaign_manager import initial_state, parse_campaign, save_state
from campaign_manager.campaign_worker import CampaignWorker
from campaign_manager.dynamic_settings import DEFAULT_AIR
from campaign_manager.models import CampaignDefinition
from campaign_manager.next_mission import (
    add_campaign_cargo,
    hide_enemies_on_the_map,
    interpreter_commands,
    mission_data,
    prepare_next_mission,
    strategic_situation,
)
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.i18n import language, t
from veaf_libs.mission_validator import ERROR, ValidationIssue
from veaf_mission_mcp.airbase import set_airbase_coalition


def _parse(**changes: Any) -> tuple[CampaignDefinition | None, list[ValidationIssue]]:
    raw = copy.deepcopy(VALID)
    head = changes.pop("head", {})
    raw["campaign"].update(head)
    raw.update(changes)
    return parse_campaign(raw)


def _persistent(**changes: Any) -> CampaignDefinition:
    head = {"mode": "persistent", **changes.pop("head", {})}
    campaign, issues = _parse(head=head, **changes)
    assert campaign is not None, issues
    return campaign


def _errors(issues: list[ValidationIssue]) -> list[str]:
    return [issue.message for issue in issues if issue.level == ERROR]


class TestTheMode:
    def test_episodic_by_default(self) -> None:
        campaign, _ = _parse()
        assert campaign is not None
        assert campaign.mode == "episodic"

    def test_persistent_read(self) -> None:
        assert _persistent().mode == "persistent"

    def test_a_persistent_campaign_needs_no_objective(self) -> None:
        campaign, issues = _parse(head={"mode": "persistent", "objectives": []})
        assert campaign is not None
        assert issues == []

    def test_an_unknown_mode_is_refused(self) -> None:
        campaign, issues = _parse(head={"mode": "forever"})
        assert campaign is None
        assert any("forever" in message for message in _errors(issues))


class TestTheDynamicBlock:
    def test_absent_gives_the_shipped_aircraft_only(self) -> None:
        dynamic = _persistent().dynamic
        assert set(dynamic) == {"air"}
        assert set(dynamic["air"]) == {"blue", "red"}

    def test_valid_settings_are_passed_on_as_they_are(self) -> None:
        block = {
            "save_seconds": 30,
            "wake_radius": 50000,
            "ground_wake_radius": 8000,
            "reach_wake_margin": 15000,
            "front_depth": 30000,
            "takeoff_threat_range": 50000,
            "attacks": ["red"],
            "max_convoys": 3,
            "players_per_convoy": 3,
            "defended_radius": 25000,
            "helicopter": {"red": "Mi-8MT"},
            "supply_crate": "Zone supplies",
            "economy": {"start_credits": 800, "prices": {"jtac": 300}},
            "intel": {"hidden": False},
            "resources": {
                "enabled": True,
                "start": 800,
                "background_per_hour": 10,
                "reserve": 50,
                "prices": {"T-72B": 7},
            },
            "factory": {"buildings": 4, "per_hour": 90, "types": ["Workshop A"]},
            "network": {"hop_seconds": 300, "isolated_seconds": 1800, "depot_store": 2, "max_deliveries": 1},
            "demolition": {"troops": "Sapeurs", "range": 4000, "fuse": 90},
            "warehouse": {"enabled": False, "load": 5},
            "bombers": {"enabled": True, "seconds": 1800, "min_distance": 60000, "escort": True, "package_delay": 120},
            "debug": False,
            "debug_status_seconds": 600,
            "territory": {"enabled": True, "margin": 50000},
        }
        dynamic = _persistent(dynamic=block).dynamic
        for key, value in block.items():
            assert dynamic[key] == value

    @pytest.mark.parametrize(
        ("block", "setting"),
        [
            ({"wake_radius": 0}, "dynamic.wake_radius"),
            ({"wake_radius": True}, "dynamic.wake_radius"),
            ({"ground_wake_radius": 0}, "dynamic.ground_wake_radius"),
            ({"reach_wake_margin": -1}, "dynamic.reach_wake_margin"),
            ({"front_depth": 0}, "dynamic.front_depth"),
            ({"takeoff_threat_range": 0}, "dynamic.takeoff_threat_range"),
            ({"attacks": ["green"]}, "dynamic.attacks"),
            ({"players_per_convoy": 0}, "dynamic.players_per_convoy"),
            ({"defended_radius": -1}, "dynamic.defended_radius"),
            ({"helicopter": {"red": "MiG-29A"}}, "dynamic.helicopter"),
            ({"economy": {"start_credits": -1}}, "dynamic.economy.start_credits"),
            ({"economy": {"bank": 1}}, "dynamic.economy.bank"),
            ({"hunter": {"chance": 150}}, "dynamic.hunter.chance"),
            ({"intel": "yes"}, "dynamic.intel"),
            ({"weather": 1}, "dynamic.weather"),
            ({"resources": {"start": -5}}, "dynamic.resources.start"),
            ({"resources": {"prices": {"T-72B": "cheap"}}}, "dynamic.resources.prices"),
            ({"factory": {"types": []}}, "dynamic.factory.types"),
            ({"network": {"hop_seconds": 0}}, "dynamic.network.hop_seconds"),
            ({"economy": {"credits_per_point": 0}}, "dynamic.economy.credits_per_point"),
            ({"economy": {"upgrades_per_zone": -1}}, "dynamic.economy.upgrades_per_zone"),
            ({"economy": {"rescue": -1}}, "dynamic.economy.rescue"),
            ({"debug": "yes"}, "dynamic.debug"),
            ({"territory": {"enabled": "yes"}}, "dynamic.territory.enabled"),
        ],
    )
    def test_a_bad_setting_is_named(self, block: dict[str, Any], setting: str) -> None:
        campaign, issues = _parse(head={"mode": "persistent"}, dynamic=block)
        assert campaign is None
        assert any(f"`{setting}`" in message for message in _errors(issues))

    def test_the_rewards_of_foothold_are_settings(self) -> None:
        # FIX-CAMPAIGN-ECONOMY-BALANCE 01: a SAM, a building and a rescue each have their own reward
        economy = {"kill_sam": 40, "kill_building": 90, "rescue": 150}
        dynamic = _persistent(dynamic={"economy": economy}).dynamic
        assert {key: dynamic["economy"][key] for key in economy} == economy

    def test_the_upgrades_a_zone_holds_are_passed_on(self) -> None:
        # FEAT-CAMPAIGN-SHOP-UPGRADES 01: the shop's limit of bought upgrades per zone
        dynamic = _persistent(dynamic={"economy": {"upgrades_per_zone": 3}}).dynamic
        assert dynamic["economy"]["upgrades_per_zone"] == 3


class TestTheAircraft:
    def test_the_shipped_loadouts_resolve_to_pylons(self) -> None:
        air = _persistent().dynamic["air"]
        for side, roles in DEFAULT_AIR.items():
            for role, declared in roles.items():
                aircraft = air[side][role]
                assert aircraft["type"] == declared["type"]
                assert aircraft["count"] == declared["count"]
                assert aircraft["payload"]["pylons"], (side, role)
                assert aircraft["payload"]["fuel"] > 0
                assert all("CLSID" in pylon for pylon in aircraft["payload"]["pylons"].values())

    def test_a_declared_aircraft_replaces_the_shipped_one(self) -> None:
        air = {"red": {"cap": {"type": "Su-27", "loadout": "BetAB-500ShP*6,R-73*2,ECM", "count": 4}}}
        aircraft = _persistent(dynamic={"air": air}).dynamic["air"]["red"]["cap"]
        assert (aircraft["type"], aircraft["count"]) == ("Su-27", 4)

    def test_a_count_alone_keeps_the_shipped_type(self) -> None:
        aircraft = _persistent(dynamic={"air": {"red": {"cas": {"count": 4}}}}).dynamic["air"]["red"]["cas"]
        assert (aircraft["type"], aircraft["count"]) == ("Su-25", 4)

    def test_an_unknown_loadout_lists_the_type_s_loadouts(self) -> None:
        air = {"red": {"cas": {"loadout": "everything"}}}
        campaign, issues = _parse(head={"mode": "persistent"}, dynamic={"air": air})
        assert campaign is None
        message = next(m for m in _errors(issues) if "dynamic.air.red.cas" in m)
        assert "FAB-250*4,UB-13*2,R-60M*2,Fuel*2" in message

    def test_a_helicopter_is_not_a_strike_aircraft(self) -> None:
        campaign, issues = _parse(head={"mode": "persistent"}, dynamic={"air": {"red": {"cas": {"type": "Mi-8MT"}}}})
        assert campaign is None
        assert any("`dynamic.air.red.cas`" in m for m in _errors(issues))

    def test_air_settings(self) -> None:
        air = _persistent(dynamic={"air": {"strike_seconds": 600, "max_flights": 2}}).dynamic["air"]
        assert (air["strike_seconds"], air["max_flights"]) == (600, 2)


class TestTheDataTable:
    def test_a_persistent_mission_carries_its_mode_and_settings(self) -> None:
        campaign = _persistent(dynamic={"wake_radius": 40000})
        data = mission_data(campaign, initial_state(campaign))
        assert data["persistent"] is True
        assert data["player_side"] == "blue"
        assert data["dynamic"]["wake_radius"] == 40000

    def test_an_episodic_mission_carries_neither(self) -> None:
        campaign, _ = _parse()
        assert campaign is not None
        data = mission_data(campaign, initial_state(campaign))
        assert "persistent" not in data
        assert "dynamic" not in data

    def test_a_persistent_side_without_reserve_draws_for_free(self) -> None:
        campaign = _persistent(sides={"red": {"reserve": {"armor": 3}}})
        sides = mission_data(campaign, initial_state(campaign))["sides"]
        assert sides["red"] == {"reserve": {"armor": 3, "air_defense": 0, "transport": 0}}
        assert sides["blue"] == {}

    def test_an_episodic_side_always_counts_its_reserve(self) -> None:
        campaign, _ = _parse()
        assert campaign is not None
        assert mission_data(campaign, initial_state(campaign))["sides"]["blue"] == {
            "reserve": {"armor": 0, "air_defense": 0, "transport": 0}
        }


class TestApply:
    def test_a_persistent_campaign_has_nothing_to_apply(self, tmp_path: Path) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["mode"] = "persistent"

        (tmp_path / "campaign.yaml").write_text(yaml.safe_dump(raw), encoding="utf-8")
        mission_template(tmp_path)
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        save_state(initial_state(campaign), tmp_path / "campaign-state.yaml")
        issues, report = CampaignWorker(tmp_path).apply(tmp_path / "anything.state")
        assert report is None
        assert any("persistent" in message.lower() or "persistante" in message.lower() for message in _errors(issues))


class TestTheCampaignCargo:
    def _ctld(self, folder: Path, crates: dict[str, Any] | None = None, groups: list[Any] | None = None) -> Path:
        path = folder / "ctld-config.yaml"
        document = {
            "configVersion": "2.3.0",
            "mm_facing": {
                "spawnableCrates": crates
                if crates is not None
                else {"Combat Vehicles": [{"unit": "LAV-25", "desc": "LAV", "weight": 1000.04}]},
                "loadableGroups": groups if groups is not None else [{"name": "Standard Group", "inf": 6}],
            },
        }
        path.write_text(yaml.safe_dump(document), encoding="utf-8")
        return path

    def test_the_supply_crate_and_the_spy_and_demolition_teams_are_added(self, tmp_path: Path) -> None:
        path = self._ctld(tmp_path)
        assert add_campaign_cargo(tmp_path, {}) == ["Zone supplies", "Spy", "Sappers"]
        facing = yaml.safe_load(path.read_text(encoding="utf-8"))["mm_facing"]
        crates = facing["spawnableCrates"]["Campaign"]
        assert [(c["desc"], c["side"]) for c in crates] == [("Zone supplies", 2), ("Zone supplies", 1)]
        assert facing["spawnableCrates"]["Combat Vehicles"][0]["desc"] == "LAV"
        assert {"name": "Spy", "inf": 1} in facing["loadableGroups"]
        assert {"name": "Sappers", "inf": 2} in facing["loadableGroups"]

    def test_the_names_follow_the_settings(self, tmp_path: Path) -> None:
        self._ctld(tmp_path)
        dynamic = {"supply_crate": "Caisse", "intel": {"spy_troops": "Espion"}, "demolition": {"troops": "Sapeurs"}}
        assert add_campaign_cargo(tmp_path, dynamic) == ["Caisse", "Espion", "Sapeurs"]

    def test_a_second_run_adds_nothing(self, tmp_path: Path) -> None:
        self._ctld(tmp_path)
        add_campaign_cargo(tmp_path, {})
        assert add_campaign_cargo(tmp_path, {}) == []

    def test_crate_weights_clash_with_none_of_the_shipped_ones(self) -> None:
        from campaign_manager.next_mission import SUPPLY_CRATES
        from veaf_libs.ctld_config import read_default_config

        text = read_default_config(Path(__file__).resolve().parents[3] / "src" / "scripts" / "community" / "CTLD.lua")
        assert text is not None
        shipped = yaml.safe_load(text)
        weights = {c.get("weight") for section in shipped["mm_facing"]["spawnableCrates"].values() for c in section}
        assert not weights & {crate["weight"] for crate in SUPPLY_CRATES}

    def test_a_mission_without_ctld_is_left_alone(self, tmp_path: Path) -> None:
        assert add_campaign_cargo(tmp_path, {}) == []


class TestTheF10View:
    def test_the_enemy_is_hidden_on_the_map(self, tmp_path: Path) -> None:
        path = tmp_path / "mission.yaml"
        path.write_text("# kept\nmission:\n  name: Front\n", encoding="utf-8")
        assert hide_enemies_on_the_map(path)
        text = path.read_text(encoding="utf-8")
        assert yaml.safe_load(text)["mission"]["forced_options"] == {"f10_view": "fog_of_war"}
        assert "# kept" in text

    def test_a_view_the_mission_chose_is_kept(self, tmp_path: Path) -> None:
        path = tmp_path / "mission.yaml"
        path.write_text("mission:\n  forced_options:\n    f10_view: allies_only\n", encoding="utf-8")
        assert not hide_enemies_on_the_map(path)
        assert (
            yaml.safe_load(path.read_text(encoding="utf-8"))["mission"]["forced_options"]["f10_view"] == "allies_only"
        )


class TestTheInterpreterInAPersistentCampaign:
    """What the interpreter spawns comes back whole at every restart, outside the save (David, 2026-11-16)."""

    def _mission(self, folder: Path) -> Path:
        (folder / "src" / "mission").mkdir(parents=True, exist_ok=True)
        # the mission file escapes the name's quotes, as DCS writes it
        (folder / "src" / "mission" / "mission").write_text(
            r'["name"] = "#veafInterpreter[\"-samLR\"]",' + "\n" + r'["name"] = "plain",' + "\n"
            r'["name"] = "#veafInterpreter[\"_spawn armoredPlatoon\"]",' + "\n",
            encoding="utf-8",
        )
        (folder / "src" / "spawn-groups.yaml").write_text("- name: '#veafInterpreter[\"-samLR\"]'\n", encoding="utf-8")
        (folder / "src" / "scripts").mkdir(exist_ok=True)
        (folder / "src" / "scripts" / "veaf-config.lua").write_text('veafInterpreter["x"] = 1\n', encoding="utf-8")
        return folder

    def test_its_commands_are_found_each_once(self, tmp_path: Path) -> None:
        assert interpreter_commands(self._mission(tmp_path)) == ["-samLR", "_spawn armoredPlatoon"]

    def test_a_mission_without_any_has_none(self, tmp_path: Path) -> None:
        assert interpreter_commands(tmp_path) == []

    def test_campaign_next_reports_them_for_a_persistent_campaign_only(self, tmp_path: Path) -> None:
        template = mission_template(tmp_path)
        # in a YAML source only: the template's mission file is a real one, which campaign next reads
        (template / "src" / "spawn-groups.yaml").write_text(
            "- name: '#veafInterpreter[\"-samLR\"]'\n", encoding="utf-8"
        )
        persistent = _persistent()
        report = prepare_next_mission(persistent, initial_state(persistent), tmp_path, tmp_path / "m1")
        assert report.interpreter_commands == ["-samLR"]
        episodic, _ = _parse()
        assert episodic is not None
        report = prepare_next_mission(episodic, initial_state(episodic), tmp_path, tmp_path / "m2")
        assert report.interpreter_commands == []


class TestTheStrategicSituation:
    """Found on the Syria campaign (2026-11-16): the text, which is also the mission's DCS briefing, read
    "mission 1 sur 10", "Réserve ennemie : 0 blindés" and "10 mission(s) prévue(s) restante(s)"."""

    def _text(self) -> str:
        raw_zones = copy.deepcopy(VALID["zones"])
        raw_zones[1]["display_name"] = "Base de Senaki"
        campaign = _persistent(head={"objectives": []}, zones=raw_zones)
        with language("fr"):
            return strategic_situation(campaign, initial_state(campaign))

    def test_no_count_of_missions_nor_reserve(self) -> None:
        text = self._text()
        assert text.startswith("SITUATION STRATÉGIQUE — campagne persistante")
        assert "Réserve ennemie" not in text
        assert "mission(s) prévue(s)" not in text
        assert "gagnée quand l'ennemi ne tient plus aucune zone" in text

    def test_the_zones_go_by_the_name_the_players_read(self) -> None:
        assert "Tenu par les rouges : Base de Senaki" in self._text()

    def test_objectives_met_do_not_win_a_persistent_campaign(self) -> None:
        campaign = _persistent()
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "blue"
        state.zones["Gudauta depot"].owner = "blue"
        with language("fr"):
            text = strategic_situation(campaign, state)
        assert "La campagne est gagnée." not in text
        assert "[x]" not in text and "[ ]" not in text
        assert "gagnée quand l'ennemi ne tient plus aucune zone" in text


class TestTheMissionFile:
    """FEAT-CAMPAIGN-MISSION-FILE: the server browser shows the file name, and a dated one changes at every redeploy."""

    def test_absent_leaves_the_computed_name(self) -> None:
        assert _persistent().mission_file is None

    @pytest.mark.parametrize("value", ["Campagne_Oronte", "Campagne_Oronte.miz", "Campagne_Oronte.MIZ"])
    def test_a_plain_name_is_read_without_its_extension(self, value: str) -> None:
        assert _persistent(head={"mission_file": value}).mission_file == "Campagne_Oronte"

    @pytest.mark.parametrize(
        "value",
        ["Campagne Oronte", "missions/Campagne_Oronte", "Campagne_Oronte.txt", "Campagné", ".miz", "", 12],
    )
    def test_anything_but_a_plain_file_name_is_refused(self, value: Any) -> None:
        campaign, issues = _parse(head={"mode": "persistent", "mission_file": value})
        assert campaign is None
        assert t("campaign.issue.bad_mission_file", value=value) in _errors(issues)

    def test_a_multi_mission_campaign_is_refused(self) -> None:
        # each of its missions needs `_NoMizedit` in its file name, and its own file
        campaign, issues = _parse(head={"mission_file": "Campagne_Oronte"})
        assert campaign is None
        assert t("campaign.issue.mission_file_needs_persistent") in _errors(issues)

    def test_campaign_next_names_the_mission_and_turns_the_date_off(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        campaign = _persistent(head={"mission_file": "Campagne_Oronte.miz"})
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert report.name == "Campagne_Oronte"
        mission = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))["mission"]
        assert mission["name"] == "Campagne_Oronte"
        assert mission["date_suffix"] is False

    def test_a_campaign_without_it_gives_the_date_back(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        named = _persistent(head={"mission_file": "Campagne_Oronte"})
        prepare_next_mission(named, initial_state(named), tmp_path, tmp_path / "m1")
        campaign = _persistent()
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        mission = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))["mission"]
        assert mission["name"] == report.name != "Campagne_Oronte"
        assert "date_suffix" not in mission


class TestEveryAirfieldOffersSlots:
    """FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 01: Minakh, neutral at build, captured by blue in flight, offered no
    slot — the build had opened Dynamic Slots on the airbases each side owned at build time only."""

    @staticmethod
    def _warehouses(folder: Path) -> dict[str, Any]:
        return yaml.safe_load((folder / "src" / "warehouses.yaml").read_text(encoding="utf-8"))

    def test_the_player_side_lists_every_airfield_zone_whatever_its_owner(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        campaign = _persistent()
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        data = self._warehouses(tmp_path / "m1")
        # Senaki-Kolkhi is red at start: blue gets its slots there the moment it is captured
        assert data["blue"]["airports"] == {"Kobuleti": {}, "Senaki-Kolkhi": {}}
        assert report.slot_airbases == ["Kobuleti", "Senaki-Kolkhi"]
        assert "airports" not in data["red"]

    def test_an_airfield_set_up_by_hand_keeps_its_settings(self, tmp_path: Path) -> None:
        template = mission_template(tmp_path)
        path = template / "src" / "warehouses.yaml"
        path.write_text(
            "# the maker's comment\nblue:\n  airports:\n    Kobuleti: { hot_start: false }\n", encoding="utf-8"
        )
        campaign = _persistent()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        written = (tmp_path / "m1" / "src" / "warehouses.yaml").read_text(encoding="utf-8")
        assert "# the maker's comment" in written
        assert yaml.safe_load(written)["blue"]["airports"] == {"Kobuleti": {"hot_start": False}, "Senaki-Kolkhi": {}}

    def test_a_base_of_the_side_outside_the_campaign_keeps_its_slots(self, tmp_path: Path) -> None:
        # an explicit list replaces "every base of the side": a rear base set in the template must be in it too
        template = mission_template(tmp_path)
        set_airbase_coalition(template, name="Batumi", coalition="blue")
        campaign = _persistent()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        airports = self._warehouses(tmp_path / "m1")["blue"]["airports"]
        assert airports == {"Kobuleti": {}, "Senaki-Kolkhi": {}, airdrome_id_for_name("Caucasus", "Batumi"): {}}

    def test_a_side_the_file_does_not_declare_is_left_closed(self, tmp_path: Path) -> None:
        template = mission_template(tmp_path)
        (template / "src" / "warehouses.yaml").write_text("red:\n  defaults: {}\n", encoding="utf-8")
        campaign = _persistent()
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert self._warehouses(tmp_path / "m1") == {"red": {"defaults": {}}}
        assert report.slot_airbases == []

    def test_an_episodic_campaign_keeps_the_owners_at_build(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        episodic, _ = _parse()
        assert episodic is not None
        report = prepare_next_mission(episodic, initial_state(episodic), tmp_path, tmp_path / "m1")
        assert "airports" not in self._warehouses(tmp_path / "m1")["blue"]
        assert report.slot_airbases == []
