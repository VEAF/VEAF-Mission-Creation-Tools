"""The Normandy parking capture ships (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 08).

Captured in DCS on 2026-10-13 with `veaf-tools dcs capture-map --parking`: 3 716 stands on 90 airfields. Without it
every QRA of the map started in the air and a client slot at a parking needed a hand edit.
"""

import json

from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import aircraft_stands_for_airbase, has_theatre


def test_the_theatre_ships_its_parking_data() -> None:
    assert has_theatre("Normandy")


def test_the_capture_holds_the_stands_it_was_made_with() -> None:
    capture = json.loads(read_bundled_text("veaf_libs", "data", "parking", "Normandy.json"))
    assert capture["theatre"] == "Normandy"
    assert len(capture["by_airbase"]) == 90
    assert sum(len(stands) for stands in capture["by_airbase"].values()) == 3716


def test_tangmere_has_aircraft_stands() -> None:
    airdrome_id = airdrome_id_for_name("Normandy", "Tangmere")
    assert airdrome_id is not None
    assert aircraft_stands_for_airbase("Normandy", airdrome_id)
