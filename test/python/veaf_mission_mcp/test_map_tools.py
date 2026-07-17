"""Tests for describe_map + resolve_coordinates (FEAT-MCP-MISSION-EDITOR-032)."""

from pathlib import Path

import pytest
from veaf_libs import coordinates
from veaf_mission_mcp.map_tools import describe_map, resolve_coordinates


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
