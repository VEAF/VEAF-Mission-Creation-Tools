"""Tests for the slot capacity/truncation primitive (ADR 0010, ticket 06).

Some physical radios have a hard limit on how many channels they can hold
(e.g. the AJS-37's fused V/UHF radio is exactly 47 slots, already an exact
fit — no truncation needed there). This primitive truncates a radio's final
composed channel map (after all other primitives run) to a declared
``capacity``, dropping the excess from the END of the list — matching how
Tripack itself truncated the AJS-37 VHF list to fit 47 slots (see the
exploration doc §7/§8.4).
"""

import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    Channel,
    RadioDefinition,
    RadioLayoutEntry,
    RadioLayoutRadio,
    pack_preset_for_type,
    parse_radio_layouts,
)


def _radio_list(freqs: list[float]) -> RadioDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf")
    for i, freq in enumerate(freqs, start=1):
        radio.add_channel(Channel(name_or_number=i, freq=freq))
    return radio


def _channel_lists(**roles: list[float]) -> dict[str, dict[str, RadioDefinition]]:
    return {"blue": {role: _radio_list(freqs) for role, freqs in roles.items()}}


class TestParseCapacity(unittest.TestCase):
    def test_parses_capacity_when_declared(self):
        data = {"SomeType": {"radios": {1: {"role": "primary_1", "capacity": 20}}}}
        layouts = parse_radio_layouts(data)
        self.assertEqual(layouts["SomeType"].radios[1].capacity, 20)

    def test_capacity_defaults_to_none_when_absent(self):
        data = {"SomeType": {"radios": {1: {"role": "primary_1"}}}}
        layouts = parse_radio_layouts(data)
        self.assertIsNone(layouts["SomeType"].radios[1].capacity)

    def test_non_integer_capacity_is_ignored_with_a_warning_not_a_crash(self):
        # A malformed 'capacity' (e.g. a typo'd string) must not abort parsing
        # the whole layout file — same authoring-error-tolerance level as
        # reserved_head_slots' invalid-entry handling.
        data = {"SomeType": {"radios": {1: {"role": "primary_1", "capacity": "not-a-number"}}}}
        layouts = parse_radio_layouts(data)
        self.assertIsNone(layouts["SomeType"].radios[1].capacity)

    def test_zero_or_negative_capacity_is_ignored_with_a_warning(self):
        data = {"SomeType": {"radios": {1: {"role": "primary_1", "capacity": 0}}}}
        layouts = parse_radio_layouts(data)
        self.assertIsNone(layouts["SomeType"].radios[1].capacity)

        data_negative = {"SomeType": {"radios": {1: {"role": "primary_1", "capacity": -5}}}}
        layouts_negative = parse_radio_layouts(data_negative)
        self.assertIsNone(layouts_negative["SomeType"].radios[1].capacity)

    @patch("presets_injector.presets_manager.logger")
    def test_invalid_capacity_logs_a_warning(self, mock_logger):
        data = {"SomeType": {"radios": {1: {"role": "primary_1", "capacity": "bogus"}}}}
        parse_radio_layouts(data)
        mock_logger.warning.assert_called_once()


class TestCapacityTruncation(unittest.TestCase):
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_list_exceeding_capacity_is_truncated_from_the_end(self, mock_get_radios, mock_get_layout):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=5)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 11)])  # 10 entries
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        # Only the first 5 entries survive; the tail (6..10) is dropped.
        self.assertEqual(result[1]["channels"], {1: 1.0, 2: 2.0, 3: 3.0, 4: 4.0, 5: 5.0})

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_list_within_capacity_is_untouched(self, mock_get_radios, mock_get_layout):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=20)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])  # 5 entries
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertEqual(len(result[1]["channels"]), 5)

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_no_capacity_declared_means_unbounded(self, mock_get_radios, mock_get_layout):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1")})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 31)])  # 30 entries
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertEqual(len(result[1]["channels"]), 30)

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_truncation_logs_at_debug_level_matching_ticket_05_convention(
        self, mock_get_radios, mock_get_layout, mock_logger
    ):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=3)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])  # 5 entries, capacity 3
        pack_preset_for_type(channel_lists, "blue", "SomeType")
        mock_logger.debug.assert_called_once()
        # No warning-level noise during a normal build (exploration doc §8.4).
        mock_logger.warning.assert_not_called()

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_no_truncation_does_not_log(self, mock_get_radios, mock_get_layout, mock_logger):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=20)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])
        pack_preset_for_type(channel_lists, "blue", "SomeType")
        mock_logger.debug.assert_not_called()

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_capacity_applies_after_trailing_specials(self, mock_get_radios, mock_get_layout):
        """Capacity is the LAST composition step: it truncates the fully composed
        radio (rotation/fusion/dummy/trailing specials already applied), not just
        the raw channel-list content.
        """
        from presets_injector.presets_manager import HardcodedChannel
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(
                    role="primary_1",
                    trailing_specials=[HardcodedChannel(freq=999.0), HardcodedChannel(freq=998.0)],
                    capacity=6,
                )
            }
        )
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])  # 5 entries + 2 specials = 7
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        # 7 total slots truncated to 6: the trailing specials (last-added) lose
        # their last entry (998.0 dropped), the first special (999.0) survives.
        self.assertEqual(result[1]["channels"], {1: 1.0, 2: 2.0, 3: 3.0, 4: 4.0, 5: 5.0, 6: 999.0})


if __name__ == "__main__":
    unittest.main()
