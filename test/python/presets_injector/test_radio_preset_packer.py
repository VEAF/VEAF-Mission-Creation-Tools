import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    Channel,
    ChannelCollection,
    PresetAssignment,
    PresetAssignmentCollection,
    PresetDefinition,
    PresetsManager,
    RadioDefinition,
    pack_preset_for_type,
    parse_channel_lists,
)
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec

UHF_ONLY = [FrequencyRange(min_mhz=225.0, max_mhz=400.0, modulation="AM/FM")]
VHF_ONLY = [FrequencyRange(min_mhz=116.0, max_mhz=152.0, modulation="AM/FM")]
FM_ONLY = [FrequencyRange(min_mhz=30.0, max_mhz=88.0, modulation="FM")]
# A single range spanning both windows (e.g. Mi-8MT's R-863, or a warbird's FuG16).
AMBIGUOUS = [FrequencyRange(min_mhz=100.0, max_mhz=399.9, modulation="AM/FM")]
HF_ONLY = [FrequencyRange(min_mhz=3.75, max_mhz=5.0, modulation="AM")]  # MiG-15bis-shaped


def _radio(freqs: list[float]) -> RadioDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf")
    for i, freq in enumerate(freqs, start=1):
        radio.add_channel(Channel(name_or_number=i, freq=freq))
    return radio


def _channel_lists(**roles: list[float]) -> dict[str, dict[str, RadioDefinition]]:
    return {"blue": {role: _radio(freqs) for role, freqs in roles.items()}}


def _specs(*range_lists: list[FrequencyRange]) -> list[RadioSpec]:
    return [RadioSpec(name=f"radio{i}", ranges=ranges) for i, ranges in enumerate(range_lists, start=1)]


class TestPackPresetForTypeDefaultProjection(unittest.TestCase):
    """No explicit Radio layout entry -> the default projection (ADR 0010).

    Each physical radio is classified from its frequency ranges: radios
    unambiguously dedicated to one sub-band claim that role directly (so a
    deliberately "inverted" aircraft resolves correctly by itself); ambiguous
    combo radios fall back to physical order. This is deliberately NOT a
    positional-only default: exact bands still matter, verified against real
    dcs-radio-specs.yaml data in TestPackPresetRealSpecsEndToEnd below.
    """

    @patch("presets_injector.presets_manager.get_radios")
    def test_clean_two_radio_aircraft(self, mock_get_radios):
        mock_get_radios.return_value = _specs(UHF_ONLY, VHF_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 131.0})
        self.assertNotIn(3, result)

    @patch("presets_injector.presets_manager.get_radios")
    def test_inverted_order_resolves_by_band_not_position(self, mock_get_radios):
        # Physical radio 1 is VHF, radio 2 is UHF (the A-10's real shape) — the
        # default must still put the UHF list on radio 2, not radio 1.
        mock_get_radios.return_value = _specs(VHF_ONLY, UHF_ONLY, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0], fm_supplement=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"], {1: 131.0})  # VHF list on physical radio 1
        self.assertEqual(result[2]["channels"], {1: 280.0})  # UHF list on physical radio 2
        self.assertEqual(result[3]["channels"], {1: 31.0})

    @patch("presets_injector.presets_manager.get_radios")
    def test_two_ambiguous_radios_fall_back_to_physical_order(self, mock_get_radios):
        # Two identical combo radios (e.g. the Hornet's ARC-210 x2) — no band
        # data can tell them apart, so physical order decides.
        mock_get_radios.return_value = _specs(AMBIGUOUS, AMBIGUOUS)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 131.0})

    @patch("presets_injector.presets_manager.get_radios")
    def test_single_ambiguous_radio_plus_fm_gets_primary_1_and_fm_substitute(self, mock_get_radios):
        # One combo primary radio (e.g. Mi-8MT's R-863) + one FM-only radio.
        mock_get_radios.return_value = _specs(AMBIGUOUS, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], fm_substitute=[31.0], fm_supplement=[99.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 31.0})  # fm_substitute, not fm_supplement

    @patch("presets_injector.presets_manager.get_radios")
    def test_two_primaries_plus_fm_gets_fm_supplement(self, mock_get_radios):
        mock_get_radios.return_value = _specs(UHF_ONLY, VHF_ONLY, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0], fm_supplement=[31.0], fm_substitute=[99.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[3]["channels"], {1: 31.0})

    @patch("presets_injector.presets_manager.get_radios")
    def test_second_fm_radio_defaults_to_fm_supplement_copy(self, mock_get_radios):
        # OH-58D-shaped: 2 primaries + 2 FM radios, fm_secondary not declared by the maker.
        mock_get_radios.return_value = _specs(UHF_ONLY, VHF_ONLY, FM_ONLY, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0], fm_supplement=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[3]["channels"], {1: 31.0})
        self.assertEqual(result[4]["channels"], {1: 31.0})  # fm_secondary defaulted to fm_supplement

    @patch("presets_injector.presets_manager.get_radios")
    def test_explicit_fm_secondary_overrides_the_default_copy(self, mock_get_radios):
        mock_get_radios.return_value = _specs(UHF_ONLY, VHF_ONLY, FM_ONLY, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], primary_2=[131.0], fm_supplement=[31.0], fm_secondary=[42.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        result = preset.to_dict()
        self.assertEqual(result[4]["channels"], {1: 42.0})

    @patch("presets_injector.presets_manager.get_radios")
    def test_single_hf_radio_with_no_primary_band_gets_fm_substitute_guess(self, mock_get_radios):
        # No band reaches above the FM ceiling -> treated as an FM-role radio by
        # default; downstream frequency validation is expected to drop the
        # mismatched content and report it (safe degradation, not a crash).
        mock_get_radios.return_value = _specs(HF_ONLY)
        channel_lists = _channel_lists(fm_substitute=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertEqual(preset.to_dict()[1]["channels"], {1: 31.0})

    @patch("presets_injector.presets_manager.get_radios")
    def test_gap_before_last_usable_radio_bails_out(self, mock_get_radios):
        # primary_2 undefined but fm_supplement is -> packing would silently
        # renumber the FM radio to the wrong physical slot.
        mock_get_radios.return_value = _specs(UHF_ONLY, VHF_ONLY, FM_ONLY)
        channel_lists = _channel_lists(primary_1=[280.0], fm_supplement=[31.0])
        preset = pack_preset_for_type(channel_lists, "blue", "SomeType")
        self.assertIsNone(preset)

    @patch("presets_injector.presets_manager.get_radios")
    def test_unknown_unit_type_returns_none(self, mock_get_radios):
        mock_get_radios.return_value = None
        channel_lists = _channel_lists(primary_1=[280.0])
        self.assertIsNone(pack_preset_for_type(channel_lists, "blue", "NotARealType"))

    def test_no_channel_lists_for_coalition_returns_none(self):
        self.assertIsNone(pack_preset_for_type({}, "red", "F-16C_50"))


class TestPackPresetRealSpecsEndToEnd(unittest.TestCase):
    """Ticket 01 acceptance: real flagship aircraft end-to-end, no mocks."""

    def setUp(self):
        self.channel_collections = {
            "common": ChannelCollection.from_dict(
                name="common",
                data={
                    "Overlord": {"title": "Overlord", "freqs": {"uhf": 280.0}},
                    "Batumi": {"title": "Batumi", "freqs": {"vhf": 131.0}},
                    "JTAC": {"title": "JTAC", "freqs": {"fm": 31.0}},
                },
            )
        }

    def _pack(self, unit_type: str, **roles: dict) -> dict:
        channel_lists, _ = parse_channel_lists({"blue": roles}, self.channel_collections)
        preset = pack_preset_for_type(channel_lists, "blue", unit_type)
        self.assertIsNotNone(preset, f"expected a preset for {unit_type}")
        return preset.to_dict()

    def test_f16_receives_uhf_and_vhf_on_the_matching_radios(self):
        result = self._pack("F-16C_50", primary_1={"01": "Overlord"}, primary_2={"01": "Batumi"})
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 131.0})

    def test_fa18_falls_back_to_physical_order_for_its_identical_radios(self):
        result = self._pack("FA-18C_hornet", primary_1={"01": "Overlord"}, primary_2={"01": "Batumi"})
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 131.0})

    def test_a10c_resolves_its_inverted_vhf_first_order_by_itself(self):
        # No explicit layout entry needed: A-10C's radio 1 is VHF, radio 2 UHF.
        result = self._pack(
            "A-10C", primary_1={"01": "Overlord"}, primary_2={"01": "Batumi"}, fm_supplement={"01": "JTAC"}
        )
        self.assertEqual(result[1]["channels"], {1: 131.0})
        self.assertEqual(result[2]["channels"], {1: 280.0})
        self.assertEqual(result[3]["channels"], {1: 31.0})

    def test_ah64d_alias_projects_instead_of_override(self):
        # The mission type "AH-64D" is aliased to the specs key "AH-64D_BLK_II"
        # (FEAT-CONVERTV5-FREQ-ALIASING ticket 03), so the packer now projects it
        # (non-empty preset) instead of leaving it as a manual override.
        result = self._pack(
            "AH-64D", primary_1={"01": "Overlord"}, primary_2={"01": "Batumi"}, fm_supplement={"01": "JTAC"}
        )
        self.assertTrue(result)

    def test_uh1h_single_radio_gets_primary_1_only(self):
        result = self._pack("UH-1H", primary_1={"01": "Overlord"})
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertNotIn(2, result)

    def test_mi8mt_gets_primary_1_and_fm_substitute(self):
        result = self._pack("Mi-8MT", primary_1={"01": "Overlord"}, fm_substitute={"01": "JTAC"})
        self.assertEqual(result[1]["channels"], {1: 280.0})
        self.assertEqual(result[2]["channels"], {1: 31.0})

    def test_warbird_single_radio_resolves_to_primary_2(self):
        # Its lone radio spans both windows in one range (a genuine airframe
        # trait, not classification noise) and resolves to VHF, matching
        # David's decision that warbirds are packed on primary_2.
        result = self._pack("Bf-109K-4", primary_2={"01": "Batumi"})
        self.assertEqual(result[1]["channels"], {1: 131.0})


class TestGetRadiosForOverrideAndFallback(unittest.TestCase):
    """PresetsManager.get_radios_for: explicit assignment always wins (ADR 0010)."""

    def setUp(self):
        self.manager = PresetsManager()
        self.manager.channel_collections = {
            "common": ChannelCollection.from_dict(
                name="common", data={"Overlord": {"title": "Overlord", "freqs": {"uhf": 280.0}}}
            )
        }
        data = {"blue": {"primary_1": {"01": "Overlord"}}}
        self.manager.channel_lists, _ = parse_channel_lists(data, self.manager.channel_collections)

    def test_no_assignment_falls_back_to_packer(self):
        preset = self.manager.get_radios_for("blue", "plane", "F-16C_50")
        self.assertIsNotNone(preset)
        self.assertEqual(preset.to_dict()[1]["channels"], {1: 280.0})

    def test_explicit_none_assignment_disables_and_skips_packer(self):
        self.manager.preset_assignments = PresetAssignmentCollection()
        self.manager.preset_assignments.preset_assignments_dict = {
            "blue": {
                "plane": {
                    "F-16C_50": PresetAssignment(
                        preset_definition=None, coalition="blue", aircraft_type="plane", unit_type="F-16C_50"
                    )
                }
            }
        }
        preset = self.manager.get_radios_for("blue", "plane", "F-16C_50")
        self.assertIsNone(preset)

    def test_explicit_assignment_wins_over_packer(self):
        bespoke = PresetDefinition(name="bespoke")
        self.manager.preset_assignments = PresetAssignmentCollection()
        self.manager.preset_assignments.preset_assignments_dict = {
            "blue": {
                "plane": {
                    "F-16C_50": PresetAssignment(
                        preset_definition=bespoke, coalition="blue", aircraft_type="plane", unit_type="F-16C_50"
                    )
                }
            }
        }
        preset = self.manager.get_radios_for("blue", "plane", "F-16C_50")
        self.assertIs(preset, bespoke)


if __name__ == "__main__":
    unittest.main()
