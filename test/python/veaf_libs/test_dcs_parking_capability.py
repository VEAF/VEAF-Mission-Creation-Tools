"""What a terrain can park, from the bundled parking dumps (FIX-DYNSLOT-PARKING 01).

DCS only ever offers a dynamic slot for an aircraft the airfield has a stand for, so the build has
to ask the terrain before stocking. These tests pin the sourced ``Term_Type`` table against the
shape of the real bundled data — the three airfields the 2026-08-30 meeting reported as broken.
"""

from __future__ import annotations

from veaf_libs.dcs_parking import (
    HELICOPTER_STAND_TYPES,
    PLANE_STAND_TYPES,
    parkable_kinds,
)

# Syria airdrome ids, resolved through veaf_libs.dcs_airdromes.
_AKROTIRI = 44
_LAKATAMIA = 48
_NAQOURA = 52
_INCIRLIK = 16


class TestTermTypeTable:
    """The sourced DCS ``Term_Type`` values (see the module docstring for provenance)."""

    def test_helipads_are_helicopter_only(self) -> None:
        assert "40" in HELICOPTER_STAND_TYPES
        assert "40" not in PLANE_STAND_TYPES

    def test_shelters_and_small_fighter_spots_are_plane_only(self) -> None:
        # Shelter (68) and SmallSizeFighter (100) are in FighterAircraftSmall but not in
        # HelicopterUsable.
        assert {"68", "100"} <= PLANE_STAND_TYPES
        assert not {"68", "100"} & HELICOPTER_STAND_TYPES

    def test_open_stands_take_both(self) -> None:
        # OpenMed (72) and OpenBig (104) are in both composite masks.
        assert {"72", "104"} <= PLANE_STAND_TYPES
        assert {"72", "104"} <= HELICOPTER_STAND_TYPES

    def test_the_runway_is_not_a_parking_stand(self) -> None:
        assert "16" not in PLANE_STAND_TYPES
        assert "16" not in HELICOPTER_STAND_TYPES


class TestParkableKindsOnRealData:
    """Measured against the bundled Syria dump — the airfields reported in game."""

    def test_naqoura_parks_helicopters_only(self) -> None:
        assert parkable_kinds("Syria", _NAQOURA) == frozenset({"helicopter"})

    def test_lakatamia_parks_helicopters_only(self) -> None:
        assert parkable_kinds("Syria", _LAKATAMIA) == frozenset({"helicopter"})

    def test_akrotiri_parks_both(self) -> None:
        assert parkable_kinds("Syria", _AKROTIRI) == frozenset({"plane", "helicopter"})

    def test_incirlik_parks_both(self) -> None:
        assert parkable_kinds("Syria", _INCIRLIK) == frozenset({"plane", "helicopter"})

    def test_theatre_name_is_case_insensitive(self) -> None:
        assert parkable_kinds("syria", _NAQOURA) == frozenset({"helicopter"})

    def test_a_string_airbase_id_resolves_like_an_int(self) -> None:
        assert parkable_kinds("Syria", str(_NAQOURA)) == parkable_kinds("Syria", _NAQOURA)


class TestNoData:
    """No data means no opinion: the caller must behave exactly as it did before."""

    def test_an_uncaptured_theatre_returns_none(self) -> None:
        assert parkable_kinds("Normandy", 1) is None

    def test_an_empty_theatre_name_returns_none(self) -> None:
        assert parkable_kinds("", 1) is None

    def test_an_airbase_absent_from_the_dump_returns_none(self) -> None:
        assert parkable_kinds("Syria", 999999) is None
