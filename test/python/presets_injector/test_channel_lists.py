import unittest

from presets_injector.presets_manager import (
    ROLE_BANDS,
    ROLE_FM_SECONDARY,
    ROLE_FM_SUBSTITUTE,
    ROLE_FM_SUPPLEMENT,
    ROLE_PRIMARY_1,
    ROLE_PRIMARY_2,
    ChannelCollection,
    RadioDefinition,
    parse_channel_lists,
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


if __name__ == "__main__":
    unittest.main()
