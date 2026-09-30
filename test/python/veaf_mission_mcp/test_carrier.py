"""`add_carrier_group` and deck starts — FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 02."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_air_group import add_air_group
from veaf_mission_mcp.carrier import add_carrier_group

_BLUE = {"coalition": "blue", "country_id": 2, "country_name": "USA"}


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    lua = (
        b'mission = { ["theatre"] = "Caucasus", ["coalition"] = { ["blue"] = { ["country"] = { } }, '
        b'["red"] = { ["country"] = { } } }, ["coalitions"] = { ["blue"] = { }, ["red"] = { } } }'
    )
    path = tmp_path / "m.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", lua)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b'warehouses = { ["airports"] = { }, ["warehouses"] = { } }\n')
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _groups(miz: Path, category: str) -> dict[str, dict[str, Any]]:
    content = read_miz(miz).mission_content or {}
    return {
        g["name"]: g
        for country in content["coalition"]["blue"]["country"]
        for g in (country.get(category) or {}).get("group") or []
    }


def _actions(tasks: Any) -> dict[str, dict[str, Any]]:
    entries = tasks.values() if isinstance(tasks, dict) else tasks
    return {t["params"]["action"]["id"]: t["params"]["action"]["params"] for t in entries}


def _stennis(miz: Path, **extra: Any) -> dict[str, Any]:
    return add_carrier_group(
        miz, name="CSG-74 Stennis", position={"x": -300000.0, "y": 500000.0}, heading_deg=90, **_BLUE, **extra
    )


class TestTheCarrierGroup:
    def test_the_atc_is_written_on_the_route_and_on_the_group(self, miz: Path) -> None:
        result = _stennis(miz, tacan_channel=74, tacan_callsign="stn", icls_channel=7, link4_mhz=336.0)
        group = _groups(miz, "ship")["CSG-74 Stennis"]
        unit_id = result["carrier_unit_id"]
        assert group["units"][0]["unitId"] == unit_id
        on_route = _actions(group["route"]["points"][0]["task"]["params"]["tasks"])
        assert on_route == _actions(group["tasks"])
        assert on_route["ActivateBeacon"] == {
            "type": 4,
            "system": 3,
            "AA": False,
            "unitId": unit_id,
            "modeChannel": "X",
            "channel": 74,
            "callsign": "STN",
            "bearing": True,
            "frequency": 1161000000,  # 74X: 1087 + 74 MHz
        }
        assert on_route["ActivateICLS"] == {"type": 131584, "unitId": unit_id, "channel": 7}
        assert on_route["ActivateLink4"] == {"frequency": 336000000, "unitId": unit_id}
        assert on_route["ActivateACLS"] == {"unitId": unit_id}

    def test_the_tower_is_on_the_carrier_unit_and_the_group_sails(self, miz: Path) -> None:
        _stennis(miz, tower_mhz=127.5, speed_kt=20)
        group = _groups(miz, "ship")["CSG-74 Stennis"]
        assert (group["units"][0]["frequency"], group["units"][0]["modulation"]) == (127500000, 0)
        start, ahead = group["route"]["points"]
        assert ahead["y"] > start["y"] and ahead["x"] == pytest.approx(start["x"])  # heading 090: east
        assert start["ETA_locked"] is True and ahead["speed"] == pytest.approx(20 * 0.514444)

    def test_the_warehouse_is_keyed_by_the_carrier_unit(self, miz: Path) -> None:
        result = _stennis(miz)
        table = (read_miz(miz).warehouses_content or {})["warehouses"]
        # The parser hands a table keyed 1..n back as a list; DCS keys it by unit id either way.
        entries = dict(enumerate(table, start=1)) if isinstance(table, list) else table
        assert entries[result["carrier_unit_id"]]["coalition"] == "blue"

    def test_the_tanker_and_pedro_carry_the_names_the_script_looks_for(self, miz: Path) -> None:
        _stennis(miz, carrier_name="CVN-74")
        planes, helis = _groups(miz, "plane"), _groups(miz, "helicopter")
        tanker, pedro = planes["CVN-74 S3B-Tanker"], helis["CVN-74 Pedro"]
        assert tanker["units"][0]["name"] == "CVN-74 S3B-Tanker" and tanker["units"][0]["type"] == "S-3B Tanker"
        assert pedro["units"][0]["name"] == "CVN-74 Pedro"
        tasks = tanker["route"]["points"][0]["task"]["params"]["tasks"]
        entries = list(tasks.values()) if isinstance(tasks, dict) else tasks
        assert entries[0]["id"] == "Tanker"
        assert entries[1]["params"]["action"]["params"]["modeChannel"] == "Y"

    def test_no_link4_on_a_deck_without_arresting_gear(self, miz: Path) -> None:
        result = add_carrier_group(miz, name="LHA-1", carrier_type="LHA_Tarawa", position={"x": 0.0, "y": 0.0}, **_BLUE)
        assert "Link4" not in str(_actions(_groups(miz, "ship")["LHA-1"]["tasks"]))
        assert any("arresting gear" in w for w in result["warnings"])

    def test_an_unknown_carrier_type_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="carrier_type"):
            add_carrier_group(miz, name="X", carrier_type="PERRY", position={"x": 0.0, "y": 0.0}, **_BLUE)


class TestDeckSlots:
    def test_slots_are_linked_to_the_ship_and_numbered_on_the_deck(self, miz: Path) -> None:
        result = _stennis(miz)
        common = {"start": "deck-cold", "carrier": "CSG-74 Stennis", "skill": "Client", **_BLUE}
        add_air_group(miz, name="Hornets", unit_type="FA-18C_hornet", count=2, **common)
        add_air_group(miz, name="Tomcat", unit_type="F-14B", **common)
        planes = _groups(miz, "plane")
        point = planes["Hornets"]["route"]["points"][0]
        assert point["linkUnit"] == point["helipadId"] == result["carrier_unit_id"]
        assert point["type"] == "TakeOffParking"
        assert [u["parking"] for u in planes["Hornets"]["units"]] == ["1", "2"]
        assert planes["Tomcat"]["units"][0]["parking"] == "3"

    def test_an_aircraft_that_cannot_use_the_deck_is_refused(self, miz: Path) -> None:
        _stennis(miz)
        with pytest.raises(ValueError, match="cannot use the deck"):
            add_air_group(miz, name="Viper", unit_type="F-16C_50", start="deck-hot", carrier="CSG-74 Stennis", **_BLUE)

    def test_an_unknown_carrier_is_refused(self, miz: Path) -> None:
        with pytest.raises(ValueError, match="no ship unit named"):
            add_air_group(miz, name="H", unit_type="FA-18C_hornet", start="deck-cold", carrier="Nope", **_BLUE)


class TestReviewFixes:
    def test_a_carrier_held_on_station_is_placed(self, miz: Path) -> None:
        _stennis(miz, speed_kt=0)
        assert _groups(miz, "ship")["CSG-74 Stennis"]["route"]["points"][1]["ETA"] == 0

    def test_a_unit_name_already_used_is_refused(self, miz: Path) -> None:
        _stennis(miz, carrier_name="CVN-74")
        with pytest.raises(ValueError, match="unit name"):
            add_carrier_group(
                miz,
                name="Other group",
                carrier_name="CVN-74",
                position={"x": 0.0, "y": 0.0},
                recovery_tanker=False,
                rescue_helicopter=False,
                **_BLUE,
            )

    def test_a_deck_start_reports_its_spots_and_refuses_explicit_parking(self, miz: Path) -> None:
        _stennis(miz)
        common = {"start": "deck-cold", "carrier": "CSG-74 Stennis", **_BLUE}
        result = add_air_group(miz, name="Hornets", unit_type="FA-18C_hornet", count=2, **common)
        assert result["stands"] == ["1", "2"]
        with pytest.raises(ValueError, match="omit 'parking'"):
            add_air_group(miz, name="More", unit_type="FA-18C_hornet", parking=["5"], **common)
