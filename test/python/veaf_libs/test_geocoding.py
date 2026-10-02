"""Tests for the pluggable geocoder (FEAT-GEO-PLACEMENT-001). HTTP is mocked — no live network."""

from typing import Any

import pytest
from veaf_libs import geocoding
from veaf_libs.geocoding import Bounds, GeocodingRefusedError, GoogleGeocoder, NominatimGeocoder, get_geocoder


class _FakeResponse:
    def __init__(self, payload: Any, status_code: int = 200, headers: dict[str, str] | None = None) -> None:
        self._payload = payload
        self.status_code = status_code
        self.headers = headers or {}

    def raise_for_status(self) -> None:
        return None

    def json(self) -> Any:
        return self._payload


class _Clock:
    """Stands in for ``time``: records the sleeps, advances only when slept."""

    def __init__(self) -> None:
        self.now = 1000.0
        self.slept: list[float] = []

    def monotonic(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.slept.append(seconds)
        self.now += seconds


@pytest.fixture(autouse=True)
def clock(monkeypatch: pytest.MonkeyPatch) -> _Clock:
    """No real sleeping, and every test starts as if no request had been sent yet."""
    fake = _Clock()
    monkeypatch.setattr(geocoding, "time", fake)
    monkeypatch.setattr(geocoding, "_last_request", float("-inf"))
    return fake


# Recorded from Nominatim on 2026-10-02 (Syria theatre bounds, jsonv2, limit 5), trimmed: each query
# came back with this single candidate.
_AL_KISWAH = [
    {
        "lat": "31.9716422",
        "lon": "35.8828309",
        "category": "highway",
        "type": "residential",
        "addresstype": "road",
        "display_name": "شارع كسوة, الرابية, قضاء الجامعة, لواء الجامعة, عمان, 11185, الأردن",
    }
]
_LATAKIA = [
    {
        "lat": "35.5798740",
        "lon": "35.9772699",
        "category": "boundary",
        "type": "administrative",
        "addresstype": "state",
        "display_name": "محافظة اللاذقية, سوريا",
    }
]
_TOWN = {"lat": "33.36", "lon": "36.23", "category": "place", "type": "town", "display_name": "Al-Kiswah, Syria"}


class TestSyriaFindings:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 07: banned after 21 calls, and a street of Amman for a town."""

    def test_a_street_comes_back_marked_as_a_road(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse(_AL_KISWAH))
        hit = NominatimGeocoder().geocode("Al-Kiswah")
        assert hit is not None and (hit.osm_class, hit.osm_type) == ("highway", "residential")
        assert hit.is_road_or_region

    def test_a_governorate_comes_back_marked_as_a_region(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse(_LATAKIA))
        hit = NominatimGeocoder().geocode("Latakia")
        assert hit is not None and hit.is_road_or_region

    def test_a_named_place_is_preferred_to_a_road(self, monkeypatch: pytest.MonkeyPatch) -> None:
        calls: list[dict[str, Any]] = []

        def fake_get(url: str, **kwargs: Any) -> _FakeResponse:
            calls.append(kwargs["params"])
            return _FakeResponse([*_AL_KISWAH, _TOWN])

        monkeypatch.setattr(geocoding.requests, "get", fake_get)
        hit = NominatimGeocoder().geocode("Al-Kiswah")
        assert hit is not None and (hit.osm_class, hit.osm_type, hit.lat) == ("place", "town", 33.36)
        assert calls[0]["limit"] > 1

    def test_two_requests_are_a_second_apart(self, monkeypatch: pytest.MonkeyPatch, clock: _Clock) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse([_TOWN]))
        NominatimGeocoder().geocode("a")
        NominatimGeocoder().geocode("b")
        assert clock.slept == [1.0]

    def test_a_429_waits_what_it_asks_once_then_retries(self, monkeypatch: pytest.MonkeyPatch, clock: _Clock) -> None:
        answers = iter([_FakeResponse([], 429, {"Retry-After": "7"}), _FakeResponse([_TOWN])])
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: next(answers))
        assert NominatimGeocoder().geocode("Al-Kiswah") is not None
        assert 7.0 in clock.slept

    def test_a_long_retry_after_is_bounded(self, monkeypatch: pytest.MonkeyPatch, clock: _Clock) -> None:
        answers = iter([_FakeResponse([], 429, {"Retry-After": "3600"}), _FakeResponse([_TOWN])])
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: next(answers))
        NominatimGeocoder().geocode("Al-Kiswah")
        assert max(clock.slept) == 30.0

    def test_a_second_429_is_reported_plainly(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse([], 429))
        with pytest.raises(GeocodingRefusedError, match="one request a second"):
            NominatimGeocoder().geocode("Al-Kiswah")


class TestNominatim:
    def test_builds_request_and_parses_hit(self, monkeypatch: pytest.MonkeyPatch) -> None:
        calls: dict[str, Any] = {}

        def fake_get(url: str, **kwargs: Any) -> _FakeResponse:
            calls["url"] = url
            calls["params"] = kwargs.get("params")
            calls["headers"] = kwargs.get("headers")
            return _FakeResponse([{"lat": "41.6519", "lon": "41.6367", "display_name": "Batumi, Georgia"}])

        monkeypatch.setattr(geocoding.requests, "get", fake_get)
        result = NominatimGeocoder().geocode("Batumi", bounds=Bounds(41.0, 40.0, 43.0, 42.0))

        assert result is not None
        assert (result.lat, result.lon) == (41.6519, 41.6367)
        assert result.display_name == "Batumi, Georgia"
        assert calls["params"]["q"] == "Batumi"
        assert calls["params"]["bounded"] == 1
        assert "viewbox" in calls["params"]
        assert "veaf-tools" in calls["headers"]["User-Agent"]

    def test_miss_returns_none(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse([]))
        assert NominatimGeocoder().geocode("Nowhereville") is None


class TestGoogle:
    def test_parses_hit(self, monkeypatch: pytest.MonkeyPatch) -> None:
        payload = {"results": [{"geometry": {"location": {"lat": 41.65, "lng": 41.64}}, "formatted_address": "Batumi"}]}
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse(payload))
        result = GoogleGeocoder("KEY").geocode("Batumi")
        assert result is not None
        assert (result.lat, result.lon, result.display_name) == (41.65, 41.64, "Batumi")

    def test_miss_returns_none(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(geocoding.requests, "get", lambda url, **k: _FakeResponse({"results": []}))
        assert GoogleGeocoder("KEY").geocode("Nowhereville") is None


class TestFactory:
    def test_google_when_key_present(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("GOOGLE_MAPS_API_KEY", raising=False)
        assert isinstance(get_geocoder(api_key="KEY"), GoogleGeocoder)

    def test_google_from_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("GOOGLE_MAPS_API_KEY", "KEY")
        assert isinstance(get_geocoder(), GoogleGeocoder)

    def test_nominatim_by_default(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("GOOGLE_MAPS_API_KEY", raising=False)
        assert isinstance(get_geocoder(), NominatimGeocoder)
