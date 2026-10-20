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

    def test_each_group_carries_its_position_and_size(self, sample_miz: Path) -> None:
        """The demo mission read `src/mission/mission` by hand to find its groups (FIX-DEMO-MISSION-FINDINGS 07)."""
        from mission_tools.miz_tools import read_miz

        def values(container: object) -> list:
            return list(container.values()) if isinstance(container, dict) else list(container or [])

        content = read_miz(sample_miz).mission_content
        expected = {}
        for coalition in values(content["coalition"]):
            for country in values(coalition.get("country")):
                for category in ("plane", "helicopter", "vehicle", "ship", "static"):
                    for group in values((country.get(category) or {}).get("group")):
                        expected[group["name"]] = (group.get("x"), group.get("y"), len(values(group.get("units"))))

        result = describe_map(sample_miz)

        assert expected, "the sample mission has groups"
        assert {g["name"]: (g["x"], g["y"], g["units"]) for g in result["groups"]} == expected


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

        result = list_airfields(mission_path=sample_miz, details=True)
        assert result["theatre"] == "Caucasus"
        batumi = next(a for a in result["airfields"] if a["name"] == "Batumi")
        assert batumi["id"] == 22
        assert (batumi["x"], batumi["y"]) == pytest.approx(
            coordinates.latlon_to_xy("Caucasus", batumi["lat"], batumi["lon"]), abs=1
        )

    def test_a_theatre_can_be_named_without_a_mission(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        names = {a["name"] for a in list_airfields(theatre="GermanyCW")["airfields"]}
        assert {"Ramstein", "Laage"} <= names

    def test_an_unknown_theatre_is_refused(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        with pytest.raises(ValueError, match="Atlantis"):
            list_airfields(theatre="Atlantis")


class TestListAirfieldsWeight:
    """FIX-OPENCODE-TEST-FINDINGS 03 and 06: 37k characters for Syria, kept to the end of the session."""

    def test_the_default_answer_is_name_id_and_position_only(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        airfields = list_airfields(theatre="Syria")["airfields"]
        assert {tuple(sorted(a)) for a in airfields} == {("id", "name", "x", "y")}
        assert all(isinstance(a["x"], int) and isinstance(a["y"], int) for a in airfields)

    def test_the_default_answer_on_syria_stays_small(self) -> None:
        """Measured as a client receives it, indented JSON: 36 732 characters before, 20 605 after."""
        import json

        from veaf_mission_mcp.map_tools import list_airfields

        assert len(json.dumps(list_airfields(theatre="Syria"), indent=2)) < 22_000

    def test_details_give_parking_and_atc_frequencies_with_no_mission(self) -> None:
        """The AI read parking/Syria.json and airfield-frequencies.yaml in the exe's own files."""
        from veaf_mission_mcp.map_tools import list_airfields

        incirlik = list_airfields(theatre="Syria", details=True, name_contains="incirlik")["airfields"]
        assert [a["name"] for a in incirlik] == ["Incirlik"]
        assert incirlik[0]["atc"]["vhf"] == 122.1
        assert incirlik[0]["parking"]["planes"] > 0
        assert {"lat", "lon"} <= set(incirlik[0])

    def test_name_contains_filters(self) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        names = [a["name"] for a in list_airfields(theatre="Syria", name_contains="HAT")["airfields"]]
        assert "Hatay" in names
        assert all("hat" in name.lower() for name in names)

    def test_a_mission_gives_each_airfield_its_coalition(self, sample_miz: Path) -> None:
        from veaf_mission_mcp.map_tools import list_airfields

        airfields = list_airfields(mission_path=sample_miz)["airfields"]
        assert {a["coalition"] for a in airfields} <= {"red", "blue", "neutral"}


class TestCoordinatesWithoutAMission:
    """FIX-OPENCODE-TEST-FINDINGS 03: with no mission folder the AI fitted its own model, 5 km off."""

    def test_resolve_coordinates_takes_a_theatre(self) -> None:
        result = resolve_coordinates(None, {"lat": 37.0, "lon": 35.4}, theatre="syria")

        assert result["theatre"] == "Syria"
        assert (result["xy"]["x"], result["xy"]["y"]) == pytest.approx(coordinates.latlon_to_xy("Syria", 37.0, 35.4))

    def test_the_batch_takes_a_theatre(self) -> None:
        result = resolve_coordinates_batch(None, [{"x": 0.0, "y": 0.0}], theatre="Syria")

        assert result["theatre"] == "Syria" and len(result["points"]) == 1

    def test_neither_a_mission_nor_a_theatre_is_refused(self) -> None:
        with pytest.raises(ValueError, match="theatre"):
            resolve_coordinates(None, {"x": 0.0, "y": 0.0})

    def test_the_action_takes_a_theatre(self) -> None:
        from veaf_mission_mcp.server import CATALOG

        result = CATALOG.run_action("resolve_coordinates", {"theatre": "Syria", "position": {"x": 0.0, "y": 0.0}})
        assert result["theatre"] == "Syria"
