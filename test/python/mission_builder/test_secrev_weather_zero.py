"""SECREV-006 — zero-valued weather params must not be silently dropped.

The DCS weather extractor used truthiness guards (``if temp := ...``), which
discard legitimate ``0`` values: wind direction 0 (due North), wind speed 0
(calm), 0 °C temperature, 0 m visibility, ground-level cloud base.
"""

from __future__ import annotations

from pathlib import Path

from mission_builder.v5_pipeline_converters import _parse_dcs_weather_lua

_WEATHER_LUA_ZEROS = """\
["weather"] = {
    ["atmosphere_type"] = 0,
    ["season"] = { ["temperature"] = 0 },
    ["wind"] = { ["atGround"] = { ["speed"] = 0, ["dir"] = 0 } },
    ["visibility"] = { ["distance"] = 0 },
    ["clouds"] = { ["base"] = 0 },
}
"""


def _write(tmp_path: Path, body: str) -> Path:
    lua = tmp_path / "weather.lua"
    lua.write_text(body, encoding="utf-8")
    return lua


def test_zero_weather_values_are_kept(tmp_path: Path) -> None:
    params, warnings = _parse_dcs_weather_lua(_write(tmp_path, _WEATHER_LUA_ZEROS))
    assert params["temperature"] == 0
    assert params["wind_speed"] == 0
    # DCS stores where the wind blows TO; versions.yaml, like a METAR, where it comes FROM
    assert params["wind_direction"] == 180
    assert params["visibility"] == 0
    assert params["cloud_height"] == 0


def test_nonzero_weather_values_still_work(tmp_path: Path) -> None:
    body = (
        '["weather"] = {\n'
        '    ["season"] = { ["temperature"] = 23.2 },\n'
        '    ["wind"] = { ["atGround"] = { ["speed"] = 4.5, ["dir"] = 150 } },\n'
        '    ["visibility"] = { ["distance"] = 1593 },\n'
        "}\n"
    )
    params, _ = _parse_dcs_weather_lua(_write(tmp_path, body))
    assert params["temperature"] == 23.2
    assert params["wind_speed"] == 4.5
    assert params["wind_direction"] == 330
    assert params["visibility"] == 1593


def test_absent_weather_values_are_omitted(tmp_path: Path) -> None:
    body = '["weather"] = {\n    ["season"] = {},\n}\n'
    params, _ = _parse_dcs_weather_lua(_write(tmp_path, body))
    assert "temperature" not in params
    assert "wind_speed" not in params


def test_a_rainy_preset_keeps_its_rain(tmp_path: Path) -> None:
    """FIX-SCRATCH-MISSION-FINDINGS ticket 01: an unmapped preset fell back to "scattered", dry."""
    body = '["weather"] = {\n    ["clouds"] = { ["preset"] = "RainyPreset1", ["base"] = 2900 },\n}\n'
    params, _ = _parse_dcs_weather_lua(_write(tmp_path, body))
    assert params["cloud_type"] == "overcast"
    assert params["precipitation"] is True


def test_every_overcast_preset_is_mapped(tmp_path: Path) -> None:
    """Preset19 to Preset27 are all overcast (their METAR in DCS's Config/Effects/clouds.lua)."""
    for number in range(19, 28):
        body = f'["weather"] = {{\n    ["clouds"] = {{ ["preset"] = "Preset{number}" }},\n}}\n'
        params, _ = _parse_dcs_weather_lua(_write(tmp_path, body))
        assert params["cloud_type"] == "overcast", number
