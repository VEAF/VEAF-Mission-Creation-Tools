"""Tests for WeatherInjectorWorker — pure-Python, no DCS runtime."""

from __future__ import annotations

import tempfile
import unittest
import unittest.mock
from datetime import date as dt_date
from datetime import timedelta
from pathlib import Path
from typing import Any

import typer
import yaml
from mission_tools.miz_tools import DcsMission
from weather_injector.models import MissionConfig, Position, VersionConfig
from weather_injector.weather_injector_worker import WeatherInjectorWorker

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_worker(tmp_path: Path) -> WeatherInjectorWorker:
    """Create a minimal WeatherInjectorWorker using a temp directory."""
    config: dict[str, Any] = {"versions": [{"name": "test"}]}
    config_file = tmp_path / "versions.yaml"
    config_file.write_text(yaml.dump(config), encoding="utf-8")
    mission_file = tmp_path / "test.miz"
    mission_file.write_bytes(b"PK\x03\x04")  # minimal fake zip header
    output_dir = tmp_path / "out"
    return WeatherInjectorWorker(config_file=config_file, mission_file=mission_file, output_dir=output_dir)


# ---------------------------------------------------------------------------
# _parse_date — static method
# ---------------------------------------------------------------------------


class TestParseDateKeywords(unittest.TestCase):
    def test_today(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("today"), dt_date.today())

    def test_today_uppercase(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("TODAY"), dt_date.today())

    def test_tomorrow(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("tomorrow"), dt_date.today() + timedelta(days=1))

    def test_yesterday(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("yesterday"), dt_date.today() - timedelta(days=1))

    def test_leading_trailing_spaces(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("  today  "), dt_date.today())


class TestParseDateRelative(unittest.TestCase):
    def test_plus_three(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("+3"), dt_date.today() + timedelta(days=3))

    def test_minus_two(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("-2"), dt_date.today() - timedelta(days=2))

    def test_plus_zero(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("+0"), dt_date.today())


class TestParseDateISO(unittest.TestCase):
    def test_specific_date(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("2024-03-15"), dt_date(2024, 3, 15))

    def test_first_of_jan(self) -> None:
        self.assertEqual(WeatherInjectorWorker._parse_date("2000-01-01"), dt_date(2000, 1, 1))


class TestParseDateInvalid(unittest.TestCase):
    def test_invalid_string_raises(self) -> None:
        with self.assertRaises(ValueError):
            WeatherInjectorWorker._parse_date("not-a-date")

    def test_invalid_relative_plus_letters_raises(self) -> None:
        # "+abc" starts with "+" but int("+abc") raises ValueError,
        # then fromisoformat also fails → final ValueError
        with self.assertRaises(ValueError):
            WeatherInjectorWorker._parse_date("+abc")


# ---------------------------------------------------------------------------
# __init__ — constructor
# ---------------------------------------------------------------------------


class TestWorkerInit(unittest.TestCase):
    def test_init_creates_output_dir(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            self.assertTrue(worker.output_dir.exists())

    def test_init_stores_paths(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            self.assertIsInstance(worker.config_file, Path)
            self.assertIsInstance(worker.mission_file, Path)
            self.assertIsInstance(worker.output_dir, Path)

    def test_init_config_and_mission_data_none(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            self.assertIsNone(worker.config)
            self.assertIsNone(worker.mission_data)


# ---------------------------------------------------------------------------
# _load_configuration
# ---------------------------------------------------------------------------


class TestLoadConfiguration(unittest.TestCase):
    def test_valid_yaml_returns_mission_config(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            config = worker._load_configuration()
            self.assertIsNotNone(config)
            self.assertIsInstance(config, MissionConfig)

    def test_valid_yaml_with_versions(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_data: dict[str, Any] = {
                "versions": [
                    {"name": "day"},
                    {"name": "night"},
                ]
            }
            config_file = tmp_path / "versions.yaml"
            config_file.write_text(yaml.dump(config_data), encoding="utf-8")
            mission_file = tmp_path / "test.miz"
            mission_file.write_bytes(b"PK")
            worker = WeatherInjectorWorker(config_file=config_file, mission_file=mission_file)
            config = worker._load_configuration()
            self.assertIsNotNone(config)
            assert config is not None
            self.assertEqual(len(config.versions), 2)
            self.assertEqual(config.versions[0].name, "day")

    def test_missing_file_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config_file = tmp_path / "nonexistent.yaml"
            with self.assertRaises((typer.Abort, SystemExit)):
                worker._load_configuration()

    def test_invalid_yaml_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config_file.write_text("invalid: yaml: [[[", encoding="utf-8")
            with self.assertRaises((typer.Abort, SystemExit)):
                worker._load_configuration()


# ---------------------------------------------------------------------------
# _set_mission_time / _set_mission_date / _set_mission_weather
# ---------------------------------------------------------------------------


class TestSetMissionTime(unittest.TestCase):
    def _make_worker_with_content(self, content: dict) -> WeatherInjectorWorker:
        import tempfile

        from mission_tools import DcsMission

        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp_path = Path(tmp_dir.name)
        worker = _make_worker(tmp_path)
        worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=content)
        return worker

    def test_set_time_stores_seconds(self) -> None:
        content: dict[str, Any] = {"start_time": 0}  # non-empty so not falsy
        worker = self._make_worker_with_content(content)
        worker._set_mission_time(36000)
        self.assertEqual(content["start_time"], 36000)

    def test_set_time_no_mission_data_noop(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            # Should not raise
            worker._set_mission_time(3600)

    def test_set_time_no_content_noop(self) -> None:
        import tempfile

        from mission_tools import DcsMission

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=None)
            worker._set_mission_time(3600)  # should not raise


class TestSetMissionDate(unittest.TestCase):
    def _make_worker_with_content(self, content: dict) -> WeatherInjectorWorker:
        import tempfile

        from mission_tools import DcsMission

        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp_path = Path(tmp_dir.name)
        worker = _make_worker(tmp_path)
        worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=content)
        return worker

    def test_set_date_stores_day_month_year(self) -> None:
        content: dict[str, Any] = {"missions": {}}  # non-empty so not falsy
        worker = self._make_worker_with_content(content)
        worker._set_mission_date(dt_date(2024, 6, 21))
        self.assertEqual(content["date"]["Day"], 21)
        self.assertEqual(content["date"]["Month"], 6)
        self.assertEqual(content["date"]["Year"], 2024)

    def test_set_date_updates_existing(self) -> None:
        content: dict[str, Any] = {"date": {"Day": 1, "Month": 1, "Year": 2000}}
        worker = self._make_worker_with_content(content)
        worker._set_mission_date(dt_date(2025, 12, 25))
        self.assertEqual(content["date"]["Year"], 2025)

    def test_set_date_no_mission_data_noop(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker._set_mission_date(dt_date(2024, 1, 1))  # should not raise


class TestSetMissionWeather(unittest.TestCase):
    def _make_worker_with_content(self, content: dict) -> WeatherInjectorWorker:
        import tempfile

        from mission_tools import DcsMission

        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp_path = Path(tmp_dir.name)
        worker = _make_worker(tmp_path)
        worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=content)
        return worker

    def test_set_weather_merges_data(self) -> None:
        content: dict[str, Any] = {"missions": {}}  # non-empty so not falsy
        worker = self._make_worker_with_content(content)
        weather = {"atmosphere": {"temperature_celsius": 20.0}}
        worker._set_mission_weather(weather)
        self.assertEqual(content["weather"]["atmosphere"]["temperature_celsius"], 20.0)

    def test_set_weather_no_mission_data_noop(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker._set_mission_weather({"fog": {"enabled": True}})  # should not raise


# ---------------------------------------------------------------------------
# MissionConfig.from_dict
# ---------------------------------------------------------------------------


class TestMissionConfigFromDict(unittest.TestCase):
    def test_minimal_config(self) -> None:
        config = MissionConfig.from_dict({"versions": []})
        self.assertIsNone(config.position)
        self.assertEqual(config.versions, [])

    def test_with_position(self) -> None:
        data = {
            "position": {"latitude": 33.4, "longitude": 36.5, "timezone": "Asia/Damascus"},
            "versions": [],
        }
        config = MissionConfig.from_dict(data)
        self.assertIsNotNone(config.position)
        assert config.position is not None
        self.assertAlmostEqual(config.position.latitude, 33.4)
        self.assertAlmostEqual(config.position.longitude, 36.5)
        self.assertEqual(config.position.timezone, "Asia/Damascus")

    def test_with_base_date(self) -> None:
        config = MissionConfig.from_dict({"base_date": "2024-06-21", "versions": []})
        self.assertEqual(config.base_date, "2024-06-21")

    def test_version_with_all_fields(self) -> None:
        data = {
            "versions": [
                {
                    "name": "morning",
                    "time": "08:00",
                    "date": "today",
                    "metar": "OSDI 151420Z 27015KT 9999 SKC 15/10 Q1018",
                    "clearsky": True,
                }
            ]
        }
        config = MissionConfig.from_dict(data)
        v = config.versions[0]
        self.assertEqual(v.name, "morning")
        self.assertEqual(v.time, "08:00")
        self.assertTrue(v.clearsky)

    def test_version_clearsky_default_false(self) -> None:
        data = {"versions": [{"name": "test"}]}
        config = MissionConfig.from_dict(data)
        self.assertFalse(config.versions[0].clearsky)

    def test_multiple_versions(self) -> None:
        data = {
            "versions": [
                {"name": "v1"},
                {"name": "v2"},
                {"name": "v3"},
            ]
        }
        config = MissionConfig.from_dict(data)
        self.assertEqual(len(config.versions), 3)
        self.assertEqual(config.versions[2].name, "v3")


# ---------------------------------------------------------------------------
# Position dataclass
# ---------------------------------------------------------------------------


class TestPosition(unittest.TestCase):
    def test_position_stores_fields(self) -> None:
        pos = Position(latitude=48.8566, longitude=2.3522, timezone="Europe/Paris")
        self.assertAlmostEqual(pos.latitude, 48.8566)
        self.assertAlmostEqual(pos.longitude, 2.3522)
        self.assertEqual(pos.timezone, "Europe/Paris")


# ---------------------------------------------------------------------------
# VersionConfig dataclass
# ---------------------------------------------------------------------------


class TestVersionConfig(unittest.TestCase):
    def test_minimal_version(self) -> None:
        v = VersionConfig(name="test")
        self.assertEqual(v.name, "test")
        self.assertIsNone(v.time)
        self.assertIsNone(v.date)
        self.assertFalse(v.clearsky)

    def test_version_with_weather(self) -> None:
        v = VersionConfig(name="rain", weather={"visibility": 3000.0})
        self.assertIsNotNone(v.weather)
        assert v.weather is not None
        self.assertEqual(v.weather["visibility"], 3000.0)


# ---------------------------------------------------------------------------
# _set_mission_date / _set_mission_weather — None mission_content branches
# ---------------------------------------------------------------------------


class TestSetMissionDateNoneContent(unittest.TestCase):
    def test_none_mission_content_is_noop(self) -> None:
        import tempfile

        from mission_tools import DcsMission

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=None)
            # Covers line 267: if not mission_content: return
            worker._set_mission_date(dt_date(2024, 6, 15))


class TestSetMissionWeatherNoneContent(unittest.TestCase):
    def test_none_mission_content_is_noop(self) -> None:
        import tempfile

        from mission_tools import DcsMission

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.mission_data = DcsMission(file_path=tmp_path / "test.miz", mission_content=None)
            # Covers line 289: if not mission_content: return
            worker._set_mission_weather({"fog": True})


# ---------------------------------------------------------------------------
# _calculate_solar_times
# ---------------------------------------------------------------------------


class TestCalculateSolarTimes(unittest.TestCase):
    def test_with_valid_position(self) -> None:
        import tempfile

        from weather_injector.models import MissionConfig, Position, VersionConfig

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = MissionConfig(
                versions=[VersionConfig(name="test")],
                position=Position(latitude=48.8566, longitude=2.3522, timezone="Europe/Paris"),
            )
            worker._calculate_solar_times()
            self.assertIn("sunrise", worker.solar_times)
            self.assertIn("sunset", worker.solar_times)

    def test_with_base_date(self) -> None:
        import tempfile

        from weather_injector.models import MissionConfig, Position, VersionConfig

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = MissionConfig(
                versions=[VersionConfig(name="test")],
                position=Position(latitude=33.4, longitude=36.5, timezone="Asia/Damascus"),
                base_date="2024-06-21",
            )
            worker._calculate_solar_times()
            self.assertIn("sunrise", worker.solar_times)

    def test_no_position_skipped(self) -> None:
        import tempfile

        from weather_injector.models import MissionConfig, VersionConfig

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = MissionConfig(versions=[VersionConfig(name="test")], position=None)
            worker._calculate_solar_times()
            self.assertEqual(worker.solar_times, {})

    def test_no_config_skipped(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = None
            worker._calculate_solar_times()
            self.assertEqual(worker.solar_times, {})


# ---------------------------------------------------------------------------
# _update_mission_time_and_date
# ---------------------------------------------------------------------------


class TestUpdateMissionTimeAndDate(unittest.TestCase):
    def _worker_with_mission(self) -> WeatherInjectorWorker:
        import tempfile

        from mission_tools import DcsMission

        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp_path = Path(tmp_dir.name)
        worker = _make_worker(tmp_path)
        worker.config = MissionConfig(versions=[])
        worker.mission_data = DcsMission(
            file_path=tmp_path / "test.miz",
            mission_content={"start_time": 0, "date": {}},
        )
        return worker

    def test_update_time(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(name="test", time="10:30")
        worker._update_mission_time_and_date(version)
        expected_seconds = 10 * 3600 + 30 * 60
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertEqual(worker.mission_data.mission_content["start_time"], expected_seconds)

    def test_update_date(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(name="test", date="2024-06-15")
        worker._update_mission_time_and_date(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertEqual(worker.mission_data.mission_content["date"]["Day"], 15)
        self.assertEqual(worker.mission_data.mission_content["date"]["Month"], 6)
        self.assertEqual(worker.mission_data.mission_content["date"]["Year"], 2024)

    def test_update_time_and_date_together(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(name="test", time="08:00", date="2024-12-25")
        worker._update_mission_time_and_date(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertEqual(worker.mission_data.mission_content["start_time"], 8 * 3600)
        self.assertEqual(worker.mission_data.mission_content["date"]["Day"], 25)

    def test_no_mission_data_noop(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = MissionConfig(versions=[])
            worker.mission_data = None
            version = VersionConfig(name="test", time="10:00")
            worker._update_mission_time_and_date(version)  # should not raise

    def test_solar_offset_time(self) -> None:
        worker = self._worker_with_mission()
        worker.solar_times = {"sunrise": 25200, "sunset": 72000}  # 7:00 and 20:00
        version = VersionConfig(name="test", time="sunrise+30*60")  # +30 minutes
        worker._update_mission_time_and_date(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        expected = 25200 + 30 * 60
        self.assertEqual(worker.mission_data.mission_content["start_time"], expected)


# ---------------------------------------------------------------------------
# _inject_weather
# ---------------------------------------------------------------------------


class TestInjectWeather(unittest.TestCase):
    def _worker_with_mission(self) -> WeatherInjectorWorker:
        import tempfile

        from mission_tools import DcsMission

        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp_path = Path(tmp_dir.name)
        worker = _make_worker(tmp_path)
        worker.config = MissionConfig(versions=[])
        worker.mission_data = DcsMission(
            file_path=tmp_path / "test.miz",
            mission_content={"weather": {}, "start_time": 0},
        )
        return worker

    def test_inject_weather_with_metar(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(name="test", metar="EGLL 010850Z 09010KT CAVOK 15/08 Q1018")
        worker._inject_weather(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertIn("weather", worker.mission_data.mission_content)

    def test_inject_weather_with_empty_metar(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(name="test", metar="")
        worker._inject_weather(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertIn("weather", worker.mission_data.mission_content)

    def test_inject_weather_with_params(self) -> None:
        worker = self._worker_with_mission()
        version = VersionConfig(
            name="test",
            weather={"temperature": 20.0, "wind_speed": 5.0, "wind_direction": 180.0},
        )
        worker._inject_weather(version)
        assert worker.mission_data is not None
        assert worker.mission_data.mission_content is not None
        self.assertIn("weather", worker.mission_data.mission_content)

    def test_inject_weather_clearsky_caps_wind(self) -> None:
        import tempfile

        from mission_tools import DcsMission

        tmp = tempfile.mkdtemp()
        tmp_path = Path(tmp)
        worker = _make_worker(tmp_path)
        worker.config = MissionConfig(versions=[])
        worker.mission_data = DcsMission(
            file_path=tmp_path / "test.miz",
            mission_content={"weather": {}, "start_time": 0},
        )
        version = VersionConfig(
            name="test",
            metar="EGLL 010850Z 09035KT CAVOK 15/08 Q1018",  # 35kt wind
            clearsky=True,
        )
        worker._inject_weather(version)

    def test_inject_weather_no_mission_data_noop(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            worker = _make_worker(tmp_path)
            worker.config = MissionConfig(versions=[])
            worker.mission_data = None
            version = VersionConfig(name="test", metar="EGLL 010850Z 09010KT CAVOK 15/08 Q1018")
            worker._inject_weather(version)  # should not raise


# ---------------------------------------------------------------------------
# mission_base_name — output path and sanitization
# ---------------------------------------------------------------------------


class TestMissionBaseNameOutput(unittest.TestCase):
    def _patched_worker(
        self,
        tmp_path: Path,
        mission_base_name: str | None,
        version_name: str = "dawn",
    ) -> tuple[WeatherInjectorWorker, VersionConfig]:
        """Build a worker with read_miz/write_miz patched out."""
        from unittest.mock import MagicMock, patch

        config_data: dict[str, Any] = {"versions": [{"name": version_name}]}
        config_file = tmp_path / "versions.yaml"
        config_file.write_text(yaml.dump(config_data), encoding="utf-8")
        mission_file = tmp_path / "test.miz"
        mission_file.write_bytes(b"PK\x03\x04")
        output_dir = tmp_path / "missions"

        worker = WeatherInjectorWorker(
            config_file=config_file,
            mission_file=mission_file,
            output_dir=output_dir,
            mission_base_name=mission_base_name,
        )

        fake_mission = MagicMock()
        fake_mission.mission_content = {"start_time": 0}
        version = VersionConfig(name=version_name)

        self._read_patcher = patch("weather_injector.weather_injector_worker.read_miz", return_value=fake_mission)
        self._write_patcher = patch("weather_injector.weather_injector_worker.write_miz")
        self._read_patcher.start()
        self._write_patcher.start()
        self.addCleanup(self._read_patcher.stop)
        self.addCleanup(self._write_patcher.stop)

        return worker, version

    def test_output_prefixed_with_base_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            worker, version = self._patched_worker(Path(tmp), "VEAF-Demo")
            result = worker._create_mission_version(version)
        self.assertEqual(result.name, "VEAF-Demo_dawn.miz")

    def test_output_without_base_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            worker, version = self._patched_worker(Path(tmp), None)
            result = worker._create_mission_version(version)
        self.assertEqual(result.name, "dawn.miz")

    def test_base_name_stored_on_init(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_file = tmp_path / "v.yaml"
            config_file.write_text(yaml.dump({"versions": []}), encoding="utf-8")
            mission_file = tmp_path / "test.miz"
            mission_file.write_bytes(b"PK")
            worker = WeatherInjectorWorker(
                config_file=config_file,
                mission_file=mission_file,
                mission_base_name="VEAF-Demo",
            )
        self.assertEqual(worker.mission_base_name, "VEAF-Demo")

    def test_base_name_sanitized_on_init(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            config_file = tmp_path / "v.yaml"
            config_file.write_text(yaml.dump({"versions": []}), encoding="utf-8")
            mission_file = tmp_path / "test.miz"
            mission_file.write_bytes(b"PK")
            worker = WeatherInjectorWorker(
                config_file=config_file,
                mission_file=mission_file,
                mission_base_name="My:Mission/Name*",
            )
        self.assertEqual(worker.mission_base_name, "My_Mission_Name_")


if __name__ == "__main__":
    unittest.main()


# ---------------------------------------------------------------------------
# FEAT-BRIEFING-METAR (#40) — ${METAR} per build variant
#
# The lot's second "check this first": a mission built in seven weather variants needs seven different
# METARs, so the substitution runs inside the per-variant build rather than once around it. These tests
# are on `_substitute_briefing_variables` directly, because driving `_create_mission_version` needs a
# real .miz.
# ---------------------------------------------------------------------------


def _mission_with_briefing(text: str) -> DcsMission:
    """A mission whose situation briefing is *text*, held inline."""
    return DcsMission(file_path=Path("unused.miz"), mission_content={"descriptionText": text})


class TestBriefingMetarPerVariant(unittest.TestCase):
    def test_the_variant_metar_is_what_lands_in_the_briefing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("Weather: ${METAR}")
            worker._substitute_briefing_variables(VersionConfig(name="day", metar="LFRS 121030Z 22015KT"))
            assert worker.mission_data.mission_content is not None
            self.assertEqual(worker.mission_data.mission_content["descriptionText"], "Weather: LFRS 121030Z 22015KT")

    def test_two_variants_of_one_mission_get_their_own_metar(self) -> None:
        # The DoD asks for exactly this. Each variant starts from a fresh read of the base mission in the
        # real flow, so the briefing is re-substituted per variant rather than accumulated.
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            results = []
            for version in (
                VersionConfig(name="day", metar="LFRS 121030Z 22015KT"),
                VersionConfig(name="night", metar="LFRS 122130Z 00000KT"),
            ):
                worker.mission_data = _mission_with_briefing("METAR: ${METAR}")
                worker._substitute_briefing_variables(version)
                assert worker.mission_data.mission_content is not None
                results.append(worker.mission_data.mission_content["descriptionText"])
            self.assertEqual(results, ["METAR: LFRS 121030Z 22015KT", "METAR: LFRS 122130Z 00000KT"])

    def test_a_variant_without_a_metar_leaves_the_token_written(self) -> None:
        # A variant built from individual weather parameters has no METAR string to show. Leaving the
        # token beats blanking it: the briefing is player-facing text, and a hole reads as the build
        # having eaten the prose.
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("Weather: ${METAR}")
            worker._substitute_briefing_variables(VersionConfig(name="params", weather={"temperature": 20}))
            assert worker.mission_data.mission_content is not None
            self.assertEqual(worker.mission_data.mission_content["descriptionText"], "Weather: ${METAR}")

    def test_an_icao_variant_fetches_the_metar_text(self) -> None:
        called: list[str] = []

        def _fake_fetch(icao: str) -> str:
            called.append(icao)
            return "LFRS 121030Z 22015KT CAVOK"

        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("${METAR}")
            with unittest.mock.patch(
                "weather_injector.weather_injector_worker.fetch_metar_string", side_effect=_fake_fetch
            ):
                worker._substitute_briefing_variables(VersionConfig(name="live", airport_icao="LFRS"))
            assert worker.mission_data.mission_content is not None
            self.assertEqual(worker.mission_data.mission_content["descriptionText"], "LFRS 121030Z 22015KT CAVOK")
            self.assertEqual(called, ["LFRS"])

    def test_no_network_call_when_the_briefing_never_asks(self) -> None:
        # The reason the fetch is a separate function: a build that does not mention ${METAR} must not
        # pay for a weather request.
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("Take off at dawn.")
            with unittest.mock.patch("weather_injector.weather_injector_worker.fetch_metar_string") as fetch:
                worker._substitute_briefing_variables(VersionConfig(name="live", airport_icao="LFRS"))
            fetch.assert_not_called()

    def test_a_failed_fetch_leaves_the_token_rather_than_inserting_nothing(self) -> None:
        # A weather outage must not silently blank a briefing line.
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("Weather: ${METAR}")
            with unittest.mock.patch("weather_injector.weather_injector_worker.fetch_metar_string", return_value=""):
                worker._substitute_briefing_variables(VersionConfig(name="live", airport_icao="LFRS"))
            assert worker.mission_data.mission_content is not None
            self.assertEqual(worker.mission_data.mission_content["descriptionText"], "Weather: ${METAR}")

    def test_a_written_metar_wins_over_an_icao_without_fetching(self) -> None:
        # Same precedence the weather conversion already uses: metar > airport_icao.
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = _mission_with_briefing("${METAR}")
            with unittest.mock.patch("weather_injector.weather_injector_worker.fetch_metar_string") as fetch:
                worker._substitute_briefing_variables(VersionConfig(name="both", metar="WRITTEN", airport_icao="LFRS"))
            fetch.assert_not_called()
            assert worker.mission_data.mission_content is not None
            self.assertEqual(worker.mission_data.mission_content["descriptionText"], "WRITTEN")

    def test_no_mission_loaded_is_not_a_crash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            worker = _make_worker(Path(tmp))
            worker.mission_data = None
            worker._substitute_briefing_variables(VersionConfig(name="day", metar="X"))
