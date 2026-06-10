"""Regression tests for iso-functional radio-presets conversion (ADR 0003).

These lock the bespoke-layout behaviour of ``convert_presets`` against the real
Tripack ``radioSettings.lua`` fixture: the Mi-24P channel rotation + FM radio and
the AJS37 leading dummy, hardcoded specials and per-channel modulations must all
round-trip into a dedicated per-aircraft preset.

Also covers the model-level ``modulations`` round-trip on ``RadioDefinition``.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any

import yaml
from mission_builder.v5_pipeline_converters import convert_presets
from presets_injector.presets_manager import Channel, PresetDefinition, RadioDefinition

_FIXTURE = Path(__file__).parent / "fixtures" / "tripack_radioSettings.lua"


def _assignment_for(data: dict[str, Any], coalition: str, aircraft: str) -> str | None:
    """Return the preset assigned to *aircraft* in either category, or ``None``."""
    coalition_asg = data["presets_assignments"][coalition]
    for category in ("plane", "helicopter"):
        if aircraft in coalition_asg.get(category, {}):
            return coalition_asg[category][aircraft]
    return None


class TestTripackPresetsFidelity(unittest.TestCase):
    """convert_presets must reproduce bespoke v5 radio layouts iso-functionally."""

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        out = Path(cls._tmp.name) / "presets.yaml"
        cls.warnings = convert_presets(_FIXTURE, out)
        cls.data = yaml.safe_load(out.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    # ── Mi-24P: channel rotation (ch0 → preset #20) + second FM radio ──────────

    def test_mi24p_assigned_dedicated_preset(self) -> None:
        self.assertEqual(_assignment_for(self.data, "blue", "Mi-24P"), "blue_mi_24p")

    def test_mi24p_has_two_radios(self) -> None:
        preset = self.data["presets_collection"]["blue_presets"]["blue_mi_24p"]
        self.assertEqual(set(preset["radios"]), {"radio_1", "radio_2"})

    def test_mi24p_rotation_preserved(self) -> None:
        radio = self.data["radios_collection"]["blue_radios"]["radio_blue_mi_24p_1"]
        # Slot [1] (DCS channel 0) holds preset #20, then 1..19 follow.
        self.assertEqual(radio["channels"][1], 243.000)  # ##RADIO1_20##
        self.assertEqual(radio["channels"][2], 284.000)  # ##RADIO1_01##
        self.assertEqual(radio["channels"][20], 268.500)  # ##RADIO1_19##

    def test_mi24p_second_fm_radio_preserved(self) -> None:
        radio = self.data["radios_collection"]["blue_radios"]["radio_blue_mi_24p_2"]
        self.assertEqual(radio["type"], "fm")
        self.assertEqual(radio["channels"][1], 31.000)  # ##RADIO3_01##
        self.assertEqual(radio["channels"][10], 40.000)  # ##RADIO3_10##

    def test_mi24p_rotation_radio_has_no_modulations(self) -> None:
        # The Mi-24P radio has an empty modulations table → channels stay plain floats.
        radio = self.data["radios_collection"]["blue_radios"]["radio_blue_mi_24p_1"]
        self.assertNotIsInstance(radio["channels"][1], dict)

    # ── AJS37: leading dummy, hardcoded specials, modulations ──────────────────

    def test_ajs37_assigned_dedicated_preset(self) -> None:
        self.assertEqual(_assignment_for(self.data, "red", "AJS37"), "red_ajs37")

    def test_ajs37_leading_dummy_preserved(self) -> None:
        radio = self.data["radios_collection"]["red_radios"]["radio_red_ajs37_1"]
        # Channel [1] is the "channel 100" dummy (frequency 0).
        self.assertEqual(radio["channels"][1]["freq"], 0)

    def test_ajs37_hardcoded_specials_preserved(self) -> None:
        radio = self.data["radios_collection"]["red_radios"]["radio_red_ajs37_1"]
        self.assertEqual(radio["channels"][41]["freq"], 30)  # Special 1 - FR22
        self.assertEqual(radio["channels"][46]["freq"], 127.5)  # G - FR24
        self.assertEqual(radio["channels"][47]["freq"], 243)  # H (LARM/GUARD)

    def test_ajs37_modulations_preserved(self) -> None:
        radio = self.data["radios_collection"]["red_radios"]["radio_red_ajs37_1"]
        # Channels 1..40 are AM (0); 41..45 are FM (1); 46..47 are AM (0).
        self.assertEqual(radio["channels"][2]["mod"], 0)
        self.assertEqual(radio["channels"][41]["mod"], 1)
        self.assertEqual(radio["channels"][45]["mod"], 1)
        self.assertEqual(radio["channels"][46]["mod"], 0)

    def test_ajs37_resolved_preset_token(self) -> None:
        radio = self.data["radios_collection"]["red_radios"]["radio_red_ajs37_1"]
        # Channel [2] references ##RADIO1_01## (red table → 243.000).
        self.assertEqual(radio["channels"][2]["freq"], 243.000)

    # ── Standard aircraft keep the lightweight shared assignment ───────────────

    def test_standard_uhf_aircraft_not_duplicated(self) -> None:
        # F-86F Sabre is a clean UHF 1:1 layout → covered by the "all" fallback.
        self.assertIsNone(_assignment_for(self.data, "blue", "F-86F Sabre"))


class TestRadioModulationRoundTrip(unittest.TestCase):
    """RadioDefinition.to_dict must emit a parallel modulations table when present."""

    def test_modulations_emitted_when_any_channel_has_mod(self) -> None:
        radio = RadioDefinition(name="r", radio_type="vhf")
        radio.add_channel(Channel(name_or_number=1, freq=284.0, mod=0))
        radio.add_channel(Channel(name_or_number=2, freq=271.5, mod=1))
        result = radio.to_dict()
        self.assertEqual(result["modulations"], {1: 0, 2: 1})
        self.assertEqual(result["channels"], {1: 284.0, 2: 271.5})

    def test_modulations_absent_when_no_channel_has_mod(self) -> None:
        radio = RadioDefinition(name="r", radio_type="vhf")
        radio.add_channel(Channel(name_or_number=1, freq=284.0))
        self.assertNotIn("modulations", radio.to_dict())

    def test_partial_modulations_default_to_zero(self) -> None:
        radio = RadioDefinition(name="r", radio_type="vhf")
        radio.add_channel(Channel(name_or_number=1, freq=284.0, mod=1))
        radio.add_channel(Channel(name_or_number=2, freq=271.5))  # no mod → 0
        self.assertEqual(radio.to_dict()["modulations"], {1: 1, 2: 0})

    def test_preset_to_dict_includes_modulations(self) -> None:
        radio = RadioDefinition(name="r", radio_type="vhf")
        radio.add_channel(Channel(name_or_number=1, freq=284.0, mod=1))
        preset = PresetDefinition(name="p")
        preset.add_radio(radio)
        self.assertEqual(preset.to_dict()[1]["modulations"], {1: 1})


class TestRadioDefinitionFromDictMod(unittest.TestCase):
    """RadioDefinition.from_dict must read a per-channel ``mod`` field."""

    def test_mod_read_from_channel_dict(self) -> None:
        radio = RadioDefinition.from_dict(
            name="r",
            data={"type": "vhf", "channels": {1: {"freq": 284.0, "mod": 1}, 2: 271.5}},
            channel_collections={},
        )
        result = radio.to_dict()
        self.assertEqual(result["channels"], {1: 284.0, 2: 271.5})
        self.assertEqual(result["modulations"], {1: 1, 2: 0})

    def test_zero_frequency_channel_accepted(self) -> None:
        # AJS37 channel 100 has freq 0; it must not be treated as "missing".
        radio = RadioDefinition.from_dict(
            name="r",
            data={"type": "vhf", "channels": {1: {"freq": 0, "mod": 0}}},
            channel_collections={},
        )
        self.assertEqual(radio.to_dict()["channels"], {1: 0})


if __name__ == "__main__":
    unittest.main()
