"""Tests for the pluggable geocoder (FEAT-GEO-PLACEMENT-001). HTTP is mocked — no live network."""

from typing import Any

import pytest
from veaf_libs import geocoding
from veaf_libs.geocoding import Bounds, GoogleGeocoder, NominatimGeocoder, get_geocoder


class _FakeResponse:
    def __init__(self, payload: Any) -> None:
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> Any:
        return self._payload


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
