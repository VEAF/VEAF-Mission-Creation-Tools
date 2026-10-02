"""Tests for the METAR composed from a manual-weather variant (FIX-OPEN-TRAINING-SYRIA-FINDINGS 10)."""

from datetime import datetime

from weather_injector.weather.metar_composer import compose_metar

_WHEN = datetime(2024, 3, 15, 9, 30)


def test_every_group_given_is_written_in_metar_order() -> None:
    manual = {
        "wind_speed": 8.0,
        "wind_direction": 268,
        "visibility": 20000,
        "cloud_type": "scattered",
        "cloud_height": 2000,
        "temperature": 25.4,
    }
    assert compose_metar(manual, _WHEN, qnh_hpa=1013.2) == "METAR 150930Z 27016KT 9999 SCT066 25/// Q1013"


def test_rain_fog_and_a_negative_temperature() -> None:
    manual = {"visibility": 800, "precipitation": True, "fog_enabled": True, "cloud_type": "overcast", "temperature": -4.6}
    assert compose_metar(manual, _WHEN) == "METAR 150930Z 0800 RA FG OVC/// M05///"


def test_calm_wind_and_a_clear_sky() -> None:
    assert compose_metar({"wind_speed": 0, "cloud_type": "clear"}, _WHEN) == "METAR 150930Z 00000KT SKC"


def test_a_north_wind_reads_360() -> None:
    assert compose_metar({"wind_speed": 5, "wind_direction": 2}, _WHEN) == "METAR 150930Z 36010KT"
