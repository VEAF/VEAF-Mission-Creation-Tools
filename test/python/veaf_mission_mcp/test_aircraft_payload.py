"""Tests for the aircraft payload builder — the fuel an aircraft is created with.

The defect these pin down (`FIX-MCP-AUTHORING-GAPS` 04) shipped a valid mission whose aircraft could
not fly: `payload.fuel` was hard-coded to 0, which is an explicit instruction to carry no fuel. A
KC-135 and its two F-15C escorts created at 20 000 ft pitched into the ground on appearing.
"""

from __future__ import annotations

import pytest
from veaf_mission_mcp.aircraft_payload import build_aircraft_payload


class TestFullInternalFuelByDefault:
    """The default is the type's own capacity, taken from the shipped database."""

    @pytest.mark.parametrize(
        ("unit_type", "expected"),
        [
            ("F-15C", 6103),  # the value the shipped VEAF templates carry
            ("F-14B", 7348),
            ("A-10C_2", 5029),
            ("UH-1H", 631),  # helicopter: the other category the ticket names
            ("Mi-8MT", 1929),
        ],
    )
    def test_capacity_comes_from_the_database(self, unit_type: str, expected: float) -> None:
        payload, warning = build_aircraft_payload(unit_type)
        assert payload["fuel"] == expected
        assert warning is None

    def test_never_zero(self) -> None:
        # The regression itself: any stock aircraft must be created with fuel in it.
        for unit_type in ("F-15C", "KC-135", "UH-1H", "AH-64D"):
            payload, _ = build_aircraft_payload(unit_type)
            assert payload["fuel"] > 0, unit_type

    def test_case_insensitive(self) -> None:
        assert build_aircraft_payload("f-15c")[0]["fuel"] == 6103

    def test_a_fractional_capacity_keeps_its_decimals(self) -> None:
        # 3054.592 kg — mission files carry the unrounded value, and so do the shipped templates.
        assert build_aircraft_payload("CH-47Fbl1")[0]["fuel"] == pytest.approx(3054.592)

    def test_the_rest_of_the_payload_is_untouched(self) -> None:
        payload, _ = build_aircraft_payload("F-15C")
        assert payload["flare"] == 0
        assert payload["chaff"] == 0
        assert payload["gun"] == 100
        assert payload["pylons"] == {}


class TestExplicitLoad:
    def test_kilograms_win_over_the_database(self) -> None:
        payload, warning = build_aircraft_payload("F-15C", fuel=1500)
        assert payload["fuel"] == 1500
        assert warning is None

    def test_zero_is_allowed_when_asked_for_explicitly(self) -> None:
        # An empty tank is a legitimate thing to ask for; what was wrong was getting it by default.
        assert build_aircraft_payload("F-15C", fuel=0)[0]["fuel"] == 0

    def test_a_fraction_of_capacity(self) -> None:
        # 80 % of the A-10C II's 5029 kg — the load the shipped template carries.
        payload, _ = build_aircraft_payload("A-10C_2", fuel_fraction=0.8)
        assert payload["fuel"] == pytest.approx(4023.2)

    def test_a_full_fraction_matches_the_default(self) -> None:
        assert build_aircraft_payload("F-15C", fuel_fraction=1)[0]["fuel"] == 6103

    def test_negative_kilograms_are_refused(self) -> None:
        with pytest.raises(ValueError, match="must be >= 0"):
            build_aircraft_payload("F-15C", fuel=-1)

    @pytest.mark.parametrize("fraction", [0, -0.5, 1.5])
    def test_a_fraction_outside_the_range_is_refused(self, fraction: float) -> None:
        with pytest.raises(ValueError, match="fuel_fraction"):
            build_aircraft_payload("F-15C", fuel_fraction=fraction)

    def test_both_at_once_is_refused(self) -> None:
        with pytest.raises(ValueError, match="not both"):
            build_aircraft_payload("F-15C", fuel=1000, fuel_fraction=0.5)


class TestUnknownType:
    """A third-party mod is warned about, not refused — the contract `add_air_group` already keeps."""

    def test_no_fuel_key_rather_than_an_invented_number(self) -> None:
        payload, warning = build_aircraft_payload("NoSuchModType")
        assert "fuel" not in payload
        assert warning is not None and "NoSuchModType" in warning

    def test_an_explicit_load_needs_no_database_entry(self) -> None:
        payload, warning = build_aircraft_payload("NoSuchModType", fuel=4200)
        assert payload["fuel"] == 4200
        assert warning is None

    def test_a_fraction_of_an_unknown_capacity_is_refused(self) -> None:
        # Unlike the default case, this one the caller asked for and it cannot be honoured.
        with pytest.raises(ValueError, match="fraction"):
            build_aircraft_payload("NoSuchModType", fuel_fraction=0.5)
