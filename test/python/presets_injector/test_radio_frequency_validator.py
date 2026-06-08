"""Unit tests for radio_frequency_validator."""

import unittest
from unittest.mock import patch

from presets_injector.radio_frequency_validator import (
    ChannelFrequency,
    FrequencyRange,
    get_valid_ranges,
    validate_frequencies,
    validate_frequency,
    warn_invalid_channel_frequencies,
    warn_invalid_frequencies,
)

_MOCK_SPECS = {
    "FA-18C_hornet": {
        "name": "F/A-18C Lot 20",
        "category": "plane",
        "radios": [
            {
                "name": "COMM 1: ARC-210",
                "ranges": [
                    {"min_mhz": 30.0, "max_mhz": 87.995, "modulation": "FM"},
                    {"min_mhz": 118.0, "max_mhz": 135.995, "modulation": "AM"},
                    {"min_mhz": 225.0, "max_mhz": 399.975, "modulation": "AM/FM"},
                ],
            }
        ],
    },
    "MiG-19P": {
        "name": "MiG-19P",
        "category": "plane",
        "radios": [
            {
                "name": "RSIU-4V Radio",
                "ranges": [
                    {"min_mhz": 100.0, "max_mhz": 150.0, "modulation": "AM/FM"},
                ],
            }
        ],
    },
    "SA342M": {
        "name": "SA342M",
        "category": "helicopter",
        "radios": [
            {
                "name": "FM Radio",
                "ranges": [
                    {"min_mhz": 30.0, "max_mhz": 87.975, "modulation": "FM"},
                ],
            }
        ],
    },
}


class TestFrequencyRange(unittest.TestCase):
    def test_contains_within(self):
        r = FrequencyRange(min_mhz=225.0, max_mhz=399.975, modulation="AM")
        self.assertTrue(r.contains(305.0))

    def test_contains_at_boundary(self):
        r = FrequencyRange(min_mhz=225.0, max_mhz=399.975, modulation="AM")
        self.assertTrue(r.contains(225.0))
        self.assertTrue(r.contains(399.975))

    def test_contains_outside(self):
        r = FrequencyRange(min_mhz=225.0, max_mhz=399.975, modulation="AM")
        self.assertFalse(r.contains(100.0))
        self.assertFalse(r.contains(400.0))


class TestGetValidRanges(unittest.TestCase):
    def setUp(self):
        self._patcher = patch("presets_injector.radio_frequency_validator._SPECS", _MOCK_SPECS)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_known_aircraft_returns_ranges(self):
        ranges = get_valid_ranges("FA-18C_hornet")
        self.assertIsNotNone(ranges)
        assert ranges is not None
        self.assertEqual(len(ranges), 3)

    def test_unknown_aircraft_returns_none(self):
        self.assertIsNone(get_valid_ranges("Unknown-Aircraft"))

    def test_mig19_single_range(self):
        ranges = get_valid_ranges("MiG-19P")
        self.assertIsNotNone(ranges)
        assert ranges is not None
        self.assertEqual(len(ranges), 1)
        self.assertEqual(ranges[0].min_mhz, 100.0)
        self.assertEqual(ranges[0].max_mhz, 150.0)


class TestValidateFrequency(unittest.TestCase):
    def setUp(self):
        self._patcher = patch("presets_injector.radio_frequency_validator._SPECS", _MOCK_SPECS)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_valid_uhf_for_hornet(self):
        self.assertTrue(validate_frequency("FA-18C_hornet", 305.0))

    def test_invalid_freq_for_mig19(self):
        # 284 MHz is the real-world case that triggered this feature
        self.assertFalse(validate_frequency("MiG-19P", 284.0))

    def test_valid_freq_for_mig19(self):
        self.assertTrue(validate_frequency("MiG-19P", 125.0))

    def test_invalid_freq_for_gazelle(self):
        self.assertFalse(validate_frequency("SA342M", 284.0))

    def test_valid_fm_for_gazelle(self):
        self.assertTrue(validate_frequency("SA342M", 50.0))

    def test_unknown_aircraft_returns_none(self):
        self.assertIsNone(validate_frequency("Unknown-Aircraft", 305.0))


class TestValidateFrequencies(unittest.TestCase):
    def setUp(self):
        self._patcher = patch("presets_injector.radio_frequency_validator._SPECS", _MOCK_SPECS)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_returns_only_invalid(self):
        invalid = validate_frequencies("MiG-19P", [125.0, 284.0, 130.0, 400.0])
        self.assertEqual(sorted(invalid), [284.0, 400.0])

    def test_all_valid_returns_empty(self):
        self.assertEqual(validate_frequencies("MiG-19P", [100.0, 125.0, 150.0]), [])

    def test_unknown_aircraft_returns_empty(self):
        self.assertEqual(validate_frequencies("Unknown-Aircraft", [284.0]), [])


class TestWarnInvalidFrequencies(unittest.TestCase):
    def setUp(self):
        self._patcher = patch("presets_injector.radio_frequency_validator._SPECS", _MOCK_SPECS)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_warns_for_invalid_frequencies(self):
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_frequencies("Bassel MiG-19 #1", "MiG-19P", [125.0, 284.0])
            mock_logger.warning.assert_called_once()
            call_args = mock_logger.warning.call_args[0][0]
            self.assertIn("284.0 MHz", call_args)
            self.assertIn("Bassel MiG-19 #1", call_args)
            self.assertIn("100.0–150.0 MHz", call_args)
            self.assertIn("presets.yaml", call_args)

    def test_no_warning_for_valid_frequencies(self):
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_frequencies("Some Group", "MiG-19P", [120.0, 140.0])
            mock_logger.warning.assert_not_called()

    def test_no_warning_for_unknown_aircraft(self):
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_frequencies("Some Group", "Unknown-Aircraft", [284.0])
            mock_logger.warning.assert_not_called()


def _make_ch(freq: float, channel: int = 1, channel_title: str = "TACTICAL UNIFORM") -> ChannelFrequency:
    return ChannelFrequency(
        freq_mhz=freq,
        radio_key="radio_uhf_blue",
        radio_collection="blue_radios",
        radio_title="UHF",
        channel=channel,
        channel_title=channel_title,
    )


class TestWarnInvalidChannelFrequencies(unittest.TestCase):
    def setUp(self):
        self._patcher = patch("presets_injector.radio_frequency_validator._SPECS", _MOCK_SPECS)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()

    def test_warns_with_presets_yaml_path(self):
        channels = [_make_ch(125.0, 1), _make_ch(284.0, 2, "TACTICAL UNIFORM")]
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_channel_frequencies(["Bassel MiG-19 #1"], "MiG-19P", channels, "blue", "plane")
            mock_logger.warning.assert_called_once()
            msg = mock_logger.warning.call_args[0][0]
            self.assertIn("284.0 MHz", msg)
            self.assertIn("MiG-19P", msg)
            self.assertIn("radio_uhf_blue", msg)
            self.assertIn("blue_radios", msg)
            self.assertIn("channel 2", msg)
            self.assertIn("TACTICAL UNIFORM", msg)
            self.assertIn("100.0–150.0 MHz", msg)
            # suggests adding a specific preset, not changing the global frequency
            self.assertIn("presets_assignments", msg)
            self.assertIn("blue", msg)
            self.assertIn("plane", msg)

    def test_no_warning_when_all_valid(self):
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_channel_frequencies(["Some Group"], "MiG-19P", [_make_ch(120.0)])
            mock_logger.warning.assert_not_called()

    def test_no_warning_for_unknown_aircraft(self):
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_channel_frequencies(["Some Group"], "Unknown-Aircraft", [_make_ch(284.0)])
            mock_logger.warning.assert_not_called()

    def test_multiple_invalid_channels_single_warning(self):
        # All invalid channels for the same group must be reported in one warning, not one per channel.
        channels = [_make_ch(284.0, 1), _make_ch(300.0, 2)]
        with patch("presets_injector.radio_frequency_validator.logger") as mock_logger:
            warn_invalid_channel_frequencies(["Some Group"], "MiG-19P", channels)
            self.assertEqual(mock_logger.warning.call_count, 1)
            msg = mock_logger.warning.call_args[0][0]
            self.assertIn("284.0 MHz", msg)
            self.assertIn("300.0 MHz", msg)


if __name__ == "__main__":
    unittest.main()
