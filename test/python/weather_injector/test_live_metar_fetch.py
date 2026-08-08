"""SECREV-2 / VMR-006 — the live METAR fetch never fetched.

`Metar(icao)` only constructs the object; `.update()` is what performs the request. Without
it every attribute read afterwards is None, so the converter returned its canned defaults —
while logging "Successfully fetched". A mission asking for live weather silently got
invented weather, and nothing said so.

These tests fake avwx entirely, so they neither need the package installed nor touch the
network.
"""

from __future__ import annotations

from typing import Any

import pytest
from weather_injector.weather import dcs_weather_converter as conv


class _Value:
    def __init__(self, value: Any) -> None:
        self.value = value


class _FakeMetar:
    """Stands in for `avwx.current.metar.Metar`, recording whether update() was called."""

    instances: list[_FakeMetar] = []

    def __init__(self, icao: str, *, update_returns: bool = True) -> None:
        self.icao = icao
        self.updated = False
        self._update_returns = update_returns
        # Values only become readable after a successful update, exactly like avwx.
        self.temperature: _Value | None = None
        self.wind_speed: _Value | None = None
        self.wind_direction: _Value | None = None
        self.visibility: list[_Value] | None = None
        self.clouds: list[Any] | None = None
        _FakeMetar.instances.append(self)

    def update(self) -> bool:
        self.updated = True
        if not self._update_returns:
            return False
        self.temperature = _Value(21.0)
        self.wind_speed = _Value(19.44)  # knots -> 10 m/s
        self.wind_direction = _Value(270)
        self.visibility = [_Value(8000.0)]
        self.clouds = [("BKN", _Value(1200.0))]
        return True


@pytest.fixture(autouse=True)
def _reset() -> None:
    _FakeMetar.instances = []


def _install(monkeypatch: pytest.MonkeyPatch, *, update_returns: bool = True) -> None:
    monkeypatch.setattr(conv, "AVWX_AVAILABLE", True)
    monkeypatch.setattr(conv, "Metar", lambda icao: _FakeMetar(icao, update_returns=update_returns), raising=False)


class TestTheFetchActuallyHappens:
    def test_update_is_called(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """The regression itself: without this call the request is never made."""
        _install(monkeypatch)
        conv._fetch_live_metar("LFPG")
        assert _FakeMetar.instances[0].updated is True

    def test_fetched_values_reach_the_result(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _install(monkeypatch)
        result = conv._fetch_live_metar("LFPG")
        assert result["temperature"] == 21.0
        assert result["wind_direction"] == 270.0
        assert result["visibility"] == 8000.0
        assert result["cloud_type"] == 3  # BKN
        assert result["cloud_height"] == 1200.0
        assert round(result["wind_speed"], 2) == 10.0  # knots converted to m/s

    def test_result_differs_from_the_defaults(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Guards the shape of the bug rather than its symptom: defaults returned as if live."""
        _install(monkeypatch)
        result = conv._fetch_live_metar("LFPG")
        assert result["temperature"] != 15.0
        assert result["visibility"] != 10000.0


class TestFallbackAnnouncesItself:
    def test_failed_update_falls_back_to_defaults(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _install(monkeypatch, update_returns=False)
        result = conv._fetch_live_metar("ZZZZ")
        assert result["temperature"] == 15.0
        assert result["visibility"] == 10000.0

    def test_failed_update_warns(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Silently falling back to defaults is what hid this for a month."""
        _install(monkeypatch, update_returns=False)
        warnings: list[str] = []
        monkeypatch.setattr(conv.logger, "warning", lambda message, *a, **k: warnings.append(str(message)))
        conv._fetch_live_metar("ZZZZ")
        assert warnings, "a failed fetch must say so"
        assert "ZZZZ" in warnings[0]

    def test_avwx_absent_still_warns_and_returns_defaults(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(conv, "AVWX_AVAILABLE", False)
        warnings: list[str] = []
        monkeypatch.setattr(conv.logger, "warning", lambda message, *a, **k: warnings.append(str(message)))
        result = conv._fetch_live_metar("LFPG")
        assert result["temperature"] == 15.0
        assert warnings

    def test_message_exists_in_both_locales(self) -> None:
        from veaf_libs.i18n import t

        for locale in ("en", "fr"):
            message = t("weather.converter.metar_fetch_empty", locale=locale, icao="LFPG")
            assert message != "weather.converter.metar_fetch_empty"
            assert "LFPG" in message
