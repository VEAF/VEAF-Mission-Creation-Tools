"""`list_payloads` knows the WW2 module aircraft and the AI bombers (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 01).

Every WW2 flight of the Normandy Open Training was armed by hand, or warned about, because the shipped table held only
the Mission Editor's own loadout files and the editor keeps a module aircraft's under CoreMods.
"""

import pytest
from veaf_libs.dcs_payloads import payload_names, payload_pylons, payload_types


@pytest.mark.parametrize(
    "unit_type",
    [
        "P-51D",
        "P-51D-30-NA",
        "P-47D-30",
        "P-47D-40",
        "MosquitoFBMkVI",
        "Bf-109K-4",
        "FW-190A8",
        "FW-190D9",
        "Ju-88A4",
        "B-17G",
    ],
)
def test_a_ww2_type_has_named_loadouts(unit_type: str) -> None:
    assert unit_type in payload_types()
    assert payload_names(unit_type)


def test_the_mustang_loadouts_name_their_stations() -> None:
    assert {"Fuel75*2", "HVAR*6,Fuel75*2"} <= set(payload_names("P-51D"))
    pylons = payload_pylons("P-51D", "HVAR*6,Fuel75*2")
    assert len(pylons) == 8
    assert all(set(value) == {"CLSID"} for value in pylons.values())


def test_the_ju88_carries_two_sc500_under_the_wings_and_ten_sc50_in_the_bay() -> None:
    assert payload_pylons("Ju-88A4", "SC500*2,SC50*10") == {
        1: {"CLSID": "SC_501_SC500"},
        2: {"CLSID": "{JU88A4TORP_10xSC50_on_InvCountedAttachmentPoints}"},
        3: {"CLSID": "SC_501_SC500"},
    }


def test_the_flying_fortress_carries_twelve_m64() -> None:
    assert payload_pylons("B-17G", "M64*12") == {1: {"CLSID": "{12xM64}"}}


def test_a_modern_module_aircraft_is_there_too() -> None:
    assert payload_names("FA-18C_hornet")
