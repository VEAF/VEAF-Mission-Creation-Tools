"""Tests for the AJS-37 key-based packer and priority-sourced specials (ADR 0012).

The Viggen's single 47-slot V/UHF radio is packed by the `keyed_groups` primitive
(Groups 100-139 by channel key, with the Group-100 recycle) plus 7 trailing
specials at absolute slots 41-47 — FR22 Special 1/2/3 and FR24 H plan-sourced from
priorities 1-4 (always AM), FR24 E/F/G fixed airframe constants. This replaces the
old fuse + leading_dummy shape and deliberately drops ADR 0003 iso-functionality
for the AJS-37 (slot 1 is now primary_2's 20th channel, not a dummy). The faithful
convert-v5 copy (`presets.v5.yaml`) is a separate, unchanged path.
"""

import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    Channel,
    HardcodedChannel,
    KeyedGroups,
    RadioDefinition,
    RadioLayoutEntry,
    RadioLayoutRadio,
    pack_preset_for_type,
    parse_radio_layouts,
)
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec


def _radio(*channels: Channel) -> RadioDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf")
    for channel in channels:
        radio.add_channel(channel)
    return radio


def _channel_lists(**roles: RadioDefinition) -> dict[str, dict[str, RadioDefinition]]:
    return {"blue": dict(roles)}


def _specs(*range_lists: list[FrequencyRange]) -> list[RadioSpec]:
    return [RadioSpec(name=f"radio{i}", ranges=ranges) for i, ranges in enumerate(range_lists, start=1)]


# A single ambiguous V/UHF range, matching the AJS-37's real 103-400 MHz radio.
AJS37_RANGE = [FrequencyRange(min_mhz=103.0, max_mhz=400.0, modulation="AM/FM")]

# The real AJS-37 keyed_groups shape (bases primary_1=100, primary_2=120).
_AJS37_KEYED = KeyedGroups(block_size=40, bases={"primary_1": 100, "primary_2": 120})


class TestParseAjs37Primitives(unittest.TestCase):
    """parse_radio_layouts reads keyed_groups and the trailing_specials {priority}/label variant."""

    def test_parses_keyed_groups(self):
        data = {
            "AJS37": {
                "radios": {
                    1: {
                        "role": "primary_1",
                        "keyed_groups": {"block_size": 40, "bases": {"primary_1": 100, "primary_2": 120}},
                    }
                }
            }
        }
        radio = parse_radio_layouts(data)["AJS37"].radios[1]
        self.assertEqual(radio.keyed_groups, KeyedGroups(block_size=40, bases={"primary_1": 100, "primary_2": 120}))

    def test_parses_priority_and_hardcoded_specials_with_labels(self):
        data = {
            "AJS37": {
                "radios": {
                    1: {
                        "role": "primary_1",
                        "trailing_specials": [
                            {"priority": 1, "label": "Sp1"},
                            {"freq": 127.5, "mod": 0, "label": "G"},
                        ],
                    }
                }
            }
        }
        specials = parse_radio_layouts(data)["AJS37"].radios[1].trailing_specials
        self.assertEqual(specials[0], HardcodedChannel(priority=1, label="Sp1"))
        self.assertEqual(specials[1], HardcodedChannel(freq=127.5, mod=0, label="G"))

    def test_primitives_default_to_none_when_absent(self):
        radio = parse_radio_layouts({"SomeType": {"radios": {1: {"role": "primary_1"}}}})["SomeType"].radios[1]
        self.assertIsNone(radio.keyed_groups)
        self.assertIsNone(radio.trailing_specials)

    @patch("presets_injector.presets_manager.logger")
    def test_special_with_neither_freq_nor_priority_is_dropped_with_warning(self, mock_logger):
        data = {"T": {"radios": {1: {"role": "primary_1", "trailing_specials": [{"label": "oops"}]}}}}
        specials = parse_radio_layouts(data)["T"].radios[1].trailing_specials
        self.assertEqual(specials, [])
        mock_logger.warning.assert_called()

    @patch("presets_injector.presets_manager.logger")
    def test_special_with_both_freq_and_priority_keeps_priority_and_warns(self, mock_logger):
        data = {"T": {"radios": {1: {"role": "primary_1", "trailing_specials": [{"freq": 30, "priority": 2}]}}}}
        special = parse_radio_layouts(data)["T"].radios[1].trailing_specials[0]
        self.assertIsNone(special.freq)
        self.assertEqual(special.priority, 2)
        mock_logger.warning.assert_called()


class TestKeyedGroupsPacking(unittest.TestCase):
    """`keyed_groups`: key-based placement into Groups 100-139 with the Group-100 wrap."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def _pack(self, primary_1, primary_2, mock_get_radios, mock_get_layout):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", keyed_groups=_AJS37_KEYED)}
        )
        channel_lists = _channel_lists(primary_1=_radio(*primary_1), primary_2=_radio(*primary_2))
        return pack_preset_for_type(channel_lists, "blue", "AJS37").to_dict()[1]["channels"]

    def test_primary_1_key_maps_to_group_100_plus_key(self):
        channels = self._pack([Channel(4, 204.0)], [])
        self.assertEqual(channels, {5: 204.0})  # key 4 -> Group 104 -> slot 5

    def test_primary_2_key_maps_to_group_120_plus_key(self):
        channels = self._pack([], [Channel(1, 131.0)])
        self.assertEqual(channels, {22: 131.0})  # key 1 -> Group 121 -> slot 22

    def test_primary_2_key_20_wraps_to_slot_1(self):
        channels = self._pack([], [Channel(20, 140.0)])
        self.assertEqual(channels, {1: 140.0})  # key 20 -> Group 140 -> wraps to Group 100 -> slot 1

    def test_gaps_are_preserved(self):
        channels = self._pack([Channel(1, 201.0), Channel(3, 203.0)], [])
        self.assertEqual(channels, {2: 201.0, 4: 203.0})  # Group 102 (key 2) left empty

    @patch("presets_injector.presets_manager.logger")
    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def test_key_beyond_role_share_is_dropped_with_warning(self, mock_get_radios, mock_get_layout, mock_logger):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", keyed_groups=_AJS37_KEYED)}
        )
        channel_lists = _channel_lists(primary_1=_radio(Channel(21, 221.0)), primary_2=_radio())
        preset = pack_preset_for_type(channel_lists, "blue", "AJS37")
        self.assertIsNone(preset)  # the only channel was out of range -> nothing left
        mock_logger.warning.assert_called()


class TestPrioritySpecials(unittest.TestCase):
    """`trailing_specials` with {priority}: plan-sourced (AM), plus fixed airframe constants."""

    @patch("presets_injector.presets_manager.get_radio_layout")
    @patch("presets_injector.presets_manager.get_radios")
    def _pack(self, specials, primary_1, mock_get_radios, mock_get_layout, primary_2=None):
        mock_get_radios.return_value = _specs(AJS37_RANGE)
        mock_get_layout.return_value = RadioLayoutEntry(
            radios={1: RadioLayoutRadio(role="primary_1", keyed_groups=_AJS37_KEYED, trailing_specials=specials)}
        )
        channel_lists = _channel_lists(primary_1=_radio(*primary_1), primary_2=_radio(*(primary_2 or [])))
        return pack_preset_for_type(channel_lists, "blue", "AJS37").to_dict()[1]

    def test_priority_special_takes_plan_freq_at_absolute_slot_am(self):
        radio = self._pack(
            [HardcodedChannel(priority=1, label="Sp1")],
            [Channel(1, 300.0, priority=1)],
        )
        self.assertEqual(radio["channels"][41], 300.0)  # slot 41 = block_size (40) + 1
        self.assertEqual(radio["modulations"][41], 0)  # plan-sourced specials are AM

    def test_hardcoded_and_priority_specials_keep_absolute_slots(self):
        # A missing priority (no priority-2 channel) leaves slot 42 empty, but the
        # hardcoded E at offset 2 must still land on slot 43, not shift up to 42.
        radio = self._pack(
            [
                HardcodedChannel(priority=1),
                HardcodedChannel(priority=2),  # unresolved -> empty
                HardcodedChannel(freq=33.0, mod=1),  # E
            ],
            [Channel(1, 300.0, priority=1)],
        )
        channels = radio["channels"]
        self.assertEqual(channels[41], 300.0)
        self.assertNotIn(42, channels)  # missing priority -> empty slot
        self.assertEqual(channels[43], 33.0)  # E keeps its absolute slot
        self.assertEqual(radio["modulations"][43], 1)  # hardcoded E is FM

    @patch("presets_injector.presets_manager.logger")
    def test_duplicate_priority_warns_and_first_wins(self, mock_logger):
        radio = self._pack(
            [HardcodedChannel(priority=1)],
            [Channel(1, 300.0, priority=1), Channel(2, 301.0, priority=1)],
        )
        self.assertEqual(radio["channels"][41], 300.0)  # first (by role order) wins
        mock_logger.warning.assert_called()


class TestAjs37EndToEnd(unittest.TestCase):
    """The real bundled AJS-37 layout: full 47-slot map, no mocks."""

    def test_ajs37_full_map_with_wrap_and_specials(self):
        primary_1 = _radio(*(Channel(k, 300.0 + k, priority={5: 1, 6: 2, 10: 4}.get(k)) for k in range(1, 21)))
        primary_2 = _radio(*(Channel(k, 130.0 + k, priority=(3 if k == 3 else None)) for k in range(1, 21)))
        preset = pack_preset_for_type(_channel_lists(primary_1=primary_1, primary_2=primary_2), "blue", "AJS37")
        self.assertIsNotNone(preset)
        result = preset.to_dict()[1]
        channels = result["channels"]

        self.assertEqual(channels[1], 150.0)  # primary_2 key 20 wrapped to Group 100
        self.assertEqual(channels[2], 301.0)  # primary_1 key 1 -> Group 101
        self.assertEqual(channels[21], 320.0)  # primary_1 key 20 -> Group 120
        self.assertEqual(channels[22], 131.0)  # primary_2 key 1 -> Group 121
        self.assertEqual(channels[40], 149.0)  # primary_2 key 19 -> Group 139

        self.assertEqual(channels[41], 305.0)  # Sp1 <- priority 1 (primary_1 key 5)
        self.assertEqual(channels[42], 306.0)  # Sp2 <- priority 2
        self.assertEqual(channels[43], 133.0)  # Sp3 <- priority 3 (primary_2 key 3)
        self.assertEqual(channels[44], 33)  # E (fixed)
        self.assertEqual(channels[45], 34)  # F (fixed)
        self.assertEqual(channels[46], 127.5)  # G (fixed)
        self.assertEqual(channels[47], 310.0)  # H <- priority 4 (primary_1 key 10)
        self.assertEqual(len(channels), 47)

        # modulations: data + priority specials AM (0); fixed E/F FM (1), G AM (0).
        self.assertEqual(result["modulations"][41], 0)
        self.assertEqual(result["modulations"][44], 1)
        self.assertEqual(result["modulations"][46], 0)


class TestBespokeOverrideStillWinsOverAjs37Packer(unittest.TestCase):
    """A maker's explicit presets_assignments entry still bypasses the packer entirely."""

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
        self.assertIs(manager.get_radios_for("blue", "plane", "AJS37"), bespoke)


if __name__ == "__main__":
    unittest.main()
