import unittest
from pathlib import Path

from presets_injector.presets_manager import (
    ROLE_BANDS,
    ROLE_FM_SECONDARY,
    ROLE_FM_SUBSTITUTE,
    ROLE_FM_SUPPLEMENT,
    ROLE_PRIMARY_1,
    ROLE_PRIMARY_2,
    ChannelCollection,
    PresetsManager,
    RadioDefinition,
    parse_channel_lists,
)

# repo root = .../<root>/test/python/presets_injector/this_file → parents[3]
_SHIPPED_DEFAULT_PRESETS = (
    Path(__file__).resolve().parents[3] / "src" / "defaults" / "mission-folder" / "src" / "presets.yaml"
)


class TestRoles(unittest.TestCase):
    def test_role_bands(self):
        self.assertEqual(
            ROLE_BANDS,
            {
                ROLE_PRIMARY_1: "uhf",
                ROLE_PRIMARY_2: "vhf",
                ROLE_FM_SUBSTITUTE: "fm",
                ROLE_FM_SUPPLEMENT: "fm",
                ROLE_FM_SECONDARY: "fm",
            },
        )


class TestParseChannelLists(unittest.TestCase):
    def setUp(self):
        self.channel_collections = {
            "common": ChannelCollection.from_dict(
                name="common",
                data={
                    "Overlord": {"title": "Overlord", "freqs": {"uhf": 280.0}},
                    "Batumi": {"title": "Batumi / 16X", "freqs": {"uhf": 260.0, "vhf": 131.0}},
                    "Garde": {"title": "Garde", "freqs": {"uhf": 243.0, "vhf": 121.5}},
                },
            )
        }

    def test_parses_a_simple_role_list(self):
        data = {"blue": {"primary_1": {"01": "Overlord", "02": "Garde"}}}
        channel_lists, dropped = parse_channel_lists(data, self.channel_collections)
        radio = channel_lists["blue"]["primary_1"]
        self.assertIsInstance(radio, RadioDefinition)
        self.assertEqual(radio.radio_type, "uhf")
        self.assertEqual([c.freq for c in radio.channels], [280.0, 243.0])
        self.assertEqual(dropped, {})

    def test_resolves_by_the_role_band_not_a_fixed_mode(self):
        # The same alias (Batumi) resolves to a different frequency depending on
        # which role's band it is placed under.
        data = {
            "blue": {
                "primary_1": {"01": "Batumi"},
                "primary_2": {"01": "Batumi"},
            }
        }
        channel_lists, _ = parse_channel_lists(data, self.channel_collections)
        self.assertEqual(channel_lists["blue"]["primary_1"].channels[0].freq, 260.0)
        self.assertEqual(channel_lists["blue"]["primary_2"].channels[0].freq, 131.0)

    def test_channel_lacking_the_role_band_is_dropped_and_recorded(self):
        # "Overlord" has no vhf frequency: it must be dropped from a primary_2 list,
        # not raise, and the drop must be recorded for reporting.
        data = {"blue": {"primary_2": {"01": "Overlord", "02": "Batumi"}}}
        channel_lists, dropped = parse_channel_lists(data, self.channel_collections)
        radio = channel_lists["blue"]["primary_2"]
        self.assertEqual(len(radio.channels), 1)
        self.assertEqual(radio.channels[0].freq, 131.0)
        self.assertEqual(dropped, {"blue": {"primary_2": ["01"]}})

    def test_literal_frequency_is_never_dropped(self):
        data = {"blue": {"fm_supplement": {"01": 31.5}}}
        channel_lists, dropped = parse_channel_lists(data, self.channel_collections)
        self.assertEqual(channel_lists["blue"]["fm_supplement"].channels[0].freq, 31.5)
        self.assertEqual(dropped, {})

    def test_unknown_role_is_rejected(self):
        data = {"blue": {"not_a_role": {"01": "Overlord"}}}
        with self.assertRaises(ValueError):
            parse_channel_lists(data, self.channel_collections)

    def test_unresolved_alias_still_raises(self):
        # A typo'd alias (not found in any collection at all) stays a hard error,
        # regardless of strict=False — that is an authoring mistake, not a
        # role/band mismatch.
        data = {"blue": {"primary_1": {"01": "TypoChannel"}}}
        with self.assertRaises(ValueError):
            parse_channel_lists(data, self.channel_collections)

    def test_fm_secondary_not_defaulted_at_parse_time(self):
        # fm_secondary defaulting to fm_supplement is a packer-time concern
        # (ADR 0010), not a parsing concern — parsing only sees what is declared.
        data = {"blue": {"fm_supplement": {"01": "Overlord"}}}
        channel_lists, _ = parse_channel_lists(data, self.channel_collections)
        self.assertNotIn(ROLE_FM_SECONDARY, channel_lists["blue"])


class TestShippedDefaultMigration(unittest.TestCase):
    """FEAT-RADIO-PRESET-PROJECTION-07: the shipped default's channel_lists must
    project the same effective radios as the legacy radios_collection/
    presets_collection/presets_assignments layers it replaced.
    """

    def setUp(self):
        self.manager = PresetsManager()
        self.manager.read_yaml(_SHIPPED_DEFAULT_PRESETS)

    def test_f16_gets_the_same_uhf_and_vhf_lists_as_the_legacy_preset(self):
        # F-16C_50 had no explicit override under the legacy format (it fell
        # under blue.plane.all: modern_blue_uhf_vhf_fm, radio_uhf_30/radio_vhf_30).
        preset = self.manager.get_radios_for("blue", "plane", "F-16C_50")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"][1], 243.0)  # Guard/UHF
        self.assertEqual(result[1]["channels"][2], 390.0)  # Archer
        self.assertEqual(result[2]["channels"][1], 121.5)  # Guard/VHF
        self.assertEqual(result[2]["channels"][2], 131.0)  # Batumi
        self.assertNotIn(3, result)  # F-16 has no 3rd (FM) radio

    def test_a10c2_is_resolved_by_the_packer_default_without_an_override(self):
        # Legacy format needed an explicit `A-10C_2: modern_blue_vhf_uhf_fm`
        # override to invert UHF/VHF; the packer's default band classification
        # now resolves this by itself (ticket 01), so the override was dropped.
        preset = self.manager.get_radios_for("blue", "plane", "A-10C_2")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"][2], 131.0)  # VHF (Batumi) on radio 1
        self.assertEqual(result[2]["channels"][2], 390.0)  # UHF (Archer) on radio 2
        self.assertEqual(result[3]["channels"][1], 30)  # FM on radio 3

    def test_ch47_keeps_its_explicit_fm_uhf_override(self):
        # The packer's default classifies the CH-47's 3rd radio (ARC-201D) as
        # VHF-capable, which would add an unwanted 3rd radio; the explicit
        # override preserves the legacy 2-radio FM/UHF layout.
        preset = self.manager.get_radios_for("blue", "helicopter", "CH-47Fbl1")
        self.assertIsNotNone(preset)
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"][1], 30)  # FM
        self.assertEqual(result[2]["channels"][1], 243.0)  # UHF (Guard)
        self.assertNotIn(3, result)

    def test_mi8mt_keeps_its_explicit_none_override(self):
        # "none" (disable injection) has no channel_lists equivalent: the
        # explicit override must be preserved (ADR 0010's manual-override path).
        preset = self.manager.get_radios_for("blue", "helicopter", "Mi-8MT")
        self.assertIsNone(preset)

    def test_red_coalition_still_gets_no_injection(self):
        # This ticket migrates the mechanism only: red stays "none" as before.
        self.assertIsNone(self.manager.get_radios_for("red", "plane", "F-16C_50"))
        self.assertIsNone(self.manager.get_radios_for("red", "helicopter", "Mi-8MT"))


if __name__ == "__main__":
    unittest.main()
