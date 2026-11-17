"""A side's supply network read for the players (FEAT-DYNAMIC-CAMPAIGN ticket 20, the theatre dossier)."""

from __future__ import annotations

from typing import Any

from campaign_manager.campaign_manager import parse_campaign
from campaign_manager.models import CampaignDefinition
from campaign_manager.network import network_picture


def _campaign() -> CampaignDefinition:
    # red: Factory - Hub - Front, Hub - Depot; Front also borders blue's Base
    def zone(name: str, side: str, lat: float, kind: str | None = None) -> dict[str, Any]:
        entry: dict[str, Any] = {"name": name, "at": {"lat": lat, "lon": 41.0}, "size": "outpost", "side": side}
        if kind:
            entry["kind"] = kind
        return entry

    raw = {
        "campaign": {"name": "Net", "theatre": "Caucasus", "mode": "persistent", "objectives": []},
        "zones": [
            zone("Base", "blue", 42.0),
            zone("Front", "red", 42.3),
            zone("Hub", "red", 42.6),
            zone("Factory", "red", 42.9, "factory"),
            zone("Depot", "red", 42.6, "depot"),
            zone("Island", "red", 43.2),
        ],
        "connections": [["Base", "Front"], ["Front", "Hub"], ["Hub", "Factory"], ["Hub", "Depot"], ["Base", "Island"]],
    }
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _owners(campaign: CampaignDefinition) -> dict[str, str]:
    return {zone.name: zone.side for zone in campaign.zones}


class TestTheNetwork:
    def test_what_each_factory_and_depot_feeds(self) -> None:
        campaign = _campaign()
        picture = network_picture(campaign, _owners(campaign), "red")
        assert picture.factories == {"Factory": ("Front", "Hub", "Depot")}
        assert picture.depots == {"Depot": ("Hub",)}
        assert picture.cut_off == ("Island",)

    def test_taking_the_hub_cuts_the_front_and_the_depot_off(self) -> None:
        campaign = _campaign()
        picture = network_picture(campaign, _owners(campaign), "red")
        assert [(node.zone, node.isolated) for node in picture.critical] == [
            ("Hub", ("Front", "Depot")),
            ("Factory", ("Front", "Hub", "Depot")),
        ][::-1]

    def test_a_side_with_no_factory_has_everything_cut_off(self) -> None:
        campaign = _campaign()
        picture = network_picture(campaign, _owners(campaign), "blue")
        assert picture.factories == {}
        assert picture.cut_off == ("Base",)
        assert picture.critical == ()


class TestTheTerritory:
    """David, 2026-11-17: the front a thin line and the territory hatched, as on the F10 map — not 6-px blocks."""

    def test_each_zone_holds_what_is_nearer_to_it_and_the_front_runs_between_two_owners(self) -> None:
        from campaign_manager.network_map import front_segments, territory_cells

        centres = {"A": (100.0, 100.0), "B": (300.0, 100.0), "C": (350.0, 150.0)}
        cells = territory_cells(centres, 400, 200)
        xs = [x for (x, _), _ in cells["A"]]
        assert max(xs) == 200 and min(xs) == 0, "A's cell runs to the bisector with B"
        segments = front_segments(cells, {"A": "blue", "B": "red", "C": "red"})
        # B and C share a side: no front between them, one straight front between A and B
        assert segments == [((200.0, 0.0), (200.0, 200.0))] or segments == [((200.0, 200.0), (200.0, 0.0))]

    def test_no_front_inside_one_side(self) -> None:
        from campaign_manager.network_map import front_segments, territory_cells

        cells = territory_cells({"A": (100.0, 100.0), "B": (300.0, 100.0)}, 400, 200)
        assert front_segments(cells, {"A": "blue", "B": "blue"}) == []


class TestTheNetworkMap:
    def test_drawn_with_numbers_tint_and_circles_at_the_kneeboard_aspect(self, tmp_path: Any) -> None:
        from campaign_manager.network_map import ReachCircle, kind_of, render_network_map
        from PIL import Image

        campaign = _campaign()
        report = render_network_map(
            campaign,
            _owners(campaign),
            tmp_path / "network.png",
            numbers={"Front": 1, "Hub": 2},
            circles=[ReachCircle(42.9, 41.0, 75000, (192, 57, 43), "SA-10 ?")],
            aspect=2 / 3,
            cache_dir=tmp_path,
            fetch=lambda _url: None,
        )
        with Image.open(report.path) as image:
            assert abs(image.width / image.height - 2 / 3) < 0.08
        assert len(report.labels) == len(campaign.zones)
        assert [kind_of(zone) for zone in campaign.zones] == [
            "outpost",
            "outpost",
            "outpost",
            "factory",
            "depot",
            "outpost",
        ]
