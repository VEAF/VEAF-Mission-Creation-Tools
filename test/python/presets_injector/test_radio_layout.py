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

    @patch("presets_injector.presets_manager.logger")
    def test_invalid_regex_key_is_skipped_and_logged(self, mock_logger):
        # A malformed regex key must not raise, must not shadow a later key's
        # match (looked up by a unit_type that isn't an exact key, so the
        # regex path is actually exercised), and must be logged so the typo
        # does not go unnoticed.
        layouts = parse_radio_layouts(
            {
                "AJS37[": {"radios": {1: {"role": "primary_2"}}},  # unbalanced bracket -> re.error
                "Mi-24.*": {"radios": {1: {"role": "primary_1"}}},
            }
        )
        entry = get_radio_layout(layouts, "Mi-24P")
        self.assertIsNotNone(entry)
        self.assertEqual(entry.radios[1].role, "primary_1")
        mock_logger.warning.assert_called_once()
        self.assertIn("AJS37[", mock_logger.warning.call_args[0][0])


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


class TestParseReservedHeadSlots(unittest.TestCase):
    def test_parses_reserved_head_slots_list(self):
        data = {
            "OH58D": {
                "radios": {
                    1: {"role": "primary_1", "reserved_head_slots": [20]},
                    3: {"role": "fm_supplement", "reserved_head_slots": [1, 20]},
                }
            }
        }
        layouts = parse_radio_layouts(data)
        entry = layouts["OH58D"]
        self.assertEqual(entry.radios[1].reserved_head_slots, [20])
        self.assertEqual(entry.radios[3].reserved_head_slots, [1, 20])

    def test_defaults_to_empty_list_when_absent(self):
        data = {"SomeType": {"radios": {1: {"role": "primary_1"}}}}
        layouts = parse_radio_layouts(data)
        self.assertEqual(layouts["SomeType"].radios[1].reserved_head_slots, [])

    def test_rejects_both_primitives_on_the_same_radio(self):
        data = {
            "SomeType": {"radios": {1: {"role": "primary_1", "rotate_last_to_head": True, "reserved_head_slots": [20]}}}
        }
        with self.assertRaises(ValueError):
            parse_radio_layouts(data)


class TestPrependReservedSlots(unittest.TestCase):
    """The _prepend_reserved_slots primitive end-to-end (OH-58D shape)."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_single_reserved_slot_from_last_entry(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", reserved_head_slots=[20])}
        )
        freqs = [100.0 + i for i in range(20)]  # #1..#20
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        # Slot 1 ("M") holds the list's last entry (#20).
        self.assertEqual(radio1[1], freqs[19])
        # Slots 2..20 hold entries #1..#19 in order.
        for slot in range(2, 21):
            self.assertEqual(radio1[slot], freqs[slot - 2])
        # Exactly 20 slots: entry #20 is REMOVED from the tail, not duplicated
        # (regression guard: a prior bug prepended the reserved entry without
        # removing it, producing 21 slots with #20 appearing twice).
        self.assertEqual(sorted(radio1.keys()), list(range(1, 21)))
        self.assertEqual(sorted(radio1.values()), sorted(freqs))

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_two_reserved_slots_from_first_then_last_entry(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="fm_supplement", reserved_head_slots=[1, 20])}
        )
        freqs = [100.0 + i for i in range(20)]  # #1..#20
        channel_lists = _channel_lists(fm_supplement=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        # Slot 1 ("C") holds entry #01, slot 2 ("M") holds entry #20.
        self.assertEqual(radio1[1], freqs[0])
        self.assertEqual(radio1[2], freqs[19])
        # Slots 3..21 hold entries #1..#19 in order (entry #01 legitimately
        # reappears here: only the list's last entry rotates out of the tail;
        # a non-last reserved index, like "C" = #01, is a leading duplicate —
        # per the exploration doc's documented 21-slot OH-58D FM shape).
        for slot in range(3, 22):
            self.assertEqual(radio1[slot], freqs[slot - 3])
        # Exactly 21 slots for a 20-entry list: only #20 is removed from the
        # tail (rotation), #01 is duplicated, not removed (regression guard —
        # distinct from the single-slot case, see
        # test_single_reserved_slot_from_last_entry, where the sole reserved
        # index IS the last entry and so is removed, keeping the count at 20).
        self.assertEqual(sorted(radio1.keys()), list(range(1, 22)))
        self.assertEqual(radio1[1], radio1[3])  # "C" duplicates the tail's own #01

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_out_of_range_reserved_index_is_skipped_not_a_crash(self, mock_get_radios, mock_get_layout):
        # A shorter-than-expected maker list (e.g. 5 entries) with a layout
        # entry expecting index 20 -> degrades safely instead of raising.
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", reserved_head_slots=[5])}
        )
        freqs = [100.0 + i for i in range(5)]
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        # Index 5 IS the list's last entry -> rotation semantics: removed from
        # the tail, so the radio still has exactly 5 slots, not 6.
        self.assertEqual(radio1[1], freqs[4])
        for slot in range(2, 6):
            self.assertEqual(radio1[slot], freqs[slot - 2])
        self.assertEqual(sorted(radio1.keys()), list(range(1, 6)))
        self.assertEqual(sorted(radio1.values()), sorted(freqs))

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_reserved_index_beyond_list_length_is_skipped_not_a_crash(self, mock_get_radios, mock_get_layout):
        # A shorter-than-expected maker list (e.g. 5 entries) with a layout
        # entry expecting index 20 -> degrades safely instead of raising.
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", reserved_head_slots=[20])}
        )
        freqs = [100.0 + i for i in range(5)]
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        # Index 20 is out of range for a 5-entry list -> skipped entirely, so
        # the plain list comes through untouched.
        self.assertEqual(radio1, {slot: freq for slot, freq in enumerate(freqs, start=1)})

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_non_positive_reserved_index_is_skipped_not_a_crash(self, mock_get_radios, mock_get_layout):
        # Index 0 (and negative indices) are not valid 1-based positions —
        # skipped rather than wrapping to the end of the list via Python's
        # negative-index semantics.
        mock_get_radios.return_value = _specs(AMBIGUOUS)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", reserved_head_slots=[0, -1, 5])}
        )
        freqs = [100.0 + i for i in range(5)]
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        radio1 = result[1]["channels"]
        # Only index 5 was valid (0 and -1 are skipped); it is also the list's
        # last entry, so rotation semantics apply and it is removed from the tail.
        self.assertEqual(radio1[1], freqs[4])
        for slot in range(2, 6):
            self.assertEqual(radio1[slot], freqs[slot - 2])
        self.assertEqual(sorted(radio1.keys()), list(range(1, 6)))
        self.assertEqual(sorted(radio1.values()), sorted(freqs))


class TestParseReservedHeadSlotsMalformedEntries(unittest.TestCase):
    """A non-integer reserved_head_slots entry must not abort the whole layout file."""

    @patch("presets_injector.presets_manager.logger")
    def test_non_integer_entry_is_skipped_and_logged(self, mock_logger):
        data = {"SomeType": {"radios": {1: {"role": "primary_1", "reserved_head_slots": [20, "not-a-number"]}}}}
        layouts = parse_radio_layouts(data)
        self.assertEqual(layouts["SomeType"].radios[1].reserved_head_slots, [20])
        mock_logger.warning.assert_called_once()
        self.assertIn("not-a-number", mock_logger.warning.call_args[0][0])


class TestOH58DEndToEnd(unittest.TestCase):
    """Real dcs-radio-layouts.yaml + dcs-radio-specs.yaml, no mocks."""

    def _list(self, count: int = 20) -> list[float]:
        return [100.0 + i for i in range(count)]

    def test_uhf_and_vhf_get_a_single_reserved_m_slot(self):
        primary_1 = self._list()
        primary_2 = [200.0 + i for i in range(20)]
        fm_supplement = [300.0 + i for i in range(20)]
        channel_lists = _channel_lists(primary_1=primary_1, primary_2=primary_2, fm_supplement=fm_supplement)
        preset = pack_preset_for_type(channel_lists, "blue", "OH58D")
        self.assertIsNotNone(preset)
        result = preset.to_dict()

        radio1 = result[1]["channels"]  # UHF
        self.assertEqual(radio1[1], primary_1[19])
        for slot in range(2, 21):
            self.assertEqual(radio1[slot], primary_1[slot - 2])
        # Exactly 20 slots: no duplicate of entry #20 (regression guard).
        self.assertEqual(sorted(radio1.keys()), list(range(1, 21)))
        self.assertEqual(sorted(radio1.values()), sorted(primary_1))

        radio2 = result[2]["channels"]  # VHF
        self.assertEqual(radio2[1], primary_2[19])
        for slot in range(2, 21):
            self.assertEqual(radio2[slot], primary_2[slot - 2])
        self.assertEqual(sorted(radio2.keys()), list(range(1, 21)))
        self.assertEqual(sorted(radio2.values()), sorted(primary_2))

    def test_fm1_and_fm2_get_c_and_m_reserved_slots_fm_secondary_defaults_to_supplement(self):
        primary_1 = self._list()
        primary_2 = [200.0 + i for i in range(20)]
        fm_supplement = [300.0 + i for i in range(20)]
        channel_lists = _channel_lists(primary_1=primary_1, primary_2=primary_2, fm_supplement=fm_supplement)
        preset = pack_preset_for_type(channel_lists, "blue", "OH58D")
        self.assertIsNotNone(preset)
        result = preset.to_dict()

        for radio_index in (3, 4):  # FM1, FM2 — fm_secondary defaults to fm_supplement's content
            radio = result[radio_index]["channels"]
            self.assertEqual(radio[1], fm_supplement[0])  # "C" = entry #01
            self.assertEqual(radio[2], fm_supplement[19])  # "M" = entry #20
            for slot in range(3, 22):
                self.assertEqual(radio[slot], fm_supplement[slot - 3])
            # Exactly 21 slots for a 20-entry list: #20 ("M") rotates out of
            # the tail, #01 ("C") is a duplicate and also reappears at slot 3
            # (regression guard against a prior bug that duplicated #20 too,
            # which would have produced 22 slots here).
            self.assertEqual(sorted(radio.keys()), list(range(1, 22)))
            self.assertEqual(radio[1], radio[3])

    def test_fm2_uses_explicit_fm_secondary_when_declared(self):
        primary_1 = self._list()
        primary_2 = [200.0 + i for i in range(20)]
        fm_supplement = [300.0 + i for i in range(20)]
        fm_secondary = [400.0 + i for i in range(20)]
        channel_lists = _channel_lists(
            primary_1=primary_1, primary_2=primary_2, fm_supplement=fm_supplement, fm_secondary=fm_secondary
        )
        preset = pack_preset_for_type(channel_lists, "blue", "OH58D")
        self.assertIsNotNone(preset)
        result = preset.to_dict()

        fm1 = result[3]["channels"]
        self.assertEqual(fm1[1], fm_supplement[0])
        self.assertEqual(fm1[2], fm_supplement[19])
        self.assertEqual(sorted(fm1.keys()), list(range(1, 22)))
        self.assertEqual(fm1[1], fm1[3])

        fm2 = result[4]["channels"]
        self.assertEqual(fm2[1], fm_secondary[0])
        self.assertEqual(fm2[2], fm_secondary[19])
        for slot in range(3, 22):
            self.assertEqual(fm2[slot], fm_secondary[slot - 3])
        self.assertEqual(sorted(fm2.keys()), list(range(1, 22)))
        self.assertEqual(fm2[1], fm2[3])


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
