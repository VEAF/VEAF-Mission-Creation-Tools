"""`campaign next` writes the mission's objectives as waypoints (FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS ticket 01).

Found on *Kolkhida* mission 1: the mission folder carried the template's example `waypoints.yaml`, so every
blue plane got two steerpoints nowhere near the Colchis plain. David fixed it by hand: POTI, KHOBI, SENAKI
at 10 000 ft for the planes and 500 ft above the ground for the helicopters, in the briefing's order.
"""

from __future__ import annotations

import copy
import math
from pathlib import Path
from typing import Any

import yaml
from campaign_fixture import PROSE, VALID
from campaign_fixture import mission_template as _template
from campaign_manager.briefing_prose import MissionPage, Titled
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.campaign_worker import CAMPAIGN_FILE, CampaignWorker
from campaign_manager.models import CampaignDefinition, CampaignZone, ZoneLocation
from campaign_manager.next_mission import prepare_next_mission
from campaign_manager.objective_waypoints import (
    HELICOPTER_ALTITUDE,
    PLANE_ALTITUDE,
    WAYPOINTS_FILE,
    objective_waypoints,
    waypoint_keys,
    write_objective_waypoints,
)
from campaign_manager.strategic_map import zone_position
from veaf_libs.coordinates import latlon_to_xy
from waypoints_injector.waypoints_manager import WaypointsManager


def _campaign(**changes: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update(changes)
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _page(*titles: str) -> MissionPage:
    return MissionPage("Mission", tuple(Titled(title, ()) for title in titles))


def _plan(data: dict[str, Any], category: str) -> dict[str, Any]:
    return next(plan for plan in data["settings"].values() if plan["category"] == category)


def _load(folder: Path) -> WaypointsManager:
    manager = WaypointsManager()
    manager.read_yaml(folder / WAYPOINTS_FILE)
    return manager


class TestTheWaypoints:
    def test_without_tasks_the_campaigns_objectives_in_their_order(self) -> None:
        campaign = _campaign()
        data = objective_waypoints(campaign, None)
        assert _plan(data, "plane")["waypoints"] == ["SENAKI", "GUDAUTA"]

    def test_the_tasks_order_wins(self) -> None:
        campaign = _campaign()
        data = objective_waypoints(campaign, _page("Frapper Gudauta depot", "Prendre Senaki"))
        assert _plan(data, "plane")["waypoints"] == ["GUDAUTA", "SENAKI"]
        assert _plan(data, "helicopter")["waypoints"] == ["GUDAUTA_LOW", "SENAKI_LOW"]

    def test_each_waypoint_stands_on_its_zones_centre(self) -> None:
        campaign = _campaign()
        data = objective_waypoints(campaign, None)
        for key, zone in (("SENAKI", "Senaki"), ("GUDAUTA_LOW", "Gudauta depot")):
            x, y = latlon_to_xy(campaign.theatre, *zone_position(campaign, campaign.zone(zone)))
            assert (data["waypoints"][key]["x"], data["waypoints"][key]["y"]) == (round(x), round(y))

    def test_planes_cruise_and_helicopters_fly_low_under_the_same_name(self) -> None:
        data = objective_waypoints(_campaign(), None)
        plane, helicopter = data["waypoints"]["SENAKI"], data["waypoints"]["SENAKI_LOW"]
        assert (plane["alt"], plane["alt_type"]) == (PLANE_ALTITUDE, "BARO") == (3048, "BARO")
        assert (helicopter["alt"], helicopter["alt_type"]) == (HELICOPTER_ALTITUDE, "RADIO") == (152, "RADIO")
        assert plane["name"] == helicopter["name"] == "SENAKI"

    def test_the_plans_are_the_players_side(self) -> None:
        data = objective_waypoints(_campaign(player_side="red"), None)
        assert {plan["coalition"] for plan in data["settings"].values()} == {"red"}
        assert {plan["category"] for plan in data["settings"].values()} == {"plane", "helicopter"}


class TestTheKeys:
    def test_a_zones_first_word_in_capitals_without_accents(self) -> None:
        campaign = _campaign()
        zones = [campaign.zone("Gudauta depot"), campaign.zone("Senaki")]
        assert waypoint_keys(zones) == {"Gudauta depot": "GUDAUTA", "Senaki": "SENAKI"}

    def test_zones_sharing_a_first_word_keep_their_whole_names(self) -> None:
        names = ("Senaki", "Senaki north", "Dépôt d'Ochamchire")
        zones = [CampaignZone(name, ZoneLocation(lat=42.0, lon=42.0), "outpost", "red") for name in names]
        assert waypoint_keys(zones) == {
            "Senaki": "SENAKI",
            "Senaki north": "SENAKI_NORTH",
            "Dépôt d'Ochamchire": "DEPOT",
        }


class TestTheFile:
    def test_campaign_next_replaces_the_templates_example(self, tmp_path: Path) -> None:
        template = _template(tmp_path)
        (template / WAYPOINTS_FILE).write_text("waypoints:\n  HOLDING_POINT: {x: 75869, y: 48674}\n", encoding="utf-8")
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        manager = _load(tmp_path / "m1")
        assert "HOLDING_POINT" not in manager.waypoints
        plane = manager.get_flight_plan_for(coalition="blue", category="plane", aircraft_type="F-16C_50")
        helicopter = manager.get_flight_plan_for(coalition="blue", category="helicopter", aircraft_type="UH-1H")
        assert plane is not None and helicopter is not None
        assert [(wp.name, wp.alt) for wp in plane.waypoints] == [("SENAKI", 3048), ("GUDAUTA", 3048)]
        assert [(wp.name, wp.alt_type) for wp in helicopter.waypoints] == [("SENAKI", "RADIO"), ("GUDAUTA", "RADIO")]
        assert manager.get_flight_plan_for(coalition="red", category="plane") is None

    def test_the_mission_page_of_campaign_next_orders_them(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(
            campaign, initial_state(campaign), tmp_path, tmp_path / "m1", page=_page("Frapper Gudauta depot", "Senaki")
        )
        plane = _load(tmp_path / "m1").get_flight_plan_for(coalition="blue", category="plane")
        assert plane is not None
        assert [wp.name for wp in plane.waypoints] == ["GUDAUTA", "SENAKI"]

    def test_a_file_left_as_written_follows_a_second_run(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1", page=_page("Gudauta depot"))
        plane = _load(tmp_path / "m1").get_flight_plan_for(coalition="blue", category="plane")
        assert plane is not None
        assert [wp.name for wp in plane.waypoints] == ["GUDAUTA"]

    def test_a_file_edited_since_is_kept(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        path = tmp_path / "m1" / WAYPOINTS_FILE
        edited = path.read_text(encoding="utf-8").replace("alt: 3048", "alt: 6096")
        path.write_text(edited, encoding="utf-8")
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1", page=_page("Gudauta depot"))
        assert path.read_text(encoding="utf-8") == edited

    def test_a_hand_written_file_in_a_refreshed_folder_is_kept(self, tmp_path: Path) -> None:
        folder = tmp_path / "m1"
        (folder / "src").mkdir(parents=True)
        (folder / WAYPOINTS_FILE).write_text("waypoints: {}\n", encoding="utf-8")
        assert not write_objective_waypoints(_campaign(), None, folder, created=False)
        assert (folder / WAYPOINTS_FILE).read_text(encoding="utf-8") == "waypoints: {}\n"

    def test_a_folder_without_one_gets_it_on_a_refresh(self, tmp_path: Path) -> None:
        assert write_objective_waypoints(_campaign(), None, tmp_path, created=False)
        assert (tmp_path / WAYPOINTS_FILE).is_file()


class TestKolkhidaMissionOne:
    """What David wrote by hand on 2026-10-08, from the zones' centres read in the running mission."""

    def _kolkhida(self) -> CampaignDefinition:
        raw = {
            "campaign": {
                "name": "Kolkhida",
                "theatre": "Caucasus",
                "era": "MODERN",
                "missions": 3,
                "player_side": "blue",
                "objectives": [{"capture": ["Senaki"]}, {"destroy": {"zone": "Khobi depot", "kind": "logistics"}}],
            },
            "zones": [
                {"name": "Kobuleti", "at": {"airfield": "Kobuleti"}, "size": "airfield", "side": "blue"},
                {"name": "Poti", "at": {"lat": 42.150, "lon": 41.670}, "size": "outpost", "side": "neutral"},
                {
                    "name": "Khobi depot",
                    "display_name": "Dépôt de Khobi",
                    "at": {"lat": 42.315, "lon": 41.900},
                    "size": "outpost",
                    "side": "red",
                    "kind": "logistics",
                },
                {"name": "Senaki", "at": {"airfield": "Senaki-Kolkhi"}, "size": "airfield", "side": "red"},
            ],
            "connections": [["Kobuleti", "Poti"], ["Poti", "Senaki"], ["Poti", "Khobi depot"]],
        }
        campaign, issues = parse_campaign(raw)
        assert campaign is not None, issues
        return campaign

    def test_the_generator_writes_what_david_wrote(self) -> None:
        page = _page(
            "Prendre Poti — priorité 1",
            "Frapper le dépôt de Khobi — priorité 2",
            "Tenir le ciel — permanent",
            "Reconnaître Senaki — opportunité",
        )
        data = objective_waypoints(self._kolkhida(), page)
        assert _plan(data, "plane")["waypoints"] == ["POTI", "KHOBI", "SENAKI"]
        assert _plan(data, "helicopter")["waypoints"] == ["POTI_LOW", "KHOBI_LOW", "SENAKI_LOW"]
        by_hand = {"POTI": (-295152, 617091), "KHOBI": (-274838, 634185), "SENAKI": (-281903, 648379)}
        for key, (x, y) in by_hand.items():
            written = data["waypoints"][key]
            # a point zone lands on the metre; an airfield zone on the runways' centre, which DCS's
            # airbase point (what the runtime zone is centred on) sits 1.1 km from at Senaki
            tolerance = 1 if key != "SENAKI" else 1500
            assert math.dist((written["x"], written["y"]), (x, y)) <= tolerance, key


class TestTheWorker:
    def test_campaign_next_reads_the_missions_tasks_from_briefing_yaml(self, tmp_path: Path) -> None:
        (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
        _template(tmp_path)
        prose = copy.deepcopy(PROSE)
        prose["missions"] = {
            1: {
                "title": "Mission",
                "tasks": [
                    {"title": "Frapper Gudauta depot", "text": "Le dépôt."},
                    {"title": "Senaki", "text": "La base."},
                ],
            }
        }
        (tmp_path / "briefing.yaml").write_text(yaml.safe_dump(prose, allow_unicode=True), encoding="utf-8")
        worker = CampaignWorker(tmp_path)
        worker.init()
        issues, report = worker.next()
        assert report is not None and report.waypoints, issues
        plane = _load(report.folder).get_flight_plan_for(coalition="blue", category="plane")
        assert plane is not None
        assert [wp.name for wp in plane.waypoints] == ["GUDAUTA", "SENAKI"]

    def test_an_error_in_briefing_yaml_falls_back_to_the_objectives(self, tmp_path: Path) -> None:
        (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
        _template(tmp_path)
        (tmp_path / "briefing.yaml").write_text("situation: 12\n", encoding="utf-8")
        worker = CampaignWorker(tmp_path)
        worker.init()
        _, report = worker.next()
        assert report is not None
        plane = _load(report.folder).get_flight_plan_for(coalition="blue", category="plane")
        assert plane is not None
        assert [wp.name for wp in plane.waypoints] == ["SENAKI", "GUDAUTA"]
