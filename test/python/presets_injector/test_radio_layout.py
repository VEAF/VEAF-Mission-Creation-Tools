import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    RadioLayoutEntry,
    RadioLayoutRadio,
    get_radio_layout,
    pack_preset_for_type,
    parse_radio_layouts,
)
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec


def _radio_list(freqs: list[float]):
    from presets_injector.presets_manager import Channel, RadioDefinition

    radio = RadioDefinition(name="r", radio_type="uhf")
    for i, freq in enumerate(freqs, start=1):
        radio.add_channel(Channel(name_or_number=i, freq=freq))
    return radio


def _channel_lists(**roles: list[float]):
    return {"blue": {role: _radio_list(freqs) for role, freqs in roles.items()}}


def _specs(*range_lists: list[FrequencyRange]) -> list[RadioSpec]:
    return [RadioSpec(name=f"radio{i}", ranges=ranges) for i, ranges in enumerate(range_lists, start=1)]


AMBIGUOUS = [FrequencyRange(min_mhz=100.0, max_mhz=399.9, modulation="AM/FM")]
FM_ONLY = [FrequencyRange(min_mhz=20.0, max_mhz=59.9, modulation="AM/FM")]


class TestParseRadioLayouts(unittest.TestCase):
    def test_parses_exact_type_with_role_and_primitive(self):
        data = {
            "Mi-24P": {
                "radios": {
                    1: {"role": "primary_1", "rotate_last_to_head": True},
                    2: {"role": "fm_substitute"},
                }
            }
        }
        layouts = parse_radio_layouts(data)
        entry = layouts["Mi-24P"]
        self.assertIsInstance(entry, RadioLayoutEntry)
        self.assertEqual(entry.radios[1], RadioLayoutRadio(role="primary_1", rotate_last_to_head=True))
        self.assertEqual(entry.radios[2], RadioLayoutRadio(role="fm_substitute", rotate_last_to_head=False))

    def test_role_is_mandatory(self):
        data = {"SomeType": {"radios": {1: {"rotate_last_to_head": True}}}}
        with self.assertRaises(ValueError):
            parse_radio_layouts(data)

    def test_unknown_role_is_rejected(self):
        data = {"SomeType": {"radios": {1: {"role": "not_a_role"}}}}
        with self.assertRaises(ValueError):
            parse_radio_layouts(data)


class TestGetRadioLayout(unittest.TestCase):
    def setUp(self):
        self.layouts = parse_radio_layouts(
            {
                "Mi-24P": {"radios": {1: {"role": "primary_1"}, 2: {"role": "fm_substitute"}}},
                "AJS37.*": {"radios": {1: {"role": "primary_2"}}},
            }
        )

    def test_exact_match(self):
        entry = get_radio_layout(self.layouts, "Mi-24P")
        self.assertIsNotNone(entry)
        self.assertEqual(entry.radios[1].role, "primary_1")

    def test_regex_fallback(self):
        entry = get_radio_layout(self.layouts, "AJS37Bnavy")
        self.assertIsNotNone(entry)
        self.assertEqual(entry.radios[1].role, "primary_2")

    def test_no_match_returns_none(self):
        self.assertIsNone(get_radio_layout(self.layouts, "F-16C_50"))


class TestLayoutOverridesDefaultProjection(unittest.TestCase):
    """A layout entry, once present, must override the band-based default entirely."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_layout_role_assignment_wins_over_band_classification(self, mock_get_radios, mock_get_layout):
        # Band classification alone would call radio 1 ambiguous->primary_1 and
        # radio 2 fm->fm_substitute anyway here, but this test proves the layout
        # path is actually consulted by asserting on an inverted layout mapping.
        mock_get_radios.return_value = _specs(AMBIGUOUS, FM_ONLY)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(role="fm_substitute"),
                2: RadioLayoutRadio(role="primary_1"),
            }
        )
        channel_lists = _channel_lists(primary_1=[280.0], fm_substitute=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"], {1: 31.0})  # fm_substitute, per layout
        self.assertEqual(result[2]["channels"], {1: 280.0})  # primary_1, per layout


class TestChannelZeroRotation(unittest.TestCase):
    """The rotate_last_to_head primitive end-to-end (Mi-24P shape)."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_last_entry_moves_to_head_rest_follow_in_order(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AMBIGUOUS, FM_ONLY)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(role="primary_1", rotate_last_to_head=True),
                2: RadioLayoutRadio(role="fm_substitute"),
            }
        )
        freqs = [100.0 + i for i in range(20)]  # 20-entry list, #1..#20
        channel_lists = _channel_lists(primary_1=freqs, fm_substitute=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "Mi-24P")
        result = preset.to_dict()
        radio1_channels = result[1]["channels"]
        # DCS channel-slot 1 ("channel 0") holds the list's last entry (#20).
        self.assertEqual(radio1_channels[1], freqs[19])
        # Slots 2..20 hold entries #1..#19 in order.
        for slot in range(2, 21):
            self.assertEqual(radio1_channels[slot], freqs[slot - 2])
        # fm_substitute reaches radio 2 untouched.
        self.assertEqual(result[2]["channels"], {1: 31.0})


class TestMi24PEndToEnd(unittest.TestCase):
    """Real dcs-radio-layouts.yaml + dcs-radio-specs.yaml, no mocks."""

    def test_mi24p_reproduces_the_tripack_rotation_and_fm_substitute(self):
        freqs = [100.0 + i for i in range(20)]
        channel_lists = _channel_lists(primary_1=freqs, fm_substitute=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "Mi-24P")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        self.assertEqual(radio1[1], freqs[19])
        for slot in range(2, 21):
            self.assertEqual(radio1[slot], freqs[slot - 2])
        self.assertEqual(result[2]["channels"], {1: 31.0})


class TestRadioCountGuard(unittest.TestCase):
    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_mismatched_radio_count_logs_a_warning(self, mock_get_radios, mock_get_layout, mock_logger):
        # Layout declares 2 radios, specs now report only 1 (simulated DCS drift).
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(role="primary_1"),
                2: RadioLayoutRadio(role="fm_substitute"),
            }
        )
        channel_lists = _channel_lists(primary_1=[280.0])
        pack_preset_for_type(channel_lists, "blue", "SomeDriftedType")
        mock_logger.warning.assert_called_once()
        self.assertIn("SomeDriftedType", mock_logger.warning.call_args[0][0])

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_matching_radio_count_does_not_warn(self, mock_get_radios, mock_get_layout, mock_logger):
        mock_get_radios.return_value = _specs(AMBIGUOUS, FM_ONLY)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(role="primary_1"),
                2: RadioLayoutRadio(role="fm_substitute"),
            }
        )
        channel_lists = _channel_lists(primary_1=[280.0], fm_substitute=[31.0])
        pack_preset_for_type(channel_lists, "blue", "SomeType")
        mock_logger.warning.assert_not_called()


if __name__ == "__main__":
    unittest.main()
