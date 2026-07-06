"""Regression tests for iso-functional radio-presets conversion (ADR 0003).

These lock the bespoke-layout behaviour of ``convert_presets`` against the real
Tripack ``radioSettings.lua`` fixture: the Mi-24P channel rotation + FM radio and
the AJS37 leading dummy, hardcoded specials and per-channel modulations must all
round-trip into a dedicated per-aircraft preset.

Also covers the model-level ``modulations`` round-trip on ``RadioDefinition``,
and (FEAT-RADIO-PRESET-PROJECTION-08, ADR 0010) the preset-plan generation that
``convert_presets`` now performs by default alongside the legacy bespoke path.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any

import yaml
from mission_builder.v5_pipeline_converters import convert_presets
from presets_injector.presets_manager import (
    Channel,
    PresetDefinition,
    PresetsManager,
    RadioDefinition,
)

_FIXTURE = Path(__file__).parent / "fixtures" / "tripack_radioSettings.lua"


def _load_faithful(v6_path: Path) -> dict[str, Any]:
    """Load the faithful, iso-functional presets file.

    FEAT-CONVERTV5-PLAN-PRESETS: ``convert_presets`` now writes two files when a
    shared channel list exists — a lean plan (``presets.yaml``) and the faithful
    copy (``presets.v5.yaml``). Fidelity assertions target the faithful copy;
    when no channel list exists (single-file legacy output) ``presets.yaml`` is
    itself the faithful file.
    """
    faithful = v6_path.with_name(f"{v6_path.stem}.v5{v6_path.suffix}")
    target = faithful if faithful.exists() else v6_path
    return yaml.safe_load(target.read_text(encoding="utf-8"))


def _assignment_for(data: dict[str, Any], coalition: str, aircraft: str) -> str | None:
    """Return the preset assigned to *aircraft* in either category, or ``None``."""
    coalition_asg = data.get("presets_assignments", {}).get(coalition, {})
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
        cls.data = _load_faithful(out)

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

    # ── No data loss: every bespoke channel must resolve to a frequency ─────────

    def test_no_dropped_channel_warnings(self) -> None:
        # The known-good Tripack fixture must convert without dropping any channel
        # (every preset token resolves and no value is an unsupported expression).
        dropped = [w for w in self.warnings if "could not be converted" in w or "n'ont pas pu être convertis" in w]
        self.assertEqual(dropped, [])


class TestTripackPresetPlanGeneration(unittest.TestCase):
    """FEAT-RADIO-PRESET-PROJECTION-08 (ADR 0010): convert_presets emits a
    ``channel_lists`` preset plan by default, alongside the legacy bespoke path.

    The real Tripack fixture's shared channel lists do **not** exactly factor
    for any of its four quirky aircraft (verified empirically against the
    phase-1 packer, not assumed from the ADR): Mi-24P's FM list is a 30-entry
    mission-wide table but the airframe's v5 entry only ever used 10 of them
    (the packer would happily emit all 30 — a divergence from the exact v5
    map); AJS-37's fused radio needs exactly 47 slots but the mission's
    ``primary_2`` list has 20 entries where the fixture's own Viggen layout
    only consumes 19 (an authoring quirk specific to how Tripack fitted this
    aircraft — the packer's 20-entry fuse overflows by one slot and shifts
    every trailing special, both coalitions); OH-58D and CH-47F were already
    known-divergent (tickets 03/07 implementation notes: the fixture itself
    has a stale/buggy OH-58D head-slot fill, and CH-47F's radio 1 content
    doesn't match the Radio layout's `fm_substitute` band assignment). ADR
    0003's prime directive ("no data loss, ever") means all four keep their
    legacy dedicated preset as the safety-net fallback for this fixture — the
    plan is generated and covers every *standard* aircraft, but bespoke
    aircraft only drop their override when the packer provably reproduces
    them exactly (covered on a minimal, controlled fixture in
    ``test_v5_pipeline_converters.py::TestConvertPresetsPlanGeneration
    ::test_bespoke_aircraft_reproduced_by_packer_gets_no_override``).
    """

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        out = Path(cls._tmp.name) / "presets.yaml"
        cls.warnings = convert_presets(_FIXTURE, out)
        # presets.yaml is the lean plan (build-loaded); presets.v5.yaml the faithful copy.
        cls.data = yaml.safe_load(out.read_text(encoding="utf-8"))
        cls.faithful = _load_faithful(out)
        cls.manager = PresetsManager()
        cls.manager.read_yaml(out)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def test_channel_lists_generated_by_default(self) -> None:
        self.assertIn("channel_lists", self.data)
        self.assertIn("blue", self.data["channel_lists"])
        self.assertIn("red", self.data["channel_lists"])

    def test_channel_lists_cover_primary_and_fm_roles(self) -> None:
        blue = self.data["channel_lists"]["blue"]
        self.assertIn("primary_1", blue)
        self.assertIn("primary_2", blue)
        self.assertIn("fm_substitute", blue)
        self.assertIn("fm_supplement", blue)

    def test_standard_aircraft_fully_covered_by_plan(self) -> None:
        # F-86F Sabre (a clean UHF 1:1 layout) needs no override either before
        # or after ticket 08 — the plan's primary_1 list covers it directly.
        self.assertIsNone(_assignment_for(self.data, "blue", "F-86F Sabre"))
        preset = self.manager.get_radios_for(coalition="blue", aircraft_type="plane", unit_type="F-86F Sabre")
        self.assertIsNotNone(preset)

    def test_warbird_projected_onto_vhf_from_plan(self) -> None:
        # The whole point of the plan (FEAT-CONVERTV5-PLAN-PRESETS): a warbird
        # with no override is projected by the packer onto its VHF-capable radio
        # straight from the crystallisation — not left on its old FuG16 freqs.
        preset = self.manager.get_radios_for(coalition="blue", aircraft_type="plane", unit_type="Bf-109K-4")
        self.assertIsNotNone(preset)
        self.assertTrue(preset.radios, msg="packer must project at least one radio onto the warbird")
        projected = {ch.freq for radio in preset.radios.values() for ch in radio.channels}
        plan_vhf = set(self.data["channel_lists"]["blue"]["primary_2"].values())
        self.assertTrue(
            projected & plan_vhf,
            msg="warbird radio must carry the plan's VHF (primary_2) crystallisation channels",
        )

    # ── Bespoke aircraft: kept iso-functionally in presets.v5.yaml, delegated ──
    # to the packer (best effort) in the lean presets.yaml plan.
    #
    # (FEAT-CONVERTV5-PLAN-PRESETS: the four quirky Tripack aircraft do not
    # factor exactly, so the faithful copy keeps their dedicated override, while
    # the plan drops it — the packer projects them from the crystallisation,
    # possibly at best effort, and the maker is warned.)

    def test_mi24p_keeps_its_dedicated_preset_in_faithful(self) -> None:
        self.assertEqual(_assignment_for(self.faithful, "blue", "Mi-24P"), "blue_mi_24p")
        self.assertEqual(_assignment_for(self.faithful, "red", "Mi-24P"), "red_mi_24p")

    def test_ajs37_keeps_its_dedicated_preset_in_faithful(self) -> None:
        self.assertEqual(_assignment_for(self.faithful, "red", "AJS37"), "red_ajs37")

    def test_oh58d_keeps_its_dedicated_preset_in_faithful(self) -> None:
        self.assertEqual(_assignment_for(self.faithful, "blue", "OH58D"), "blue_oh58d")

    def test_ch47f_keeps_its_dedicated_preset_in_faithful(self) -> None:
        self.assertEqual(_assignment_for(self.faithful, "blue", "CH-47Fbl1"), "blue_ch_47fbl1")

    def test_plan_drops_reducible_bespoke_overrides(self) -> None:
        # The lean plan file no longer carries a dedicated override for the
        # packer-projectable bespoke aircraft — the packer handles them.
        for coalition, aircraft in (
            ("blue", "Mi-24P"),
            ("red", "AJS37"),
            ("blue", "OH58D"),
            ("blue", "CH-47Fbl1"),
        ):
            self.assertIsNone(_assignment_for(self.data, coalition, aircraft))

    def test_plan_warns_about_best_effort_projection(self) -> None:
        # The maker is told (once) which aircraft the plan projects at best effort.
        self.assertTrue(
            any("Mi-24P" in w and "AJS37" in w for w in self.warnings),
            msg="expected a best-effort summary warning naming the projected aircraft",
        )

    def test_fallback_aircraft_frequencies_unchanged_from_legacy_only_conversion(self) -> None:
        # No-data-loss guarantee (ADR 0003): every kept-fallback aircraft's
        # channels in the faithful copy are byte-identical to the legacy-only
        # conversion — confirming the plan work touched no legacy frequency.
        oh58d = self.faithful["radios_collection"]["blue_radios"]["radio_blue_oh58d_1"]
        self.assertEqual(oh58d["channels"][1], 284.000)  # ##RADIO1_01## duplicated "M" channel
        self.assertEqual(oh58d["channels"][2], 284.000)
        ch47f = self.faithful["radios_collection"]["blue_radios"]["radio_blue_ch_47fbl1_2"]
        self.assertEqual(ch47f["channels"][1], 243.000)  # ##RADIO1_20## rotated to head
        self.assertEqual(ch47f["channels"][2], 284.000)  # ##RADIO1_01##

    def test_fallback_warning_names_the_affected_aircraft(self) -> None:
        combined = " ".join(self.warnings)
        for aircraft in ("Mi-24P", "AJS37", "OH58D", "CH-47Fbl1"):
            self.assertIn(aircraft, combined)


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


class TestPlanFrequencyAliasing(unittest.TestCase):
    """FEAT-CONVERTV5-FREQ-ALIASING: the build-loaded plan (presets.yaml) uses
    readable aliases; the faithful copy (presets.v5.yaml) stays byte-identical/raw."""

    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory()
        out = Path(cls._tmp.name) / "presets.yaml"
        convert_presets(_FIXTURE, out)
        cls.plan = yaml.safe_load(out.read_text(encoding="utf-8"))
        cls.faithful = _load_faithful(out)

    @classmethod
    def tearDownClass(cls) -> None:
        cls._tmp.cleanup()

    def test_plan_channel_lists_use_alias(self) -> None:
        # 243.0 (##RADIO1_20##) is the generic VEAF "Guard" channel.
        primary_1 = self.plan["channel_lists"]["blue"]["primary_1"]
        self.assertIn("Guard", primary_1.values())

    def test_plan_embeds_channels_collection(self) -> None:
        aliases = self.plan["channels_collection"]["aliases"]
        self.assertEqual(aliases["Guard"]["freqs"]["uhf"], 243.0)

    def test_faithful_copy_keeps_raw_frequency(self) -> None:
        radio = self.faithful["radios_collection"]["blue_radios"]["radio_blue_mi_24p_1"]
        self.assertEqual(radio["channels"][1], 243.0)
        self.assertNotIn("channels_collection", self.faithful)
