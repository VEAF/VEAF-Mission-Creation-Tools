"""Shared fixtures for the weather-injector tests.

Why this file exists: FEAT-BRIEFING-METAR made ``_fetch_live_metar`` memoised per ICAO, so one station
is asked once per process. Two consumers now share that answer — the DCS weather table and the
briefing's ``${METAR}`` — and they must agree, since a station publishing between two requests would
otherwise put a METAR in the briefing contradicting the weather actually injected (Sourcery, PR #786).

A process-wide cache is state, and state leaks between tests: two of the existing fetch tests started
failing because the second one received the first one's answer. Clearing it per test here rather than
per test case keeps that from being a trap the next test in this directory falls into.
"""

from __future__ import annotations

import pytest
from weather_injector.weather.dcs_weather_converter import clear_metar_cache


@pytest.fixture(autouse=True)
def _fresh_metar_cache() -> None:
    """Start every weather test with no memoised METAR."""
    clear_metar_cache()
