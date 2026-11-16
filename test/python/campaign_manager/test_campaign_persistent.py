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
from campaign_manager.next_mission import add_campaign_cargo, hide_enemies_on_the_map, mission_data
from veaf_libs.mission_validator import ERROR, ValidationIssue


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
            "attacks": ["red"],
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
            "bombers": {"enabled": True, "seconds": 1800, "min_distance": 60000},
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
            ({"attacks": ["green"]}, "dynamic.attacks"),
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
            ({"economy": {"spawn_prices": {"cap": -1}}}, "dynamic.economy.spawn_prices"),
            ({"territory": {"enabled": "yes"}}, "dynamic.territory.enabled"),
        ],
    )
    def test_a_bad_setting_is_named(self, block: dict[str, Any], setting: str) -> None:
        campaign, issues = _parse(head={"mode": "persistent"}, dynamic=block)
        assert campaign is None
        assert any(f"`{setting}`" in message for message in _errors(issues))


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
