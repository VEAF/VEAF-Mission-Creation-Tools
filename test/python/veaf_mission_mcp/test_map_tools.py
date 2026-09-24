"""Tests for describe_map + resolve_coordinates (FEAT-MCP-MISSION-EDITOR-032)."""

from pathlib import Path

import pytest
from veaf_libs import coordinates
from veaf_mission_mcp.map_tools import describe_map, resolve_coordinates, resolve_coordinates_batch


class TestDescribeMap:
    def test_reports_theatre_bullseyes_and_reference_points(self, sample_miz: Path) -> None:
        result = describe_map(sample_miz)

        assert result["theatre"] == "Caucasus"
        # The sample mission has blue/red coalitions; describe_map surfaces their bullseyes
        # (empty dict entries if absent) and the existing zone/groups as reference points.
        assert "bullseyes" in result
        assert any(z["name"] == "combatZone_Test" for z in result["zones"])
        assert {g["coalition"] for g in result["groups"]} <= {"blue", "red", "neutrals"}


class TestResolveCoordinates:
    def test_xy_to_latlon_roundtrips(self, sample_miz: Path) -> None:
        result = resolve_coordinates(sample_miz, {"x": -291014.0, "y": 617414.0})

        assert result["theatre"] == "Caucasus"
        exp_lat, exp_lon = coordinates.xy_to_latlon("Caucasus", -291014.0, 617414.0)
        assert result["latlon"]["lat"] == exp_lat
        assert result["latlon"]["lon"] == exp_lon
        assert result["xy"] == {"x": -291014.0, "y": 617414.0}

    def test_latlon_to_xy(self, sample_miz: Path) -> None:
        result = resolve_coordinates(sample_miz, {"lat": 42.18654874, "lon": 41.67893429})

        exp_x, exp_y = coordinates.latlon_to_xy("Caucasus", 42.18654874, 41.67893429)
        assert result["xy"] == {"x": exp_x, "y": exp_y}

    def test_incomplete_position_raises(self, sample_miz: Path) -> None:
        with pytest.raises(ValueError, match="position"):
            resolve_coordinates(sample_miz, {"lat": 42.0})


class TestResolveCoordinatesBatch:
    """Ticket 19: one position per call, so placing a front of twenty points took twenty calls."""

    def test_each_position_is_converted_in_order(self, sample_miz: Path) -> None:
        positions = [{"x": -291014.0, "y": 617414.0}, {"lat": 42.18654874, "lon": 41.67893429}]
        result = resolve_coordinates_batch(sample_miz, positions)

        assert result["theatre"] == "Caucasus"
        assert [p["xy"] for p in result["points"]] == [
            resolve_coordinates(sample_miz, position)["xy"] for position in positions
        ]

    def test_a_bad_position_is_named_by_its_index(self, sample_miz: Path) -> None:
        with pytest.raises(ValueError, match=r"positions\[2\]"):
            resolve_coordinates_batch(sample_miz, [{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}, {"lat": 42.0}])


class TestResolveCoordinatesAction:
    def test_the_action_takes_a_list(self, sample_miz: Path) -> None:
        from veaf_mission_mcp.server import CATALOG

        result = CATALOG.run_action(
            "resolve_coordinates", {"mission_path": str(sample_miz), "positions": [{"x": 0.0, "y": 0.0}] * 3}
        )
        assert len(result["points"]) == 3

    def test_the_action_refuses_neither_and_both(self, sample_miz: Path) -> None:
        from veaf_mission_mcp.server import CATALOG

        for params in ({}, {"position": {"x": 0.0, "y": 0.0}, "positions": []}):
            with pytest.raises(ValueError, match="exactly one"):
                CATALOG.run_action("resolve_coordinates", {"mission_path": str(sample_miz), **params})


class TestListAirfields:
    """Ticket 19: the session read veaf_build/dcs_data/airbase_dumps/GermanyCW.json by hand."""

    def test_lists_the_mission_theatre_with_both_coordinates(self, sample_miz: Path) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        result = list_airfields(mission_path=sample_miz)
        assert result["theatre"] == "Caucasus"
        batumi = next(a for a in result["airfields"] if a["name"] == "Batumi")
        assert batumi["id"] == 22
        assert (batumi["x"], batumi["y"]) == pytest.approx(
            coordinates.latlon_to_xy("Caucasus", batumi["lat"], batumi["lon"])
        )

    def test_a_theatre_can_be_named_without_a_mission(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        names = {a["name"] for a in list_airfields(theatre="GermanyCW")["airfields"]}
        assert {"Ramstein", "Laage"} <= names

    def test_an_unknown_theatre_is_refused(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        with pytest.raises(ValueError, match="Atlantis"):
            list_airfields(theatre="Atlantis")
