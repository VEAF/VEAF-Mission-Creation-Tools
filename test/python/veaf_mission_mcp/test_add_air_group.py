"""Tests for `add_air_group` — a flight on the ramp, parking resolved from the capture.

Uses Kobuleti (Caucasus airdrome id 24), which the bundled parking data covers, so the resolution path
runs against real captured stands rather than a mock.
"""

import zipfile
from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_air_group import add_air_group


def _caucasus_miz(tmp_path: Path, extra_group_lua: str = "") -> Path:
    """A minimal Caucasus `.miz`, optionally carrying an extra pre-placed group."""
    blue_country = '["country"] = { ' + extra_group_lua + " }"
    lua = (
        'mission = { ["theatre"] = "Caucasus", '
        '["coalition"] = { ["blue"] = { ' + blue_country + ' }, ["red"] = { ["country"] = { } } }, '
        '["coalitions"] = { ["blue"] = { }, ["red"] = { } } }'
    ).encode()
    path = tmp_path / "m.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", lua)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _slot_group(mission_content: dict, name: str) -> dict:
    for coalition in mission_content["coalition"].values():
        countries = coalition.get("country")
        for country in countries.values() if isinstance(countries, dict) else (countries or []):
            planes = (country.get("plane") or {}).get("group")
            for group in planes.values() if isinstance(planes, dict) else (planes or []):
                if group.get("name") == name:
                    return group
    raise AssertionError(f"group {name!r} not found")


def _units(group: dict) -> list:
    u = group["units"]
    return list(u.values()) if isinstance(u, dict) else u


class TestParkingStart:
    def test_a_two_ship_takes_two_stands(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Viper",
            unit_type="F-16C_50",
            count=2,
            start="parking-cold",
            airfield="Kobuleti",
        )
        assert result["airdrome_id"] == 24
        assert len(result["stands"]) == 2 and len(set(result["stands"])) == 2  # two distinct stands

        group = _slot_group(read_miz(miz).mission_content, "Viper")
        units = _units(group)
        assert len(units) == 2
        for unit in units:
            assert unit["parking"] == unit["parking_id"]  # parking_id = parking (measured 2026-08-15)
            assert unit["skill"] == "High"  # a ramp flight is AI by default
        wp = (
            group["route"]["points"]
            if isinstance(group["route"]["points"], list)
            else list(group["route"]["points"].values())
        )[0]
        assert (wp["type"], wp["action"]) == ("TakeOffParking", "From Parking Area")
        assert wp["airdromeId"] == 24 and wp["ETA_locked"] is True

    def test_hot_start_writes_the_hot_pair(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Viper",
            unit_type="F-16C_50",
            start="parking-hot",
            airfield="Kobuleti",
        )
        group = _slot_group(read_miz(miz).mission_content, "Viper")
        wp = (
            group["route"]["points"]
            if isinstance(group["route"]["points"], list)
            else list(group["route"]["points"].values())
        )[0]
        assert (wp["type"], wp["action"]) == ("TakeOffParkingHot", "From Parking Area Hot")

    def test_units_sit_on_aircraft_stands_only(self, tmp_path: Path) -> None:
        # Only terminal types 104/68 are offered; a unit never lands on a runway threshold (type 16).
        from veaf_libs.dcs_parking import stands_for_airbase

        by_number = {s.parking: s for s in stands_for_airbase("Caucasus", 24)}
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Viper",
            unit_type="F-16C_50",
            count=3,
            start="parking-cold",
            airfield="Kobuleti",
        )
        for spot in result["stands"]:
            assert by_number[spot].term_type in ("104", "68")


class TestRefusals:
    def test_an_unknown_airfield_is_refused(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        with pytest.raises(ValueError, match="unknown airfield"):
            add_air_group(
                miz,
                coalition="blue",
                country_id=2,
                country_name="USA",
                name="V",
                unit_type="F-16C_50",
                start="parking-cold",
                airfield="Nowhere",
            )

    def test_a_parking_start_without_an_airfield_is_refused(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        with pytest.raises(ValueError, match="airfield"):
            add_air_group(
                miz,
                coalition="blue",
                country_id=2,
                country_name="USA",
                name="V",
                unit_type="F-16C_50",
                start="parking-cold",
            )

    def test_an_occupied_stand_is_refused_naming_the_holder(self, tmp_path: Path) -> None:
        # Pre-place a group on Kobuleti stand "43", then request that exact stand.
        pre = (
            '[1] = { ["name"] = "USA", ["plane"] = { ["group"] = { [1] = { ["name"] = "Sitting Duck", '
            '["units"] = { [1] = { ["name"] = "sd1", ["parking"] = "43" } }, '
            '["route"] = { ["points"] = { [1] = { ["airdromeId"] = 24 } } } } } } }'
        )
        miz = _caucasus_miz(tmp_path, pre)
        with pytest.raises(ValueError, match="Sitting Duck"):
            add_air_group(
                miz,
                coalition="blue",
                country_id=2,
                country_name="USA",
                name="V",
                unit_type="F-16C_50",
                start="parking-cold",
                airfield="Kobuleti",
                parking=["43"],
            )

    def test_auto_selection_skips_an_occupied_stand(self, tmp_path: Path) -> None:
        pre = (
            '[1] = { ["name"] = "USA", ["plane"] = { ["group"] = { [1] = { ["name"] = "Parked", '
            '["units"] = { [1] = { ["name"] = "p1", ["parking"] = "1" } }, '
            '["route"] = { ["points"] = { [1] = { ["airdromeId"] = 24 } } } } } } }'
        )
        miz = _caucasus_miz(tmp_path, pre)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="V",
            unit_type="F-16C_50",
            count=1,
            start="parking-cold",
            airfield="Kobuleti",
        )
        assert "1" not in result["stands"]

    def test_an_explicit_parking_list_sets_the_flight_size(self, tmp_path: Path) -> None:
        # A count that disagrees with the parking list would index past the chosen stands; the list
        # wins, so two stands means two aircraft whatever count says.
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Pair",
            unit_type="F-16C_50",
            count=1,
            start="parking-cold",
            airfield="Kobuleti",
            parking=["15", "14"],
        )
        assert result["stands"] == ["15", "14"]
        assert len(_units(_slot_group(read_miz(miz).mission_content, "Pair"))) == 2

    def test_an_unknown_start_is_refused(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        with pytest.raises(ValueError, match="Unknown start"):
            add_air_group(
                miz,
                coalition="blue",
                country_id=2,
                country_name="USA",
                name="V",
                unit_type="F-16C_50",
                start="carrier",
            )


class TestAirAndRunway:
    def test_an_air_start_needs_no_airfield(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="CAP",
            unit_type="F-16C_50",
            count=2,
            start="air",
            position={"x": -300000.0, "y": 600000.0},
            altitude_ft=20000,
        )
        group = _slot_group(read_miz(miz).mission_content, "CAP")
        units = _units(group)
        assert len(units) == 2
        assert units[0]["alt"] == pytest.approx(6096.0)  # 20000 ft
        assert "parking" not in units[0]

    def test_an_air_start_without_a_position_is_refused(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        with pytest.raises(ValueError, match="position"):
            add_air_group(
                miz,
                coalition="blue",
                country_id=2,
                country_name="USA",
                name="CAP",
                unit_type="F-16C_50",
                start="air",
            )

    def test_a_runway_start_uses_the_field(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Scramble",
            unit_type="F-16C_50",
            start="runway",
            airfield="Kobuleti",
        )
        group = _slot_group(read_miz(miz).mission_content, "Scramble")
        wp = (
            group["route"]["points"]
            if isinstance(group["route"]["points"], list)
            else list(group["route"]["points"].values())
        )[0]
        assert (wp["type"], wp["action"]) == ("TakeOff", "From Runway")
        assert wp["airdromeId"] == 24


class TestCoalitions:
    def test_the_country_lands_in_coalitions(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Viper",
            unit_type="F-16C_50",
            start="parking-cold",
            airfield="Kobuleti",
        )
        content = read_miz(miz).mission_content
        assert content["coalitions"]["blue"] == [2]


class TestAircraftCategory:
    """A helicopter flight must land under `helicopter`, not `plane` (FIX-MCP-AIRCRAFT-CATEGORY).

    Found in game on 2026-08-16, by David opening a generated test mission in the Mission Editor:
    the two CTLD helicopter slots showed as AIRPLANE GROUP with `UH-1H` in red — unflyable. The
    action hard-coded `category="plane"`, and no assertion here looked at the category, so every
    test passed while every helicopter it produced was broken.
    """

    def _group_under(self, mission_content: dict, category: str, name: str) -> dict | None:
        for coalition in mission_content["coalition"].values():
            countries = coalition.get("country")
            for country in countries.values() if isinstance(countries, dict) else (countries or []):
                groups = (country.get(category) or {}).get("group")
                for group in groups.values() if isinstance(groups, dict) else (groups or []):
                    if group.get("name") == name:
                        return group
        return None

    def test_a_helicopter_flight_lands_under_helicopter(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Dustoff",
            unit_type="UH-1H",
            count=1,
            start="parking-cold",
            airfield="Kobuleti",
            skill="Client",
        )
        assert result["category"] == "helicopter"
        content = read_miz(miz).mission_content
        assert self._group_under(content, "helicopter", "Dustoff") is not None
        assert self._group_under(content, "plane", "Dustoff") is None

    def test_a_plane_flight_still_lands_under_plane(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Viper",
            unit_type="F-16C_50",
            count=1,
            start="parking-cold",
            airfield="Kobuleti",
        )
        assert result["category"] == "plane"
        assert self._group_under(read_miz(miz).mission_content, "plane", "Viper") is not None

    def test_an_unclassifiable_type_warns_instead_of_guessing_silently(self, tmp_path: Path) -> None:
        miz = _caucasus_miz(tmp_path)
        result = add_air_group(
            miz,
            coalition="blue",
            country_id=2,
            country_name="USA",
            name="Modded",
            unit_type="NoSuchModType",
            count=1,
            start="parking-cold",
            airfield="Kobuleti",
        )
        assert result["category"] == "plane"
        assert any("NoSuchModType" in w for w in result["warnings"])
