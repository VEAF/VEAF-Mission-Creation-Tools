"""`set_route`: a flight plan written in one action (FIX-COWORK-SESSION-FINDINGS ticket 11).

The assistant wrote its route by search-and-replace in `waypoints.yaml`, computed each altitude by hand,
and named two points COAST: the second replaced the first and the route lost a point.
"""

from pathlib import Path
from typing import Any

import pytest
import yaml
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.coordinates import xy_to_latlon
from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.set_route import set_route
from waypoints_injector.waypoints_manager import WaypointsManager

SENAKI_COAST = {"name": "FEET WET", "x": -268000.0, "y": 603000.0}
PUSH = {"name": "PUSH", "x": -200000.0, "y": 450000.0}


class _Grid:
    """Ground at 100 m everywhere but at the coast point, at sea level."""

    def elevation_at(self, x: float, y: float) -> float | None:
        return 0.0 if (x, y) == (-268000.0, 603000.0) else 100.0


@pytest.fixture
def folder(tmp_path: Path, monkeypatch) -> Path:
    for relative, content in generate_blank_mission("Caucasus").items():
        path = tmp_path / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    (tmp_path / "src" / "waypoints.yaml").write_text(
        "# the maker's comment\nwaypoints:\n  KEEP:\n    type: Turning Point\n    action: Turning Point\n    alt: 0\n"
        "settings:\n  other:\n    coalition: red\n    waypoints:\n      - KEEP\n",
        encoding="utf-8",
    )
    import veaf_mission_mcp.set_route as module

    monkeypatch.setattr(module, "grid_for_theatre", lambda theatre: _Grid())
    return tmp_path


def _file(folder: Path) -> dict[str, Any]:
    return yaml.safe_load((folder / "src" / "waypoints.yaml").read_text(encoding="utf-8"))


def test_the_plan_and_its_points_are_written_on_the_ground(folder: Path) -> None:
    result = set_route(folder, plan="lion", points=[SENAKI_COAST, PUSH], aircraft_type="AJS37")
    data = _file(folder)
    keys = data["settings"]["lion"]["waypoints"]
    assert keys == ["LION_FEET_WET", "LION_PUSH"]
    assert data["settings"]["lion"]["type"] == "AJS37"
    assert data["settings"]["lion"]["coalition"] == "blue" and data["settings"]["lion"]["category"] == "plane"
    assert data["waypoints"]["LION_FEET_WET"]["name"] == "FEET WET"
    assert data["waypoints"]["LION_FEET_WET"]["alt"] == 0 and data["waypoints"]["LION_PUSH"]["alt"] == 100
    assert data["waypoints"]["LION_PUSH"]["alt_type"] == "BARO"
    assert "KEEP" in data["waypoints"] and "other" in data["settings"]
    assert "# the maker's comment" in (folder / "src" / "waypoints.yaml").read_text(encoding="utf-8")
    assert result["legs"] == [{"from": "FEET WET", "to": "PUSH", "heading": 294, "nm": 90}]
    assert Path(result["backup"]).is_file()


def test_the_injector_reads_what_it_wrote(folder: Path) -> None:
    set_route(folder, plan="lion", points=[SENAKI_COAST, PUSH])
    manager = WaypointsManager()
    manager.read_yaml(folder / "src" / "waypoints.yaml")
    plan = manager.get_flight_plan_for(coalition="blue", category="plane")
    assert plan is not None and [wp.name for wp in plan.waypoints] == ["FEET WET", "PUSH"]


def test_a_point_may_be_given_in_latitude_and_longitude(folder: Path) -> None:
    lat, lon = xy_to_latlon("Caucasus", -200000.0, 450000.0)
    set_route(folder, plan="lion", points=[SENAKI_COAST, {"name": "PUSH", "lat": lat, "lon": lon}])
    point = _file(folder)["waypoints"]["LION_PUSH"]
    assert abs(point["x"] + 200000.0) < 1 and abs(point["y"] - 450000.0) < 1


def test_two_points_with_one_name_are_refused(folder: Path) -> None:
    with pytest.raises(ValueError, match="COAST"):
        set_route(folder, plan="lion", points=[{**SENAKI_COAST, "name": "COAST"}, {**PUSH, "name": "Coast"}])


def test_a_point_without_a_position_is_refused(folder: Path) -> None:
    with pytest.raises(ValueError, match="position"):
        set_route(folder, plan="lion", points=[{"name": "NOWHERE"}])


def test_writing_the_plan_again_replaces_it_and_drops_its_old_points(folder: Path) -> None:
    set_route(folder, plan="lion", points=[SENAKI_COAST, PUSH])
    set_route(folder, plan="lion", points=[{**PUSH, "name": "IP"}])
    data = _file(folder)
    assert data["settings"]["lion"]["waypoints"] == ["LION_IP"]
    assert "LION_PUSH" not in data["waypoints"] and "LION_FEET_WET" not in data["waypoints"]
    assert "KEEP" in data["waypoints"]


def test_no_grid_writes_sea_level_and_says_so(folder: Path, monkeypatch) -> None:
    import veaf_mission_mcp.set_route as module

    monkeypatch.setattr(module, "grid_for_theatre", lambda theatre: None)
    result = set_route(folder, plan="lion", points=[PUSH])
    assert _file(folder)["waypoints"]["LION_PUSH"]["alt"] == 0
    assert any("elevation grid" in warning for warning in result["warnings"])


def test_the_action_runs_through_the_catalog(folder: Path) -> None:
    catalog = ActionCatalog()
    register_default_actions(catalog)
    result = catalog.run_action(
        "set_route", {"mission_path": str(folder), "plan": "lion", "points": [SENAKI_COAST, PUSH]}
    )
    assert result["plan"] == "lion" and len(result["points"]) == 2
