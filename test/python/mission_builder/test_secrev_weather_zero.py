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
    assert params["wind_direction"] == 0
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
    assert params["wind_direction"] == 150
    assert params["visibility"] == 1593


def test_absent_weather_values_are_omitted(tmp_path: Path) -> None:
    body = '["weather"] = {\n    ["season"] = {},\n}\n'
    params, _ = _parse_dcs_weather_lua(_write(tmp_path, body))
    assert "temperature" not in params
    assert "wind_speed" not in params
