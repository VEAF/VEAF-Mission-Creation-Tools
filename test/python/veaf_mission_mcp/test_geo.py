"""Tests for the geocode action + theatre bounds (FEAT-GEO-PLACEMENT-003/004). Geocoder mocked."""

from pathlib import Path
from typing import Any

import pytest
import yaml
from veaf_libs import coordinates, geocoding
from veaf_libs.bundled_data import read_bundled_text
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

    @pytest.mark.parametrize(
        ("place", "lat", "lon"),
        [("Port Stanley", -51.69, -57.85), ("Ushuaia", -54.81, -68.31), ("Punta Arenas", -53.16, -70.91)],
    )
    def test_falklands_box_contains_its_places(self, place: str, lat: float, lon: float) -> None:
        # Without a box the geocoder answered « San Julian » in Jujuy and « Porvenir » in Maule.
        b = geocoding.theatre_bounds("Falklands")
        assert b is not None, place
        assert b.min_lat <= lat <= b.max_lat and b.min_lon <= lon <= b.max_lon, place

    def test_unknown_theatre_is_none(self) -> None:
        assert geocoding.theatre_bounds("no-such-theatre") is None

    def test_every_theatre_of_the_projection_table_has_a_box(self) -> None:
        """FIX-OPEN-TRAINING-NORMANDY-FINDINGS 11: a theatre with no box checks nothing, and said it was fine."""
        theatres = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcs-maps.yaml"))
        assert [name for name in theatres if geocoding.theatre_bounds(name) is None] == []

    @pytest.mark.parametrize(
        ("place", "lat", "lon"),
        [("Omaha Beach", 49.37, -0.87), ("Tangmere", 50.85, -0.71), ("Evreux", 49.03, 1.22)],
    )
    def test_normandy_box_contains_its_places(self, place: str, lat: float, lon: float) -> None:
        b = geocoding.theatre_bounds("Normandy")
        assert b is not None
        assert b.min_lat <= lat <= b.max_lat and b.min_lon <= lon <= b.max_lon, place

    def test_normandy_box_excludes_the_omaha_beach_of_iowa(self) -> None:
        b = geocoding.theatre_bounds("Normandy")
        assert b is not None
        assert not (b.min_lat <= 43.37 <= b.max_lat and b.min_lon <= -95.15 <= b.max_lon)

    def test_every_theatre_box_holds_the_airfield_it_was_derived_from(self) -> None:
        positions = yaml.safe_load(read_bundled_text("veaf_libs", "data", "airdrome-positions.yaml"))["theatres"]
        outside = []
        for theatre in ("Afghanistan", "GermanyCW", "Iraq", "Kola", "Nevada", "Normandy", "SinaiMap", "TheChannel"):
            box = geocoding.theatre_bounds(theatre)
            assert box is not None, theatre
            outside += [
                f"{theatre}/{a['name']}"
                for a in positions[theatre]
                if not (box.min_lat <= a["lat"] <= box.max_lat and box.min_lon <= a["lon"] <= box.max_lon)
            ]
        assert outside == []


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

    def test_a_theatre_with_no_box_checks_nothing_and_says_so(
        self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        fake = _FakeGeocoder(GeocodeResult(43.37, -95.15, "Omaha Beach, Okoboji, Iowa"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)
        monkeypatch.setattr(geocoding, "theatre_bounds", lambda theatre: None)

        result = geo.geocode(sample_miz, "Omaha Beach")

        assert result["in_theatre_bounds"] is None
        assert any("no bounds for this theatre" in w for w in result["warnings"])

    def test_bearing_distance_offsets_result(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        fake = _FakeGeocoder(GeocodeResult(42.0, 41.0, "somewhere"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)

        base = geo.geocode(sample_miz, "X")
        north = geo.geocode(sample_miz, "X", bearing=0.0, distance_km=10.0)
        assert north["latlon"]["lat"] > base["latlon"]["lat"]  # moved north

    def test_miss_returns_stable_shape(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(None))
        result = geo.geocode(sample_miz, "Nowhereville")
        assert result["found"] is False
        # Same keys as a hit, nulled — callers never special-case.
        assert set(result) == {
            "query",
            "found",
            "display_name",
            "osm_class",
            "osm_type",
            "theatre",
            "latlon",
            "xy",
            "in_theatre_bounds",
            "warnings",
        }
        assert result["latlon"] is None and result["xy"] is None and result["in_theatre_bounds"] is None

    def test_partial_bearing_distance_raises(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(
            geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(GeocodeResult(42.0, 41.0, "x"))
        )
        with pytest.raises(ValueError, match="together"):
            geo.geocode(sample_miz, "X", bearing=90.0)  # distance_km missing

    def test_out_of_bounds_warns_not_fails(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        # A hit far outside Caucasus (e.g. Paris) → still returned, but flagged.
        fake = _FakeGeocoder(GeocodeResult(48.8566, 2.3522, "Paris, France"))
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: fake)

        result = geo.geocode(sample_miz, "Paris")
        assert result["found"] is True
        assert result["in_theatre_bounds"] is False
        assert any("bounds" in w for w in result["warnings"])


class TestRoadsRegionsAndRefusals:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 07."""

    def test_a_road_is_returned_with_its_class_and_a_warning(
        self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        road = GeocodeResult(41.6, 41.6, "Some street", "highway", "residential")
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(road))
        result = geo.geocode(sample_miz, "Al-Kiswah")
        assert (result["osm_class"], result["osm_type"]) == ("highway", "residential")
        assert any("not a named place" in w for w in result["warnings"])

    @pytest.mark.parametrize(
        ("query", "display_name"),
        [("Umatac, Guam", "Guam, United States"), ("San Jose, Tinian", "Tinian, Northern Mariana Islands")],
    )
    def test_an_island_given_for_a_village_is_warned_about(
        self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch, query: str, display_name: str
    ) -> None:
        """FIX-OPEN-TRAINING-MARIANAS-FINDINGS ticket 05: a village asked, the island's centre given, no word."""
        island = GeocodeResult(13.4, 144.7, display_name, "place", "island")
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(island))
        warnings = geo.geocode(sample_miz, query)["warnings"]
        named, found = query.split(",")[0], display_name.split(",")[0]
        assert any(named in w and found in w and "island" in w for w in warnings), warnings

    def test_the_island_asked_for_is_not_warned_about(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        island = GeocodeResult(13.4, 144.7, "Guam, United States", "place", "island")
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(island))
        assert not [w for w in geo.geocode(sample_miz, "Guam")["warnings"] if "island" in w]

    def test_the_village_found_is_not_warned_about(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        village = GeocodeResult(13.3, 144.66, "Umatac, Guam, United States", "place", "village")
        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _FakeGeocoder(village))
        assert not [w for w in geo.geocode(sample_miz, "Umatac, Guam")["warnings"] if "Umatac" in w]

    def test_a_refusal_is_a_miss_that_says_why(self, sample_miz: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        class _Refusing:
            def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None:
                raise geocoding.GeocodingRefusedError("Nominatim refused the request (HTTP 429)")

        monkeypatch.setattr(geocoding, "get_geocoder", lambda api_key=None: _Refusing())
        result = geo.geocode(sample_miz, "Al-Kiswah")
        assert result["found"] is False
        assert result["warnings"] == ["Nominatim refused the request (HTTP 429)"]
