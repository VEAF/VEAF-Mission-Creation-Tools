"""SECREV-2 / VMR-016 — the METAR parser dropped every sub-zero temperature.

A METAR writes a negative temperature with an `M` prefix, not a minus sign: `M05/M10` is
-5 °C with a -10 °C dewpoint. The parser tested `part.lstrip("-").isdigit()`, so `M05`
failed the test and the temperature was skipped **silently** — the mission kept whatever
default was in place, and nothing said the field had been ignored.

Winter and high-altitude missions are exactly where this matters, and exactly where nobody
would think to check that the temperature they typed had survived.
"""

from __future__ import annotations

import pytest
from weather_injector.weather.dcs_weather_converter import _fallback_metar_parsing

_DEFAULTS = {"temperature": 15.0, "wind_speed": 5.0, "wind_direction": 0.0, "visibility": 10000.0}


def _temperature(metar: str) -> float:
    return _fallback_metar_parsing(metar, _DEFAULTS.copy())["temperature"]


class TestNegativeTemperatures:
    @pytest.mark.parametrize(
        ("metar", "expected"),
        [
            ("UUEE 121030Z 27015KT 9999 M05/M10 Q1013", -5.0),
            ("UUEE 121030Z 27015KT 9999 M15/M20 Q1013", -15.0),
            ("UUEE 121030Z 27015KT 9999 M01/M03 Q1013", -1.0),
            ("UUEE 121030Z 27015KT 9999 M00/M00 Q1013", 0.0),
        ],
    )
    def test_m_prefixed_temperature_is_read(self, metar: str, expected: float) -> None:
        assert _temperature(metar) == expected

    def test_a_negative_temperature_is_not_silently_defaulted(self) -> None:
        """The shape of the bug: the default survived and looked like a real reading."""
        assert _temperature("UUEE 121030Z 27015KT 9999 M05/M10 Q1013") != _DEFAULTS["temperature"]

    def test_mixed_negative_temperature_positive_dewpoint(self) -> None:
        assert _temperature("LFPG 121030Z 27015KT 9999 M02/03 Q1013") == -2.0


class TestPositiveTemperaturesStillWork:
    """Guard: the fix must not disturb the path that already worked."""

    @pytest.mark.parametrize(
        ("metar", "expected"),
        [
            ("LFPG 121030Z 27015KT 9999 15/10 Q1013", 15.0),
            ("LFPG 121030Z 27015KT 9999 05/02 Q1013", 5.0),
            ("LFPG 121030Z 27015KT 9999 30/M02 Q1013", 30.0),
        ],
    )
    def test_positive_temperature_is_read(self, metar: str, expected: float) -> None:
        assert _temperature(metar) == expected

    def test_unparseable_group_leaves_the_default(self) -> None:
        assert _temperature("LFPG 121030Z 27015KT 9999 XX/YY Q1013") == _DEFAULTS["temperature"]
