"""Tests for the fusion, leading-dummy and trailing-specials primitives (ADR 0010).

These are the three primitives ticket 04 adds on top of ticket 02's Radio layout
mechanism (`rotate_last_to_head`), needed together to reproduce the AJS-37's
single V/UHF radio: a leading dummy (frequency 0), a fusion of two channel-list
roles into one physical radio, and 7 trailing hardcoded special channels with
their own modulations.

Ground truth for the real AJS-37 values: the Tripack `radioSettings.lua` fixture
(`red AJS37`) and `test/python/mission_builder/test_presets_fidelity.py`'s
`TestTripackPresetsFidelity` (the ADR 0003 legacy bespoke-preset path), which pin
the exact frequencies and modulations reproduced here via the new packer path.
"""

import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    Channel,
    HardcodedChannel,
    RadioDefinition,
    RadioLayoutEntry,
    RadioLayoutRadio,
    pack_preset_for_type,
    parse_radio_layouts,
)
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec


def _radio_list(freqs: list[float]) -> RadioDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf")
    for i, freq in enumerate(freqs, start=1):
        radio.add_channel(Channel(name_or_number=i, freq=freq))
    return radio


def _channel_lists(**roles: list[float]) -> dict[str, dict[str, RadioDefinition]]:
    return {"blue": {role: _radio_list(freqs) for role, freqs in roles.items()}}


def _specs(*range_lists: list[FrequencyRange]) -> list[RadioSpec]:
    return [RadioSpec(name=f"radio{i}", ranges=ranges) for i, ranges in enumerate(range_lists, start=1)]


# A single ambiguous V/UHF range, matching the AJS-37's real 103-400 MHz radio.
AJS37_RANGE = [FrequencyRange(min_mhz=103.0, max_mhz=400.0, modulation="AM/FM")]


class TestParseRadioLayoutsNewPrimitives(unittest.TestCase):
    """parse_radio_layouts must read the new fuse/leading_dummy/trailing_specials keys."""

    def test_parses_fuse_leading_dummy_and_trailing_specials(self):
        data = {
            "AJS37": {
                "radios": {
                    1: {
                        "role": "primary_2",
                        "fuse": ["primary_1", "primary_2"],
                        "leading_dummy": {"freq": 0, "mod": 0},
                        "trailing_specials": [
                            {"freq": 30, "mod": 1},
                            {"freq": 243, "mod": 0},
                        ],
                    }
                }
            }
        }
        layouts = parse_radio_layouts(data)
        radio = layouts["AJS37"].radios[1]
        self.assertEqual(radio.fuse, ["primary_1", "primary_2"])
        self.assertEqual(radio.leading_dummy, HardcodedChannel(freq=0, mod=0))
        self.assertEqual(
            radio.trailing_specials,
            [HardcodedChannel(freq=30, mod=1), HardcodedChannel(freq=243, mod=0)],
        )

    def test_primitives_default_to_none_when_absent(self):
        data = {"SomeType": {"radios": {1: {"role": "primary_1"}}}}
        layouts = parse_radio_layouts(data)
        radio = layouts["SomeType"].radios[1]
        self.assertIsNone(radio.fuse)
        self.assertIsNone(radio.leading_dummy)
        self.assertIsNone(radio.trailing_specials)


class TestRadioFusionPrimitive(unittest.TestCase):
    """`fuse`: concatenate several role lists into one physical radio, renumbered."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_two_lists_fused_in_declared_order(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_2", fuse=["primary_1", "primary_2"])}
        )
        primary_1_freqs = [200.0 + i for i in range(3)]
        primary_2_freqs = [130.0 + i for i in range(2)]
        channel_lists = _channel_lists(primary_1=primary_1_freqs, primary_2=primary_2_freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        channels = result[1]["channels"]
        # primary_1's 3 entries first, renumbered 1..3
        self.assertEqual([channels[1], channels[2], channels[3]], primary_1_freqs)
        # then primary_2's 2 entries, renumbered 4..5
        self.assertEqual([channels[4], channels[5]], primary_2_freqs)
        self.assertEqual(len(channels), 5)


class TestLeadingDummyPrimitive(unittest.TestCase):
    """`leading_dummy`: a fixed, source-less channel at slot 1, rest shifted."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_dummy_occupies_slot_one_content_shifts(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", leading_dummy=HardcodedChannel(freq=0, mod=0))}
        )
        freqs = [200.0, 201.0]
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        channels = result[1]["channels"]
        self.assertEqual(channels[1], 0)
        self.assertEqual(channels[2], 200.0)
        self.assertEqual(channels[3], 201.0)
        self.assertEqual(result[1]["modulations"][1], 0)


class TestTrailingSpecialsPrimitive(unittest.TestCase):
    """`trailing_specials`: fixed (freq, mod) pairs appended after the content."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_specials_appended_after_content_with_their_own_modulations(self, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={
                1: RadioLayoutRadio(
                    role="primary_1",
                    trailing_specials=[
                        HardcodedChannel(freq=30.0, mod=1),
                        HardcodedChannel(freq=243.0, mod=0),
                    ],
                )
            }
        )
        freqs = [200.0, 201.0]
        channel_lists = _channel_lists(primary_1=freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        channels = result[1]["channels"]
        modulations = result[1]["modulations"]
        self.assertEqual(channels[3], 30.0)
        self.assertEqual(channels[4], 243.0)
        self.assertEqual(modulations[1], 0)  # untouched content defaults to AM
        self.assertEqual(modulations[3], 1)
        self.assertEqual(modulations[4], 0)


class TestAjs37EndToEnd(unittest.TestCase):
    """Ticket 04 acceptance: the real AJS-37 layout entry, dummy + fusion + specials + mod."""

    def test_ajs37_reproduces_dummy_fused_lists_specials_and_modulations(self):
        primary_1_freqs = [100.0 + i for i in range(20)]  # 20 UHF entries
        primary_2_freqs = [150.0 + i for i in range(19)]  # 19 VHF entries
        channel_lists = _channel_lists(primary_1=primary_1_freqs, primary_2=primary_2_freqs)
        preset = pack_preset_for_type(channel_lists, "blue", "AJS37")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        channels = result[1]["channels"]
        modulations = result[1]["modulations"]

        # slot 1: leading dummy, freq 0, AM
        self.assertEqual(channels[1], 0)
        self.assertEqual(modulations[1], 0)

        # slots 2-21: primary_1's 20 entries in order
        for i, freq in enumerate(primary_1_freqs):
            self.assertEqual(channels[2 + i], freq)

        # slots 22-40: primary_2's 19 entries in order
        for i, freq in enumerate(primary_2_freqs):
            self.assertEqual(channels[22 + i], freq)

        # slots 41-47: hardcoded FR22/FR24 specials (real Tripack values)
        self.assertEqual(channels[41], 30)  # Special 1 - FR22
        self.assertEqual(channels[42], 31)  # Special 2 - FR22
        self.assertEqual(channels[43], 32)  # Special 3 - FR22
        self.assertEqual(channels[44], 33)  # E - FR24
        self.assertEqual(channels[45], 34)  # F - FR24
        self.assertEqual(channels[46], 127.5)  # G - FR24
        self.assertEqual(channels[47], 243)  # H (LARM/GUARD) - FR24

        # modulations: 1-40 AM, 41-45 FM, 46-47 AM
        for slot in list(range(1, 41)) + [46, 47]:
            self.assertEqual(modulations[slot], 0, f"slot {slot} should be AM")
        for slot in range(41, 46):
            self.assertEqual(modulations[slot], 1, f"slot {slot} should be FM")

        self.assertEqual(len(channels), 47)


class TestBespokeOverrideStillWinsOverAjs37Packer(unittest.TestCase):
    """A maker's explicit `presets_assignments` entry still bypasses the packer entirely
    (ADR 0010's manual-override path; no new code needed, this only guards the wiring).
    """

    def test_get_radios_for_returns_explicit_assignment_not_packed_ajs37(self):
        from presets_injector.presets_manager import (
            ChannelCollection,
            PresetAssignment,
            PresetAssignmentCollection,
            PresetDefinition,
            PresetsManager,
            parse_channel_lists,
        )

        manager = PresetsManager()
        manager.channel_collections = {
            "common": ChannelCollection.from_dict(
                name="common", data={"Overlord": {"title": "Overlord", "freqs": {"uhf": 280.0}}}
            )
        }
        data = {"blue": {"primary_1": {"01": "Overlord"}, "primary_2": {"01": "Overlord"}}}
        manager.channel_lists, _ = parse_channel_lists(data, manager.channel_collections)

        bespoke = PresetDefinition(name="bespoke_ajs37")
        manager.preset_assignments = PresetAssignmentCollection()
        manager.preset_assignments.preset_assignments_dict = {
            "blue": {
                "plane": {
                    "AJS37": PresetAssignment(
                        preset_definition=bespoke, coalition="blue", aircraft_type="plane", unit_type="AJS37"
                    )
                }
            }
        }
        preset = manager.get_radios_for("blue", "plane", "AJS37")
        self.assertIs(preset, bespoke)


if __name__ == "__main__":
    unittest.main()
