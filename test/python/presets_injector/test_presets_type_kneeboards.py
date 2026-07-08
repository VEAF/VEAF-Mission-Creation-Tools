"""Per-type kneeboard generation + Viggen pilot labels + column split (ADR 0012, ticket 04)."""

import unittest

from presets_injector.presets_manager import (
    Channel,
    ChannelCollection,
    PresetDefinition,
    RadioDefinition,
    RadioPresetsImageGenerator,
    _radio_max_slot,
    _split_radio_into_columns,
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


class TestColumnSplit(unittest.TestCase):
    def test_max_slot_counts_labelled_empty_slots(self):
        radio = RadioDefinition(name="r")
        radio.add_channel(Channel(1, 251.0))
        radio.display_labels = {slot: str(99 + slot) for slot in range(1, 41)}
        self.assertEqual(_radio_max_slot(radio), 40)

    def test_split_renumbers_locally_and_carries_labels(self):
        radio = RadioDefinition(name="r", radio_type="uhf", title="V/UHF")
        for slot in range(1, 48):
            radio.add_channel(Channel(slot, 200.0 + slot))
            radio.display_labels[slot] = f"L{slot}"
        columns = _split_radio_into_columns(radio, num_columns=2)
        self.assertEqual(len(columns), 2)
        # 47 slots over 2 columns -> 24 + 23.
        self.assertEqual(len(columns[0].channels), 24)
        self.assertEqual(len(columns[1].channels), 23)
        # Second column's first channel is real slot 25, renumbered to local slot 1,
        # keeping its real pilot label.
        self.assertEqual(columns[1].channels[0].number, 1)
        self.assertEqual(columns[1].channels[0].freq, 225.0)
        self.assertEqual(columns[1].display_labels[1], "L25")

    def test_split_preserves_gaps(self):
        radio = RadioDefinition(name="r")
        radio.add_channel(Channel(1, 201.0))
        radio.add_channel(Channel(3, 203.0))
        radio.display_labels = {slot: f"L{slot}" for slot in range(1, 31)}
        columns = _split_radio_into_columns(radio, num_columns=2)
        # Local slot 2 (real slot 2) is an empty gap: labelled but no channel.
        self.assertNotIn(2, [c.number for c in columns[0].channels])
        self.assertEqual(columns[0].display_labels[2], "L2")


class TestPreparedRenderPreset(unittest.TestCase):
    def test_tall_single_radio_is_split_into_two_columns(self):
        radio = RadioDefinition(name="r")
        for slot in range(1, 48):
            radio.add_channel(Channel(slot, 200.0 + slot))
        preset = PresetDefinition(name="p")
        preset.add_radio(radio)
        render = _generator()._prepare_render_preset(preset, title="AJS37 (blue)")
        self.assertEqual(len(render.radios), 2)
        self.assertEqual(render.title, "AJS37 (blue)")

    def test_short_preset_keeps_its_radios(self):
        preset = _preset(Channel(1, 251.0), Channel(2, 252.0))
        render = _generator()._prepare_render_preset(preset, title="A-10C (blue)")
        self.assertEqual(len(render.radios), 1)


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


if __name__ == "__main__":
    unittest.main()
