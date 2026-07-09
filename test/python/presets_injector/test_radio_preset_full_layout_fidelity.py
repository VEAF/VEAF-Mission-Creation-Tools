"""Full-lot regression test (ADR 0010, ticket 06 acceptance criterion).

Reproduces the real Tripack fixture's channel maps for every headline type
populated across tickets 02-06 (Mi-24P's rotation, AJS-37's fusion/dummy/
specials/modulation, OH-58D's reserved head slots, CH-47F's role fix), all
through `pack_preset_for_type` against the real bundled `dcs-radio-specs.yaml`
and `dcs-radio-layouts.yaml` — no mocks. This is the end-to-end proof that all
five tickets' primitives keep composing correctly together in the shipped
layout file, not just in isolation.
"""

import unittest

from presets_injector.presets_manager import (
    Channel,
    ChannelCollection,
    RadioDefinition,
    pack_preset_for_type,
    parse_channel_lists,
)


def _channel_lists(**roles: list[float]) -> dict[str, dict[str, RadioDefinition]]:
    channel_collections: dict[str, ChannelCollection] = {"c": ChannelCollection.from_dict("c", {})}
    data = {
        "blue": {role: {str(i + 1).zfill(2): freq for i, freq in enumerate(freqs)} for role, freqs in roles.items()}
    }
    channel_lists, _ = parse_channel_lists(data, channel_collections)
    return channel_lists


class TestFullLayoutFidelity(unittest.TestCase):
    def test_mi24p_rotation(self):
        freqs = [100.0 + i for i in range(20)]
        preset = pack_preset_for_type(_channel_lists(primary_1=freqs, fm_substitute=[31.0]), "blue", "Mi-24P")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"][1], freqs[19])  # channel-0 rotation
        self.assertEqual(result[2]["channels"], {1: 31.0})

    def test_ajs37_keyed_groups_wrap_and_specials(self):
        # ADR 0012: key-based Group 100-139 mapping (primary_2's 20th wraps to
        # Group 100 / slot 1) + fixed E/F/G specials at absolute slots 44-46.
        primary_1 = [100.0 + i for i in range(20)]  # keys 1..20
        primary_2 = [150.0 + i for i in range(20)]  # keys 1..20
        preset = pack_preset_for_type(_channel_lists(primary_1=primary_1, primary_2=primary_2), "blue", "AJS37")
        result = preset.to_dict()
        channels = result[1]["channels"]
        self.assertEqual(channels[1], primary_2[19])  # primary_2 key 20 recycled into Group 100
        self.assertEqual(channels[2], primary_1[0])  # primary_1 key 1 -> Group 101
        self.assertEqual(channels[22], primary_2[0])  # primary_2 key 1 -> Group 121
        self.assertEqual(channels[46], 127.5)  # G (fixed airframe constant)
        # 40 data slots + 3 fixed specials (E/F/G); the 4 priority specials are
        # empty (this plan tags no priorities), so they leave their slots unset.
        self.assertEqual(len(channels), 43)

    def test_oh58d_reserved_head_slots(self):
        primary_1 = [100.0 + i for i in range(20)]
        primary_2 = [200.0 + i for i in range(20)]
        fm_supplement = [300.0 + i for i in range(20)]
        channel_lists = _channel_lists(primary_1=primary_1, primary_2=primary_2, fm_supplement=fm_supplement)
        preset = pack_preset_for_type(channel_lists, "blue", "OH58D")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"][1], primary_1[19])  # "M" reserved slot
        self.assertEqual(result[3]["channels"][1], fm_supplement[0])  # "C" reserved slot
        self.assertEqual(result[3]["channels"][2], fm_supplement[19])  # "M" reserved slot

    def test_ch47f_fm_and_uhf_role_fix(self):
        fm = [30.0 + i for i in range(20)]
        uhf = [300.0 + i for i in range(20)]
        preset = pack_preset_for_type(_channel_lists(fm_substitute=fm, primary_1=uhf), "blue", "CH-47Fbl1")
        result = preset.to_dict()
        # radio 1 (ARC-186) carries FM, not the misclassified VHF role.
        self.assertEqual(result[1]["channels"][1], fm[19])
        # radio 2 (ARC-164) carries UHF.
        self.assertEqual(result[2]["channels"][1], uhf[19])


if __name__ == "__main__":
    unittest.main()
