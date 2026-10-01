"""Tests for the `terrain_elevation` MCP action."""

import sys
from pathlib import Path

import pytest
from veaf_libs.terrain_elevation import save_grid
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.terrain import describe_terrain

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "veaf_libs"))
from test_terrain_elevation import _ridge  # noqa: E402


@pytest.fixture
def caucasus(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    save_grid(_ridge(), tmp_path / "home" / "terrain" / "Caucasus.terrain")


def test_with_no_grid_it_says_how_to_sweep_one(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("VEAF_HOME", str(tmp_path / "home"))
    answer = describe_terrain("NoSuchTheatre", points=[{"x": 0, "y": 0}])
    assert answer["available"] is False
    assert "terrain-sweep NoSuchTheatre" in answer["how"]


def test_points_get_metres_and_feet_and_off_the_grid_is_null(caucasus) -> None:
    answer = describe_terrain("Caucasus", points=[{"x": -275000, "y": 685000}, {"x": 0, "y": 0}])
    assert answer["available"] and "Terrain only" in answer["caveat"]
    assert answer["points"][0]["ground"] == {"m": 1000, "ft": 3281}
    assert answer["points"][1]["ground"] is None


def test_a_route_gets_its_legs_and_with_observers_its_exposure(caucasus) -> None:
    route = [
        {"x": -271000, "y": 681000, "alt": 50, "alt_type": "RADIO"},
        {"x": -271000, "y": 689000, "alt": 50, "alt_type": "RADIO"},
    ]
    sam = {"name": "SA-6", "x": -279000, "y": 685000, "range": 20000}
    answer = describe_terrain("Caucasus", route=route, observers=[sam])
    assert answer["legs"] == [{"leg": "0-1", "length_m": 8000, "highest": {"m": 100, "ft": 328}, "covered": True}]
    assert answer["exposure"][0]["observer"] == "SA-6"
    assert answer["exposure"][0]["legs"][0]["seen_m"] == 0


def test_observers_without_a_route_are_refused(caucasus) -> None:
    with pytest.raises(ValueError, match="route"):
        describe_terrain("Caucasus", observers=[{"x": 0, "y": 0, "range": 1}])


def test_an_area_gets_its_maxima_per_cell(caucasus) -> None:
    area = {"min_x": -280000, "min_y": 680000, "max_x": -270000, "max_y": 690000}
    cells = describe_terrain("Caucasus", area=area)["cells"]
    assert max(c["highest"]["m"] for c in cells) == 1000
    with pytest.raises(ValueError, match="cell"):
        describe_terrain("Caucasus", area={**area, "cell": "hexagon"})


def test_the_action_is_registered(caucasus) -> None:
    from veaf_mission_mcp.actions import register_default_actions

    catalog = ActionCatalog()
    register_default_actions(catalog)
    result = catalog.run_action("terrain_elevation", {"theatre": "Caucasus", "points": [{"x": -275000, "y": 685000}]})
    assert result["points"][0]["ground"]["m"] == 1000


def test_observers_need_every_route_altitude(caucasus) -> None:
    route = [{"x": -271000, "y": 681000}, {"x": -271000, "y": 689000, "alt": 50}]
    with pytest.raises(ValueError, match=r"\[0\] have no alt"):
        describe_terrain("Caucasus", route=route, observers=[{"x": -279000, "y": 685000, "range": 20000}])
    # Without observers the altitudes are not needed.
    assert describe_terrain("Caucasus", route=route)["legs"]
