"""Per-type kneeboard generation + Viggen pilot labels + column split (ADR 0012, ticket 04)."""

import unittest

from presets_injector.presets_manager import (
    Channel,
    ChannelCollection,
    PresetDefinition,
    RadioDefinition,
    RadioPresetsImageGenerator,
    _ch_label,
    _radio_max_slot,
    pack_preset_for_type,
    parse_channel_lists,
)


def _preset(*channels: Channel) -> PresetDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf", title="UHF")
    for channel in channels:
        radio.add_channel(channel)
    preset = PresetDefinition(name="p", title="t")
    preset.add_radio(radio)
    return preset


def _generator() -> RadioPresetsImageGenerator:
    return RadioPresetsImageGenerator(preset_collections={})


class TestGenerateTypeImagePaths(unittest.TestCase):
    def test_single_coalition_type_has_no_coalition_suffix(self):
        injected = {("blue", "AJS37"): _preset(Channel(1, 251.0))}
        paths = set(_generator().generate_type_images(injected))
        self.assertEqual(paths, {"KNEEBOARD/AJS37/IMAGES/presets.png"})

    def test_same_type_in_both_coalitions_is_suffixed(self):
        injected = {
            ("blue", "AJS37"): _preset(Channel(1, 251.0)),
            ("red", "AJS37"): _preset(Channel(1, 252.0)),
        }
        paths = set(_generator().generate_type_images(injected))
        self.assertEqual(
            paths,
            {"KNEEBOARD/AJS37/IMAGES/presets-blue.png", "KNEEBOARD/AJS37/IMAGES/presets-red.png"},
        )

    def test_distinct_types_each_get_their_own_folder(self):
        injected = {
            ("blue", "AJS37"): _preset(Channel(1, 251.0)),
            ("blue", "A-10C"): _preset(Channel(1, 252.0)),
        }
        paths = set(_generator().generate_type_images(injected))
        self.assertIn("KNEEBOARD/AJS37/IMAGES/presets.png", paths)
        self.assertIn("KNEEBOARD/A-10C/IMAGES/presets.png", paths)

    def test_type_with_slash_is_sanitised_in_the_path(self):
        injected = {("blue", "F/A-18C"): _preset(Channel(1, 251.0))}
        paths = set(_generator().generate_type_images(injected))
        self.assertEqual(paths, {"KNEEBOARD/F_A-18C/IMAGES/presets.png"})


class TestMaxSlot(unittest.TestCase):
    def test_max_slot_counts_labelled_empty_slots(self):
        radio = RadioDefinition(name="r")
        radio.add_channel(Channel(1, 251.0))
        radio.display_labels = {slot: str(99 + slot) for slot in range(1, 41)}
        self.assertEqual(_radio_max_slot(radio), 40)


class TestAjs37DisplayLabels(unittest.TestCase):
    """The packed AJS-37 radio carries pilot-facing CH labels end to end."""

    def test_data_slots_labelled_as_groups_and_specials_named(self):
        channel_collections: dict[str, ChannelCollection] = {"c": ChannelCollection.from_dict("c", {})}
        data = {
            "blue": {
                "primary_1": {
                    str(k).zfill(2): {"freq": 300.0 + k, "priority": (1 if k == 5 else None)} for k in range(1, 21)
                },
                "primary_2": {str(k).zfill(2): 130.0 + k for k in range(1, 21)},
            }
        }
        channel_lists, _ = parse_channel_lists(data, channel_collections)
        preset = pack_preset_for_type(channel_lists, "blue", "AJS37")
        labels = next(iter(preset.radios.values())).display_labels
        self.assertEqual(labels[1], "100")  # first data slot = Group 100
        self.assertEqual(labels[40], "139")  # last data slot = Group 139
        self.assertEqual(labels[41], "Sp1")  # FR22 Special 1
        self.assertEqual(labels[47], "H")  # FR24 H


class TestRotatedChannelDisplayLabels(unittest.TestCase):
    """A channel-0 rotation radio shows the number on the selector, not the DCS slot.

    DCS slot 1 of the Mi-24P's R-863 is the selector's channel 0, so the kneeboard must print slot N as channel
    N-1. It printed the slot: "13 Nörvenich" where the cockpit reads channel 12 (GermanyCW, read in the
    cockpit on 2026-09-29).
    """

    def test_mi24p_slots_are_labelled_from_channel_zero(self):
        channel_collections: dict[str, ChannelCollection] = {"c": ChannelCollection.from_dict("c", {})}
        data = {"blue": {"primary_1": {str(k).zfill(2): 250.0 + k for k in range(1, 21)}}}
        channel_lists, _ = parse_channel_lists(data, channel_collections)
        preset = pack_preset_for_type(channel_lists, "blue", "Mi-24P")
        radio = next(iter(preset.radios.values()))

        self.assertEqual(radio.display_labels[1], "00")  # the list's 20th entry, on the selector's 0
        self.assertEqual(radio.display_labels[13], "12")  # the list's 12th entry, on the selector's 12
        channel_13 = next(c for c in radio.channels if c.number == 13)
        self.assertEqual(channel_13.freq, 262.0)


class TestReservedHeadSlotDisplayLabels(unittest.TestCase):
    """An OH-58D radio shows its reserved head slots by name, then presets numbered from 1."""

    def _radios(self):
        channel_collections: dict[str, ChannelCollection] = {"c": ChannelCollection.from_dict("c", {})}
        data = {
            "blue": {
                "primary_1": {str(k).zfill(2): 250.0 + k for k in range(1, 21)},
                "primary_2": {str(k).zfill(2): 130.0 + k for k in range(1, 17)},  # 16 entries, as GermanyCW
                "fm_supplement": {str(k).zfill(2): 30.0 + k for k in range(1, 31)},
            }
        }
        channel_lists, _ = parse_channel_lists(data, channel_collections)
        return pack_preset_for_type(channel_lists, "blue", "OH58D").radios

    def test_uhf_head_slot_is_m_then_presets_from_one(self):
        radio = self._radios()["radio_1"]
        self.assertEqual(radio.display_labels[1], "M")
        self.assertEqual(radio.display_labels[13], "12")
        self.assertEqual(next(c for c in radio.channels if c.number == 13).freq, 262.0)  # preset 12 = entry #12

    def test_short_vhf_list_keeps_preset_numbers(self):
        radio = self._radios()["radio_2"]
        self.assertEqual(radio.display_labels[6], "05")
        self.assertEqual(next(c for c in radio.channels if c.number == 6).freq, 135.0)  # preset 5 = entry #5

    def test_rows_past_the_last_labelled_slot_carry_no_number(self):
        # the page draws 32 rows for every radio: past the 20th slot of a labelled radio, printing the DCS slot
        # ("21" right after "19") would read as one more preset
        radio = self._radios()["radio_1"]
        self.assertEqual(_ch_label(radio, 21), "")
        plain = RadioDefinition(name="r", radio_type="uhf", title="UHF")
        self.assertEqual(_ch_label(plain, 21), "21")  # a radio without labels keeps plain slot numbers

    def test_fm_head_slots_are_c_then_m(self):
        radio = self._radios()["radio_3"]
        self.assertEqual([radio.display_labels[1], radio.display_labels[2], radio.display_labels[3]], ["C", "M", "01"])


if __name__ == "__main__":
    unittest.main()
