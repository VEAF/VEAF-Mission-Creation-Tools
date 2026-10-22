"""Five parking captures ship (FIX-MISSION-LANGUAGE-FOLLOWS-USER ticket 03).

Captured in DCS on 2026-10-22 with `veaf-tools capture-map --parking`, one blank mission per map with the
bridge inside. Without them `add_air_group` refused every ramp and runway start on these maps.
"""

import json

import pytest
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import aircraft_stands_for_airbase, has_theatre

# theatre: (airfields with stands, stands, an airfield to check)
CAPTURES = {
    "Afghanistan": (26, 1435, "Bagram"),
    "GermanyCW": (227, 7035, "Ramstein"),
    "MarianaIslands": (8, 282, "Andersen AFB"),
    "MarianaIslandsWWII": (11, 534, "Agana"),
    "TheChannel": (12, 616, "Manston"),
}


@pytest.mark.parametrize("theatre", sorted(CAPTURES))
def test_the_theatre_ships_its_parking_data(theatre: str) -> None:
    assert has_theatre(theatre)


@pytest.mark.parametrize("theatre", sorted(CAPTURES))
def test_the_capture_holds_the_stands_it_was_made_with(theatre: str) -> None:
    airfields, stands, _ = CAPTURES[theatre]
    capture = json.loads(read_bundled_text("veaf_libs", "data", "parking", f"{theatre}.json"))
    assert capture["theatre"] == theatre
    assert len(capture["by_airbase"]) == airfields
    assert sum(len(s) for s in capture["by_airbase"].values()) == stands


@pytest.mark.parametrize("theatre", sorted(CAPTURES))
def test_a_main_airfield_has_aircraft_stands(theatre: str) -> None:
    airdrome_id = airdrome_id_for_name(theatre, CAPTURES[theatre][2])
    assert airdrome_id is not None
    assert aircraft_stands_for_airbase(theatre, airdrome_id)
