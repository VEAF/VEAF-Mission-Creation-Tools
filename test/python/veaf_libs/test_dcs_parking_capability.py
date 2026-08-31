"""What a terrain can park, from the bundled parking dumps (FIX-DYNSLOT-PARKING 01).

DCS only ever offers a dynamic slot for an aircraft the airfield has a stand for, so the build has
to ask the terrain before stocking. These tests pin the sourced ``Term_Type`` table against the
shape of the real bundled data — the three airfields the 2026-08-30 meeting reported as broken.
"""

from __future__ import annotations

from veaf_libs.dcs_parking import (
    AIRCRAFT_STAND_TYPES,
    HELICOPTER_STAND_TYPES,
    PLANE_STAND_TYPES,
    aircraft_stands_for_airbase,
    parkable_kinds,
    stands_for_airbase,
)

# Syria airdrome ids, resolved through veaf_libs.dcs_airdromes.
_AKROTIRI = 44
_LAKATAMIA = 48
_NAQOURA = 52
_INCIRLIK = 16

#: Syria's only airfield carrying OpenMed (72) stands and no 68/104 — 16 of them.
_THALAH = 5

#: Persian Gulf airfields in the same case (see CHORE-AIRCRAFT-STAND-TYPES).
_BANDAR_LENGEH = 3
_JIROFT = 27


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


class TestAircraftStandTypes:
    """The set this tool seats a unit on: DCS's ``FighterAircraft`` mask (CHORE-AIRCRAFT-STAND-TYPES).

    Measured on the bundled captures and on the real VEAF missions — the numbers and their provenance
    live beside the constant in ``veaf_libs.dcs_parking``.
    """

    def test_it_is_the_fighter_aircraft_mask(self) -> None:
        # 244 = 68 + 72 + 104. Asserted as the sum so a silent edit to the set fails here.
        assert sum(int(t) for t in AIRCRAFT_STAND_TYPES) == 244

    def test_open_med_is_seatable(self) -> None:
        # 28% of the position-confirmed parked planes in the real VEAF missions sit on 72.
        assert "72" in AIRCRAFT_STAND_TYPES

    def test_the_small_fighter_spot_is_not_seatable(self) -> None:
        # 100 is documented as a tight spot for small airframes and unlocks no airfield, so it stays
        # out of the seatable set while remaining a plane stand for capability purposes.
        assert "100" not in AIRCRAFT_STAND_TYPES
        assert "100" in PLANE_STAND_TYPES

    def test_it_never_offers_a_runway_or_a_helipad(self) -> None:
        assert not AIRCRAFT_STAND_TYPES & {"16", "40"}

    def test_it_stays_within_what_a_plane_can_use(self) -> None:
        assert AIRCRAFT_STAND_TYPES < PLANE_STAND_TYPES


class TestOpenMedOnlyAirfieldsAreUsable:
    """The seven airfields the narrow ``{68, 104}`` set refused to place anything on.

    Each carries OpenMed (72) stands and no 68/104 at all, so ``aircraft_stands_for_airbase`` used to
    return nothing and ``add_air_group`` refused the field outright.
    """

    def test_thalah_offers_its_open_med_stands(self) -> None:
        stands = aircraft_stands_for_airbase("Syria", _THALAH)
        assert len(stands) == 16
        assert {s.term_type for s in stands} == {"72"}

    def test_bandar_lengeh_offers_its_open_med_stands(self) -> None:
        stands = aircraft_stands_for_airbase("PersianGulf", _BANDAR_LENGEH)
        assert stands and {s.term_type for s in stands} == {"72"}

    def test_jiroft_offers_its_open_med_stands(self) -> None:
        stands = aircraft_stands_for_airbase("PersianGulf", _JIROFT)
        assert stands and {s.term_type for s in stands} == {"72"}

    def test_their_helipads_and_runways_are_still_refused(self) -> None:
        # Bandar-e-Jask carries 2 helipads and 2 runway spawns alongside its 2 OpenMed stands.
        offered = aircraft_stands_for_airbase("PersianGulf", 21)
        assert {s.term_type for s in offered} == {"72"}
        assert {s.term_type for s in stands_for_airbase("PersianGulf", 21)} == {"16", "40", "72"}


class TestPersianGulfHasNoShelters:
    """Why the Caucasus-only measurement generalised badly, pinned so it cannot be re-assumed."""

    def test_no_persian_gulf_airfield_offers_a_shelter(self) -> None:
        # 68 is a Caucasus/Syria stand type. On Persian Gulf the old {68, 104} set meant "104 only",
        # which is what left six of its airfields unusable.
        for airbase_id in (_BANDAR_LENGEH, _JIROFT, 2, 4, 14):
            assert "68" not in {s.term_type for s in stands_for_airbase("PersianGulf", airbase_id)}


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
