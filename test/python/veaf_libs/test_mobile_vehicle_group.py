"""Which groups a briefing shows as a zone rather than pinpointed (FIX-MARTEAU-PLAY-FINDINGS 07)."""

import pytest
from veaf_libs.dcs_units_data import is_mobile_vehicle_group


@pytest.mark.parametrize(
    ("types", "mobile"),
    [
        (["T-72B", "T-72B"], True),  # tanks
        (["BMP-2", "BTR-82A"], True),  # light armour
        (["Ural-375", "UAZ-469"], True),  # trucks and a 4x4
        # Khan Arnabah's armoured platoon on 2026-10-29: the AAA truck moves with the tanks
        (["BMP-2", "BTR-82A", "Ural-375 ZU-23", "VAB_Mephisto", "T-55"], True),
        (["T-72B", "T-72B", "ZSU-23-4 Shilka"], True),  # a Shilka carries SAM TR, and escorts
        (["BMP-2", "2S6 Tunguska", "Strela-10M3"], True),
        (["Kub 1S91 str", "Kub 2P25 ln", "Ural-375"], False),  # a SAM battery and its logistics truck
        (["SAU Gvozdika", "Grad-URAL"], False),  # an artillery position
        (["Strela-10M3"], False),  # a short-range SAM
        (["ZU-23 Emplacement"], False),  # a gun pit, nothing that moves
        (["Ural-375 ZU-23"], False),  # mobile AAA alone: an air defence, not a vehicle target
        (["No such type"], False),
        ([], False),
    ],
)
def test_a_group_is_mobile_vehicles_only_without_a_fixed_site(types: list[str], mobile: bool) -> None:
    assert is_mobile_vehicle_group(types) is mobile
