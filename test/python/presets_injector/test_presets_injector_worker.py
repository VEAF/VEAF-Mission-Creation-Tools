"""Tests for PresetsInjectorWorker — init, load_config, add_group, process_units, process_groups."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

from mission_tools import Group
from presets_injector.presets_injector_worker import PresetsInjectorWorker
from presets_injector.presets_manager import PresetDefinition


def _make_worker(presets_file: Path | None = None) -> PresetsInjectorWorker:
    return PresetsInjectorWorker(presets_file=presets_file, input_mission=None, output_mission=None)


class TestPresetsInjectorWorkerInit(unittest.TestCase):
    def test_init_without_presets_file(self) -> None:
        worker = _make_worker()
        self.assertIsNone(worker.presets_file)
        self.assertIsNone(worker.input_mission)
        self.assertIsNone(worker.output_mission)
        self.assertEqual(worker.groups, {})
        self.assertIsNotNone(worker.presets_manager)

    def test_init_stores_presets_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            presets_file = Path(tmpdir) / "presets.yaml"
            presets_file.write_text("presets: {}", encoding="utf-8")
            worker = _make_worker(presets_file=presets_file)
            self.assertEqual(worker.presets_file, presets_file)


class TestLoadConfig(unittest.TestCase):
    def test_load_config_without_file_returns_empty_manager(self) -> None:
        worker = _make_worker()
        manager = worker.presets_manager
        self.assertIsNotNone(manager)

    def test_load_config_with_nonexistent_file_raises(self) -> None:
        with self.assertRaises((RuntimeError, SystemExit)):
            _make_worker(presets_file=Path("/nonexistent/path/presets.yaml"))


class TestAddGroup(unittest.TestCase):
    def test_add_group_with_name_stored(self) -> None:
        worker = _make_worker()
        group = Group(group_dcs={"name": "F-16 Alpha"}, aircraft_type="plane", country="USA", coalition="blue", name="F-16 Alpha")
        worker.add_group(group)
        self.assertIn("F-16 Alpha", worker.groups)

    def test_add_group_without_name_not_stored(self) -> None:
        worker = _make_worker()
        group = Group(group_dcs={}, aircraft_type="plane", country="USA", coalition="blue")
        worker.add_group(group)
        self.assertEqual(len(worker.groups), 0)

    def test_add_group_human_pilot_detected(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"name": "Human Group"},
            aircraft_type="plane", country="USA", coalition="blue",
            name="Human Group", unit_type="F-16C_50", human_pilot=True,
        )
        worker.add_group(group)
        stored = worker.groups["Human Group"]
        self.assertTrue(stored.human_pilot)
        self.assertEqual(stored.unit_type, "F-16C_50")

    def test_add_group_player_skill_detected(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"name": "Player Group"},
            aircraft_type="plane", country="Russia", coalition="red",
            name="Player Group", human_pilot=True,
        )
        worker.add_group(group)
        self.assertTrue(worker.groups["Player Group"].human_pilot)

    def test_add_group_ai_pilot_not_human(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"name": "AI Group"},
            aircraft_type="plane", country="USA", coalition="blue",
            name="AI Group", human_pilot=False,
        )
        worker.add_group(group)
        self.assertFalse(worker.groups["AI Group"].human_pilot)

    def test_add_group_no_units(self) -> None:
        worker = _make_worker()
        group = Group(group_dcs={"name": "No Units Group"}, aircraft_type="plane", country="USA", coalition="blue", name="No Units Group")
        worker.add_group(group)
        self.assertIn("No Units Group", worker.groups)
        self.assertFalse(worker.groups["No Units Group"].human_pilot)


class TestProcessUnits(unittest.TestCase):
    def _make_group(self, skill: str = "Client") -> Group:
        return Group(
            group_dcs={
                "units": [{"type": "F-16C_50", "skill": skill}],
                "frequency": 305.0,
            },
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=True,
            name="TestGroup",
            unit_type="F-16C_50",
        )

    def test_process_units_with_empty_preset(self) -> None:
        worker = _make_worker()
        group = self._make_group()
        count = worker.process_units(group, PresetDefinition.EMPTY)
        self.assertEqual(count, 1)
        # With EMPTY preset, frequency key is removed
        self.assertNotIn("frequency", group.group_dcs)

    def test_process_units_with_non_empty_preset(self) -> None:
        worker = _make_worker()
        group = self._make_group()
        preset = PresetDefinition("test_preset")
        count = worker.process_units(group, preset)
        self.assertEqual(count, 1)

    def test_process_units_ai_pilot_not_processed(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"units": [{"type": "F-16C_50", "skill": "Excellent"}]},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=False,
            name="AI Group",
            unit_type="F-16C_50",
        )
        count = worker.process_units(group, PresetDefinition.EMPTY)
        self.assertEqual(count, 0)

    def test_process_units_no_units_returns_zero(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"units": []},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=True,
            name="EmptyGroup",
            unit_type="F-16C_50",
        )
        count = worker.process_units(group, PresetDefinition.EMPTY)
        self.assertEqual(count, 0)


class TestProcessGroups(unittest.TestCase):
    def test_process_groups_with_matching_preset(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"units": [{"type": "F-16C_50", "skill": "Client"}]},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=True,
            name="Human Group",
            unit_type="F-16C_50",
        )
        worker.groups = {"Human Group": group}
        preset = PresetDefinition("test_preset")
        worker.presets_manager = MagicMock()
        worker.presets_manager.get_radios_for.return_value = preset
        worker.process_groups(silent=True)
        self.assertTrue(preset.used_in_mission)
        self.assertFalse(group.group_dcs.get("communication", True))

    def test_process_groups_no_matching_preset(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"units": [{"type": "F-16C_50", "skill": "Client"}]},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=True,
            name="Human Group",
            unit_type="F-16C_50",
        )
        worker.groups = {"Human Group": group}
        worker.presets_manager = MagicMock()
        worker.presets_manager.get_radios_for.return_value = None
        worker.process_groups(silent=True)

    def test_process_groups_no_human_pilots_skipped(self) -> None:
        worker = _make_worker()
        group = Group(
            group_dcs={"units": [{"type": "F-16C_50", "skill": "Excellent"}]},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            human_pilot=False,
            name="AI Group",
            unit_type="F-16C_50",
        )
        worker.groups = {"AI Group": group}
        worker.presets_manager = MagicMock()
        worker.presets_manager.get_radios_for.return_value = None
        worker.process_groups(silent=True)
        worker.presets_manager.get_radios_for.assert_not_called()

    def test_process_groups_not_silent_logs(self) -> None:
        worker = _make_worker()
        worker.groups = {}
        worker.presets_manager = MagicMock()
        # Should not raise even when not silent
        worker.process_groups(silent=False)


class TestGenerateValidationReport(unittest.TestCase):
    """Tests for collect_freq_issues() and generate_validation_report()."""

    def _make_worker_with_issues(self) -> PresetsInjectorWorker:
        """Return a worker with _freq_issues pre-loaded (one strict, one non-strict)."""
        from presets_injector.radio_frequency_validator import ChannelFrequency, FrequencyIssue, FrequencyRange

        worker = _make_worker()
        strict_range = FrequencyRange(min_mhz=100.0, max_mhz=150.0, modulation="AM/FM")
        non_strict_range = FrequencyRange(min_mhz=20.0, max_mhz=59.9, modulation="AM/FM")
        ch = ChannelFrequency(freq_mhz=284.0, radio_key="radio_uhf", radio_collection="blue_radios",
                              radio_title="UHF", channel=1, channel_title="TACTICAL")
        worker._freq_issues = [
            FrequencyIssue(
                unit_type="MiG-19P",
                group_names=["Bandit MiG #1"],
                invalid_channels=[ch],
                valid_ranges=[strict_range],
                coalition="blue",
                aircraft_category="plane",
                strict=True,
            ),
            FrequencyIssue(
                unit_type="Ka-50",
                group_names=["Helo #1"],
                invalid_channels=[ch],
                valid_ranges=[non_strict_range],
                coalition="blue",
                aircraft_category="helicopter",
                strict=False,
            ),
        ]
        return worker

    # Keep old name as alias so test methods below still work
    _make_worker_with_pending = _make_worker_with_issues

    def test_collect_freq_issues_returns_issues_for_known_types(self) -> None:
        worker = self._make_worker_with_pending()
        issues = worker.collect_freq_issues()
        unit_types = {i.unit_type for i in issues}
        # MiG-19P has invalid UHF freq; Ka-50 has UHF freq outside its 20-59 MHz range
        self.assertIn("MiG-19P", unit_types)
        self.assertIn("Ka-50", unit_types)

    def test_collect_freq_issues_strict_sorted_first(self) -> None:
        worker = self._make_worker_with_pending()
        issues = worker.collect_freq_issues()
        if len(issues) >= 2:
            strict_issues = [i for i in issues if i.strict]
            non_strict_issues = [i for i in issues if not i.strict]
            if strict_issues and non_strict_issues:
                self.assertLess(issues.index(strict_issues[0]), issues.index(non_strict_issues[0]))

    def test_generate_validation_report_creates_file(self) -> None:
        worker = self._make_worker_with_pending()
        with tempfile.TemporaryDirectory() as tmpdir:
            report_path = Path(tmpdir) / "report.md"
            count = worker.generate_validation_report(report_path)
            self.assertTrue(report_path.exists())
            self.assertGreater(count, 0)

    def test_generate_validation_report_content(self) -> None:
        worker = self._make_worker_with_pending()
        with tempfile.TemporaryDirectory() as tmpdir:
            report_path = Path(tmpdir) / "report.md"
            worker.generate_validation_report(report_path)
            content = report_path.read_text(encoding="utf-8")
            self.assertIn("# Radio Presets Frequency Validation Report", content)
            self.assertIn("MiG-19P", content)

    def test_generate_validation_report_empty_when_no_issues(self) -> None:
        worker = _make_worker()
        # No pending warnings → all valid
        with tempfile.TemporaryDirectory() as tmpdir:
            report_path = Path(tmpdir) / "report.md"
            count = worker.generate_validation_report(report_path)
            self.assertEqual(count, 0)
            content = report_path.read_text(encoding="utf-8")
            self.assertIn("All preset frequencies are valid", content)


if __name__ == "__main__":
    unittest.main()
