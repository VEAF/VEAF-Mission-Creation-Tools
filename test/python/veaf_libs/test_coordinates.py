"""Tests for the DCS coordinate projection port (FEAT-MCP-MISSION-EDITOR-031).

Reference cases and tolerances are carried over verbatim from the source implementation
(``bfr-claude-plugins`` `projection.lua` test suite).
"""

import math

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


class TestOffset:
    def test_due_north_increases_latitude(self) -> None:
        lat, lon = coordinates.offset_latlon(42.0, 41.0, 0.0, 10_000.0)
        assert lon == pytest.approx(41.0, abs=1e-6)  # no east/west drift due north
        assert lat > 42.0
        # ~10 km north ≈ 0.0899° of latitude.
        assert lat == pytest.approx(42.0 + 10_000.0 / 111_195.0, abs=1e-3)

    def test_due_east_increases_longitude(self) -> None:
        lat, lon = coordinates.offset_latlon(42.0, 41.0, 90.0, 10_000.0)
        assert lon > 41.0
        assert lat == pytest.approx(42.0, abs=1e-3)

    def test_offset_distance_matches_via_projection(self) -> None:
        # Offset 10 km from a real Caucasus point; the DCS-xy distance should be ~10 km (within 1%),
        # validating the geodesic offset composed with the theatre projection.
        lat0, lon0 = coordinates.xy_to_latlon("caucasus", 0.0, 0.0)
        lat1, lon1 = coordinates.offset_latlon(lat0, lon0, 30.0, 10_000.0)
        x0, y0 = coordinates.latlon_to_xy("caucasus", lat0, lon0)
        x1, y1 = coordinates.latlon_to_xy("caucasus", lat1, lon1)
        assert math.hypot(x1 - x0, y1 - y0) == pytest.approx(10_000.0, rel=0.01)


class TestTheatreHandling:
    def test_supported_theatres_from_dcs_maps(self) -> None:
        supported = set(coordinates.supported_theatres())
        # Sourced from the vendored VEAF/dcs-maps export — all DCS theatres, DCS-spelled keys.
        assert {
            "Caucasus",
            "Syria",
            "PersianGulf",
            "MarianaIslands",
            "Normandy",
            "Nevada",
            "SinaiMap",
            "GermanyCW",
        } <= supported
        assert len(supported) >= 14

    def test_case_insensitive(self) -> None:
        assert coordinates.is_theatre_supported("Caucasus")
        lat_lower, _ = coordinates.xy_to_latlon("caucasus", 0.0, 0.0)
        lat_mixed, _ = coordinates.xy_to_latlon("CauCasus", 0.0, 0.0)
        assert lat_lower == lat_mixed

    def test_alias_resolves_to_canonical_key(self) -> None:
        # airdromes.yaml-style names resolve to the dcs-maps keys.
        assert coordinates.is_theatre_supported("Sinai")  # -> SinaiMap
        assert coordinates.is_theatre_supported("GermanyColdWar")  # -> GermanyCW
        assert coordinates.xy_to_latlon("Sinai", 0.0, 0.0) == coordinates.xy_to_latlon("SinaiMap", 0.0, 0.0)

    def test_unsupported_theatre_raises_naming_it(self) -> None:
        with pytest.raises(ValueError, match="atlantis"):
            coordinates.xy_to_latlon("atlantis", 0.0, 0.0)
        with pytest.raises(ValueError, match="atlantis"):
            coordinates.latlon_to_xy("atlantis", 40.0, 40.0)
