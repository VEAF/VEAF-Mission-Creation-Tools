"""Tests for `aircraft_identity` — callsigns and tail numbers (FIX-OPEN-TRAINING-PROMPT-FINDINGS 01)."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_air_group import add_air_group
from veaf_mission_mcp.aircraft_identity import assign_identities
from veaf_mission_mcp.player_slot import add_player_slot


def _flight(count: int) -> dict[str, Any]:
    return {"units": [{"name": f"u{i}"} for i in range(count)]}


def _content_with(*groups: tuple[str, str, dict[str, Any]]) -> dict[str, Any]:
    """A mission table with pre-placed plane groups, given as (country name, task, group)."""
    countries = [
        {"id": i, "name": name, "plane": {"group": [dict(group, task=task)]}}
        for i, (name, task, group) in enumerate(groups, start=1)
    ]
    return {"coalition": {"blue": {"country": countries}, "red": {"country": []}}}


def _placed(callsign: Any, onboard_num: str) -> dict[str, Any]:
    return {"units": [{"name": "old", "callsign": callsign, "onboard_num": onboard_num}]}


class TestWesternCallsigns:
    def test_a_first_fighter_flight_is_enfield_1(self) -> None:
        group = _flight(2)
        assign_identities(_content_with(), group, country_id=2, task="CAP")
        assert [u["callsign"] for u in group["units"]] == [
            {1: 1, 2: 1, 3: 1, "name": "Enfield11"},
            {1: 1, 2: 1, 3: 2, "name": "Enfield12"},
        ]

    def test_the_next_flight_takes_the_next_free_family(self) -> None:
        content = _content_with(("USA", "CAP", _placed({1: 1, 2: 1, 3: 1, "name": "Enfield11"}, "010")))
        group = _flight(1)
        assign_identities(content, group, country_id=2, task="CAS")
        assert group["units"][0]["callsign"]["name"] == "Springfield11"

    def test_a_tanker_is_texaco_and_an_awacs_overlord(self) -> None:
        tanker, awacs = _flight(1), _flight(1)
        assign_identities(_content_with(), tanker, country_id=2, task="Refueling")
        assign_identities(_content_with(), awacs, country_id=2, task="AWACS")
        assert tanker["units"][0]["callsign"]["name"] == "Texaco11"
        assert awacs["units"][0]["callsign"]["name"] == "Overlord11"

    def test_once_every_family_is_used_a_new_flight_number_is_taken(self) -> None:
        placed = [
            ("USA", "Refueling", _placed({1: i, 2: 1, 3: 1, "name": f"{word}11"}, f"{i:03d}"))
            for i, word in enumerate(("Texaco", "Arco", "Shell"), start=1)
        ]
        group = _flight(1)
        assign_identities(_content_with(*placed), group, country_id=2, task="Refueling")
        assert group["units"][0]["callsign"] == {1: 1, 2: 2, 3: 1, "name": "Texaco21"}


class TestNumericCallsigns:
    def test_a_russian_aircraft_gets_a_number(self) -> None:
        group = _flight(2)
        assign_identities(_content_with(), group, country_id=0, task="CAP")
        assert [u["callsign"] for u in group["units"]] == [101, 102]

    def test_numbers_continue_after_the_highest(self) -> None:
        content = _content_with(("Russia", "CAP", _placed(182, "010")))
        group = _flight(1)
        assign_identities(content, group, country_id=0, task="CAP")
        assert group["units"][0]["callsign"] == 183


class TestTailNumbers:
    def test_they_continue_after_the_highest_in_the_mission(self) -> None:
        content = _content_with(("USA", "CAP", _placed(None, "701")))
        group = _flight(2)
        assign_identities(content, group, country_id=2, task="CAP")
        assert [u["onboard_num"] for u in group["units"]] == ["702", "703"]

    def test_a_value_already_set_is_kept(self) -> None:
        group = {"units": [{"name": "u", "onboard_num": "042", "callsign": 5}]}
        assign_identities(_content_with(), group, country_id=2, task="CAP")
        assert group["units"][0] == {"name": "u", "onboard_num": "042", "callsign": 5}


def _empty_miz(tmp_path: Path) -> Path:
    lua = (
        b'mission = { ["theatre"] = "Caucasus", ["coalition"] = { ["blue"] = { ["country"] = { } }, '
        b'["red"] = { ["country"] = { } } }, ["coalitions"] = { ["blue"] = { }, ["red"] = { } } }'
    )
    path = tmp_path / "m.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", lua)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _all_units(miz: Path) -> list[dict[str, Any]]:
    content = read_miz(miz).mission_content or {}
    units: list[dict[str, Any]] = []
    for country in content["coalition"]["blue"]["country"]:
        for category in ("plane", "helicopter"):
            for group in (country.get(category) or {}).get("group") or []:
                units.extend(group["units"])
    return units


class TestThroughTheActions:
    """The wiring: both aircraft-creating actions go through `assign_identities` and the payload."""

    def test_two_flights_and_a_slot_share_no_tail_number(self, tmp_path: Path) -> None:
        miz = _empty_miz(tmp_path)
        common: dict[str, Any] = {
            "coalition": "blue",
            "country_id": 2,
            "country_name": "USA",
            "start": "air",
            "position": {"x": 0.0, "y": 0.0},
        }
        add_air_group(miz, name="Tanker", unit_type="KC-135", task="Refueling", **common)
        add_air_group(miz, name="Arena", unit_type="F-14B", count=2, skill="Client", task="CAP", **common)
        add_player_slot(miz, name="Slot", unit_type="FA-18C_hornet", **common)
        units = _all_units(miz)
        tails = [u["onboard_num"] for u in units]
        assert len(set(tails)) == len(tails) == 4
        by_type = {(u["type"], u["callsign"]["name"]): u for u in units}
        assert ("KC-135", "Texaco11") in by_type
        assert ("F-14B", "Enfield11") in by_type and ("F-14B", "Enfield12") in by_type
        assert (
            by_type[("F-14B", "Enfield12")]["payload"]["chaff"],
            by_type[("F-14B", "Enfield12")]["payload"]["flare"],
        ) == (140, 60)
        assert ("FA-18C_hornet", "Springfield11") in by_type


def test_a_tenth_aircraft_continues_on_the_next_flight() -> None:
    group = _flight(10)
    assign_identities(_content_with(), group, country_id=2, task="CAP")
    names = [u["callsign"]["name"] for u in group["units"]]
    assert names[8:] == ["Enfield19", "Enfield21"]
    assert len(set(names)) == 10
