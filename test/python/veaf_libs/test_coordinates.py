"""Tests for the DCS coordinate projection port (FEAT-MCP-MISSION-EDITOR-031).

Reference cases and tolerances are carried over verbatim from the source implementation
(``bfr-claude-plugins`` `projection.lua` test suite).
"""

import pytest
from veaf_libs import coordinates

# (theatre, x, y, expected_lat, expected_lon) — from the ported Lua test suite.
_CASES = [
    ("caucasus", -291014.0, 617414.0, 42.18654874, 41.67893429),
    ("caucasus", 0.0, 0.0, 45.12949706, 34.26551519),
    ("syria", 50000.0, -120000.0, 35.43077102, 34.56390494),
    ("persiangulf", -100000.0, 200000.0, 25.26563769, 58.23384439),
    ("marianaislands", 10000.0, 20000.0, 13.57691968, 144.98145132),
]


class TestXyToLatLon:
    @pytest.mark.parametrize(("theatre", "x", "y", "lat", "lon"), _CASES)
    def test_matches_reference(self, theatre: str, x: float, y: float, lat: float, lon: float) -> None:
        got_lat, got_lon = coordinates.xy_to_latlon(theatre, x, y)
        assert abs(got_lat - lat) < 5e-6, f"{theatre} lat: {got_lat} vs {lat}"
        assert abs(got_lon - lon) < 5e-6, f"{theatre} lon: {got_lon} vs {lon}"


class TestRoundTrip:
    @pytest.mark.parametrize(("theatre", "x", "y", "lat", "lon"), _CASES)
    def test_xy_latlon_xy_stable(self, theatre: str, x: float, y: float, lat: float, lon: float) -> None:
        back_x, back_y = coordinates.latlon_to_xy(theatre, *coordinates.xy_to_latlon(theatre, x, y))
        assert abs(back_x - x) < 0.5, f"{theatre} x: {back_x} vs {x}"
        assert abs(back_y - y) < 0.5, f"{theatre} y: {back_y} vs {y}"


class TestTheatreHandling:
    def test_supported_theatres(self) -> None:
        assert set(coordinates.supported_theatres()) == {"caucasus", "syria", "persiangulf", "marianaislands"}

    def test_case_insensitive(self) -> None:
        assert coordinates.is_theatre_supported("Caucasus")
        lat_lower, _ = coordinates.xy_to_latlon("caucasus", 0.0, 0.0)
        lat_mixed, _ = coordinates.xy_to_latlon("CauCasus", 0.0, 0.0)
        assert lat_lower == lat_mixed

    def test_unsupported_theatre_raises_naming_it(self) -> None:
        with pytest.raises(ValueError, match="nevada"):
            coordinates.xy_to_latlon("nevada", 0.0, 0.0)
        with pytest.raises(ValueError, match="nevada"):
            coordinates.latlon_to_xy("nevada", 40.0, 40.0)
