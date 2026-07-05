"""Tests for the CH-47Fbl1 radio layout entry (ADR 0010, ticket 06).

Real `dcs-radio-specs.yaml` data for CH-47Fbl1 reports 3 physical radios:

1. "VHF FM: ARC-186" — 30-88 MHz FM (its real role), PLUS a secondary
   108-152 MHz AM range (an airband navaid/voice band). That secondary range
   is wide enough to make the packer's default band classifier
   (`_classify_radio`) see it as "vhf"-capable rather than FM, because it
   reaches above the FM ceiling into the V/UHF window.
2. "UHF AM: ARC-164" — 225-400 MHz, unambiguously UHF.
3. "VHF FM: ARC-201D" — 30-88 MHz FM, a clean second FM set.

Ground truth for the intended layout comes from the real Tripack fixture
(`test/python/mission_builder/fixtures/tripack_radioSettings.lua`, "blue
CH-47F"): only 2 radios are meaningfully populated (FM then UHF, both with
channel-0 rotation, matching the Mi-24P's rotation primitive); the fixture's
3rd radio references a mismatched `radioPresetsRed` table with only 10
channels — a Tripack authoring artifact (see the exploration doc §4.2), not a
real airframe layout to reproduce.
"""

import unittest

from presets_injector.presets_manager import (
    Channel,
    ChannelCollection,
    RadioDefinition,
    _assign_roles_by_position,
    _classify_radio,
    pack_preset_for_type,
    parse_channel_lists,
)
from presets_injector.radio_frequency_validator import get_radios


class TestDefaultMisclassifiesCh47fWithoutLayoutEntry(unittest.TestCase):
    """Pin the real bug this ticket works around, using the REAL specs data."""

    def test_radio_1_classifies_as_vhf_not_fm(self):
        # Real spec: ARC-186 radio 1's secondary 108-152 MHz range makes the
        # coarse band classifier call it "vhf" (reaches above the FM ceiling),
        # even though it is an FM-role radio (module name "VHF FM: ARC-186").
        radios = get_radios("CH-47Fbl1")
        self.assertEqual(_classify_radio(radios[0].ranges), "vhf")

    def test_default_projection_puts_vhf_role_on_radio_1_instead_of_fm(self):
        radios = get_radios("CH-47Fbl1")
        role_by_index = _assign_roles_by_position(radios)
        # This is the misclassification: without an explicit layout entry,
        # radio 1 (physical index 0) is assigned primary_2 (VHF), not an FM role.
        self.assertEqual(role_by_index[0], "primary_2")


class TestCh47fEndToEnd(unittest.TestCase):
    """Real dcs-radio-layouts.yaml + dcs-radio-specs.yaml, no mocks."""

    def _list(self, start: float, count: int = 20) -> list[float]:
        return [start + i for i in range(count)]

    def _channel_lists(self, **roles: list[float]) -> dict[str, dict[str, RadioDefinition]]:
        channel_collections: dict[str, ChannelCollection] = {"c": ChannelCollection.from_dict("c", {})}
        data = {
            "blue": {role: {str(i + 1).zfill(2): freq for i, freq in enumerate(freqs)} for role, freqs in roles.items()}
        }
        channel_lists, _ = parse_channel_lists(data, channel_collections)
        return channel_lists

    def test_fm_and_uhf_land_on_the_correct_radios_with_rotation(self):
        fm = self._list(30.0)
        uhf = self._list(300.0)
        channel_lists = self._channel_lists(fm_substitute=fm, primary_1=uhf)
        preset = pack_preset_for_type(channel_lists, "blue", "CH-47Fbl1")
        self.assertIsNotNone(preset)
        result = preset.to_dict()

        radio1 = result[1]["channels"]  # FM (ARC-186), rotated
        self.assertEqual(radio1[1], fm[19])
        for slot in range(2, 21):
            self.assertEqual(radio1[slot], fm[slot - 2])

        radio2 = result[2]["channels"]  # UHF (ARC-164), rotated
        self.assertEqual(radio2[1], uhf[19])
        for slot in range(2, 21):
            self.assertEqual(radio2[slot], uhf[slot - 2])

        # Radio 3 (ARC-201D, 2nd FM) gets no content: fm_secondary defaults to
        # fm_supplement, which is not declared in this test's channel_lists.
        self.assertNotIn(3, result)

    def test_third_radio_gets_content_when_maker_declares_fm_secondary(self):
        fm = self._list(30.0)
        uhf = self._list(300.0)
        fm2 = self._list(400.0)
        channel_lists = self._channel_lists(fm_substitute=fm, primary_1=uhf, fm_secondary=fm2)
        preset = pack_preset_for_type(channel_lists, "blue", "CH-47Fbl1")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertIn(3, result)
        self.assertEqual(result[3]["channels"][1], fm2[0])


if __name__ == "__main__":
    unittest.main()
