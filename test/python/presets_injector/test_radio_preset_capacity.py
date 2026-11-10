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
from veaf_libs.i18n import t


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
    def test_truncation_warns_naming_the_type_the_radio_the_capacity_and_the_dropped_count(
        self, mock_get_radios, mock_get_layout, mock_logger
    ):
        # FIX-RADIO-PRESET-CAPACITY (amends ADR 0010): a dropped preset is one a pilot will look for, so the
        # build says it — no longer a debug line.
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=3)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])  # 5 entries, capacity 3
        pack_preset_for_type(channel_lists, "blue", "SomeType")
        mock_logger.warning.assert_called_once_with(
            t(
                "presets_injector.radio_layout.capacity_truncated",
                unit_type="SomeType",
                radio_index=1,
                capacity=3,
                dropped_count=2,
            )
        )

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_a_shared_warned_set_warns_once_per_radio_not_once_per_unit(
        self, mock_get_radios, mock_get_layout, mock_logger
    ):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")])
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=3)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 6)])
        warned: set[tuple[str, int, int]] = set()
        for _ in range(3):  # three units of the same type in one build
            pack_preset_for_type(channel_lists, "blue", "SomeType", capacity_warned=warned)
        mock_logger.warning.assert_called_once()

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
        mock_logger.warning.assert_not_called()

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


class TestCapacityFromTheModule(unittest.TestCase):
    """FEAT-RADIO-CAPACITY-ALL-TYPES: a radio holds what its module's ``panelRadio`` lists.

    ``dcs-radio-specs.yaml`` carries that count per radio (``channels``); the packer truncates to it
    when the Radio layout declares no ``capacity`` of its own, including under the band-based
    default, where no layout entry exists at all.
    """

    def test_get_radios_reads_the_channel_count(self):
        from presets_injector.radio_frequency_validator import get_radios

        radios = get_radios("OH58D")
        self.assertIsNotNone(radios)
        self.assertEqual([r.channels for r in radios], [20, 20, 21, 21])

    def test_a_radio_the_overlay_declares_has_no_count(self):
        from presets_injector.radio_frequency_validator import get_radios

        radios = get_radios("La-7")
        self.assertIsNotNone(radios)
        self.assertTrue(all(r.channels is None for r in radios))

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_a_list_with_gaps_is_cut_by_slot_number_not_by_count(self, mock_get_radios, mock_get_layout, mock_logger):
        # A channel dropped from a list (out of band) leaves its slot empty, so a pilot's channel N stays
        # N. Four entries reaching slot 6 overflow a 5-slot radio although they are fewer than 5: the one
        # past slot 5 goes, and the kept ones keep their slot.
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM")], channels=5)
        ]
        mock_get_layout.return_value = None
        radio = RadioDefinition(name="r", radio_type="uhf")
        for slot in (1, 2, 4, 6):
            radio.add_channel(Channel(name_or_number=slot, freq=225.0 + slot))
        preset = pack_preset_for_type({"blue": {"primary_1": radio}}, "blue", "SomeType")
        self.assertIsNotNone(preset)
        self.assertEqual(preset.to_dict()[1]["channels"], {1: 226.0, 2: 227.0, 4: 229.0})
        mock_logger.warning.assert_called_once_with(
            t(
                "presets_injector.radio_layout.capacity_truncated",
                unit_type="SomeType",
                radio_index=1,
                capacity=5,
                dropped_count=1,
            )
        )

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_the_band_based_default_truncates_to_the_module_count(self, mock_get_radios, mock_get_layout, mock_logger):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM")], channels=5)
        ]
        mock_get_layout.return_value = None
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(225, 235)])  # 10 entries
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        self.assertEqual(list(preset.to_dict()[1]["channels"].values()), [225.0, 226.0, 227.0, 228.0, 229.0])
        mock_logger.warning.assert_called_once_with(
            t(
                "presets_injector.radio_layout.capacity_truncated",
                unit_type="SomeType",
                radio_index=1,
                capacity=5,
                dropped_count=5,
            )
        )

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_a_layout_radio_without_capacity_takes_the_module_count(self, mock_get_radios, mock_get_layout):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM")], channels=4)
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1")})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 11)])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        self.assertEqual(len(preset.to_dict()[1]["channels"]), 4)

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_the_layout_capacity_wins_over_the_module_count(self, mock_get_radios, mock_get_layout):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM")], channels=4)
        ]
        mock_get_layout.return_value = RadioLayoutEntry(radios={1: RadioLayoutRadio(role="primary_1", capacity=7)})
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(1, 11)])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        self.assertEqual(len(preset.to_dict()[1]["channels"]), 7)

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_a_radio_without_a_count_stays_unbounded(self, mock_get_radios, mock_get_layout, mock_logger):
        from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

        mock_get_radios.return_value = [
            RadioSpec(name="r1", ranges=[FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM")])
        ]
        mock_get_layout.return_value = None
        channel_lists = _channel_lists(primary_1=[float(i) for i in range(225, 255)])  # 30 entries
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNotNone(preset)
        self.assertEqual(len(preset.to_dict()[1]["channels"]), 30)
        mock_logger.warning.assert_not_called()

    def test_the_shipped_layout_capacities_agree_with_the_modules(self):
        # The four types #1262 declared by hand read the same counts from the datamine: the layout
        # values stay, and a DCS update that changes a count shows up here.
        from presets_injector.presets_manager import _load_radio_layouts
        from presets_injector.radio_frequency_validator import get_radios

        checked = 0
        for unit_type, entry in _load_radio_layouts().items():
            radios = get_radios(unit_type)
            self.assertIsNotNone(radios, unit_type)
            for index, layout_radio in entry.radios.items():
                if layout_radio.capacity is not None:
                    self.assertEqual(layout_radio.capacity, radios[index - 1].channels, f"{unit_type} radio {index}")
                    checked += 1
        self.assertEqual(checked, 9)

    def test_a_shipped_type_without_layout_is_truncated_end_to_end(self):
        # F-16C_50 has no layout entry: its UHF and VHF hold 20 presets each (panelRadio).
        lists = _channel_lists(
            primary_1=[225.0 + i for i in range(30)],
            primary_2=[118.0 + i * 0.5 for i in range(30)],
        )
        preset = pack_preset_for_type(lists, "blue", "F-16C_50")
        self.assertIsNotNone(preset)
        self.assertEqual([len(radio["channels"]) for radio in preset.to_dict().values()], [20, 20])

    def test_the_viggen_keyed_block_fits_its_47_slots_untouched(self):
        lists = _channel_lists(
            primary_1=[225.0 + i for i in range(20)],
            primary_2=[300.0 + i for i in range(20)],
        )
        with patch("presets_injector.presets_manager.logger") as mock_logger:
            preset = pack_preset_for_type(lists, "blue", "AJS37")
        self.assertIsNotNone(preset)
        self.assertEqual(len(preset.to_dict()[1]["channels"]), 43)  # 40 + E, F, G (no plan priorities here)
        mock_logger.warning.assert_not_called()


if __name__ == "__main__":
    unittest.main()
