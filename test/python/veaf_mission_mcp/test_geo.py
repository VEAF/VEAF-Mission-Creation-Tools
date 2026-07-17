"""Tests for the geocode action + theatre bounds (FEAT-GEO-PLACEMENT-003/004). Geocoder mocked."""

from pathlib import Path
from typing import Any

import pytest
from veaf_libs import coordinates, geocoding
from veaf_libs.geocoding import Bounds, GeocodeResult
from veaf_mission_mcp import geo


class _FakeGeocoder:
    def __init__(self, result: GeocodeResult | None) -> None:
        self._result = result
        self.bounds_seen: Bounds | None = None

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None:
        self.bounds_seen = bounds
        return self._result


class TestTheatreBounds:
    def test_caucasus_box_contains_batumi(self) -> None:
        b = geocoding.theatre_bounds("Caucasus")
        assert b is not None
        assert b.min_lat <= 41.65 <= b.max_lat and b.min_lon <= 41.64 <= b.max_lon

    def test_unknown_theatre_is_none(self) -> None:
        assert geocoding.theatre_bounds("nevada") is None


class TestGeocode:
    def test_resolves_name_to_xy(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        fake = _FakeGeocoder(GeocodeResult(41.6519, 41.6367, "Batumi, Georgia"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)

        result = geo.geocode(sample_miz, "Batumi")

        assert result["found"] is True
        assert result["theatre"] == "Caucasus"
        exp_x, exp_y = coordinates.latlon_to_xy("Caucasus", 41.6519, 41.6367)
        assert result["xy"] == {"x": exp_x, "y": exp_y}
        assert result["in_theatre_bounds"] is True
        # The Caucasus bounding box was passed to the geocoder to disambiguate.
        assert fake.bounds_seen is not None

    def test_bearing_distance_offsets_result(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        fake = _FakeGeocoder(GeocodeResult(42.0, 41.0, "somewhere"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)

        base = geo.geocode(sample_miz, "X")
        north = geo.geocode(sample_miz, "X", bearing=0.0, distance_km=10.0)
        assert north["latlon"]["lat"] > base["latlon"]["lat"]  # moved north

    def test_miss_returns_found_false(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(None))
        result = geo.geocode(sample_miz, "Nowhereville")
        assert result["found"] is False

    def test_out_of_bounds_warns_not_fails(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        # A hit far outside Caucasus (e.g. Paris) → still returned, but flagged.
        fake = _FakeGeocoder(GeocodeResult(48.8566, 2.3522, "Paris, France"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)

        result = geo.geocode(sample_miz, "Paris")
        assert result["found"] is True
        assert result["in_theatre_bounds"] is False
        assert any("bounds" in w for w in result["warnings"])
