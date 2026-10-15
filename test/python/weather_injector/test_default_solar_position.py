"""Where solar times are computed when ``versions.yaml`` gives no ``position`` (FIX-SOLAR-DEFAULT-POSITION).

Why this exists: the shipped ``versions.yaml`` declared a Damascus position, so a Caucasus mission keeping
it started its ``sunrise`` variant at 07:48 on 2024-03-15, 24 minutes after sunrise at Kobuleti (50 in
June); and a file without ``position`` aborted the build on the first solar expression.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

import pytest
import yaml
from mission_tools.miz_tools import read_miz
from veaf_libs import coordinates
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.geocoding import theatre_bounds
from weather_injector.utils.theatre_position import theatre_position
from weather_injector.weather_injector_worker import WeatherInjectorWorker


def _blank_miz(path: Path, theatre: str) -> Path:
    with zipfile.ZipFile(path, "w") as miz:
        for name, data in generate_blank_mission(theatre).items():
            miz.writestr(name, data)
    return path


def _built_start_time(tmp_path: Path, theatre: str, config: dict) -> int:
    """Build the variants of ``config`` on a blank mission of ``theatre``; the first one's ``start_time``."""
    config_file = tmp_path / "versions.yaml"
    config_file.write_text(yaml.safe_dump(config), encoding="utf-8")
    mission = _blank_miz(tmp_path / "base.miz", theatre)
    built = WeatherInjectorWorker(config_file, mission, tmp_path / "out").work()
    assert built, "no variant built"
    content = read_miz(built[0]).mission_content
    assert content is not None
    return int(content["start_time"])


_SUNRISE_VARIANT = {"base_date": "2024-03-15", "versions": [{"name": "dawn", "time": "sunrise"}]}


def test_a_caucasus_mission_without_position_gets_the_caucasus_sunrise(tmp_path: Path) -> None:
    start = _built_start_time(tmp_path, "Caucasus", _SUNRISE_VARIANT)
    # Sunrise near Batumi on 2024-03-15 is 07:24-07:25 on the Caucasus clock (UTC+4); Damascus's is 07:48.
    assert 7 * 3600 + 20 * 60 <= start <= 7 * 3600 + 30 * 60, f"start_time {start // 3600:02d}:{start % 3600 // 60:02d}"


def test_an_explicit_position_still_wins(tmp_path: Path) -> None:
    config = {**_SUNRISE_VARIANT, "position": {"latitude": 33.5, "longitude": 35.5, "timezone": "Asia/Damascus"}}
    start = _built_start_time(tmp_path, "Caucasus", config)
    assert 7 * 3600 + 45 * 60 <= start <= 7 * 3600 + 50 * 60


def test_a_position_outside_the_theatre_is_warned(tmp_path: Path, caplog: pytest.LogCaptureFixture) -> None:
    config = {**_SUNRISE_VARIANT, "position": {"latitude": 33.5, "longitude": 35.5, "timezone": "Asia/Damascus"}}
    with caplog.at_level("WARNING"):
        _built_start_time(tmp_path, "Caucasus", config)
    assert any("Caucasus" in record.getMessage() and "33.5" in record.getMessage() for record in caplog.records)


def test_a_position_inside_the_theatre_is_not_warned(tmp_path: Path, caplog: pytest.LogCaptureFixture) -> None:
    config = {**_SUNRISE_VARIANT, "position": {"latitude": 41.93, "longitude": 41.86, "timezone": "Asia/Tbilisi"}}
    with caplog.at_level("WARNING"):
        _built_start_time(tmp_path, "Caucasus", config)
    assert not [record for record in caplog.records if record.levelname == "WARNING"]


@pytest.mark.parametrize("theatre", coordinates.supported_theatres())
def test_every_supported_theatre_has_a_point_inside_its_bounds(theatre: str) -> None:
    position = theatre_position(theatre)
    assert position is not None
    bounds = theatre_bounds(theatre)
    assert bounds is not None
    assert bounds.min_lat <= position.latitude <= bounds.max_lat
    assert bounds.min_lon <= position.longitude <= bounds.max_lon


def test_the_timezone_is_the_nominal_zone_of_the_longitude() -> None:
    # Only read for a theatre whose DCS clock is not in theatre_offsets.py, such as Iraq (UTC+3).
    position = theatre_position("Iraq")
    assert position is not None
    assert position.timezone == "Etc/GMT-3"


@pytest.mark.parametrize("theatre", [None, "", "NoSuchMap"])
def test_no_point_for_an_unknown_theatre(theatre: str | None) -> None:
    assert theatre_position(theatre) is None
