"""Flaming Cliffs get a kneeboard and nothing else — FIX-RADIO-LAYOUT-GAPS ticket 03.

David's decision of 2026-08-10, after measuring 40 real VEAF missions: **110 FC3 player slots carry
no `Radio` table, against 2105 non-FC3 slots that do.** These airframes expose no settable radio, so
the deliverable is the **plate** their pilots read while dialling SRS by hand — on all three bands.

The bands are declared in the specs because that is where the packer looks when building a preset at
all. `kneeboard_only` is what keeps that honest: the plate is rendered, and nothing is written into
the mission.
"""

from __future__ import annotations

import unittest

from presets_injector.radio_frequency_validator import get_radios, is_kneeboard_only

FC3 = (
    "Su-27",
    "Su-25",
    "Su-25T",
    "Su-33",
    "MiG-29A",
    "MiG-29S",
    "MiG-29G",
    "J-11A",
    "A-10A",
    "F-15C",
)


class TestTheShippedData(unittest.TestCase):
    def test_every_fc3_type_is_declared(self) -> None:
        # The packer needs radios to project onto; with none it produced nothing and the type lost
        # its plate, which is exactly what the Foothold conversion measured.
        for unit_type in FC3:
            self.assertIsNotNone(get_radios(unit_type), f"{unit_type} has no declared radio")

    def test_all_three_bands_are_declared(self) -> None:
        # David's answer: all three. An FC3 pilot in SRS is not limited to one.
        for unit_type in FC3:
            radios = get_radios(unit_type)
            assert radios is not None
            self.assertEqual(len(radios), 3, f"{unit_type} should declare UHF, VHF and FM")

    def test_the_declared_bands_contain_what_the_shipped_plan_uses(self) -> None:
        # Measured from src/defaults/mission-folder/src/presets.yaml: fm 30.0–59.0, vhf 118.0–141.0,
        # uhf 225.0–391.7. The bounds bound the plan's bands; they are not a claim about hardware.
        needed = (30.0, 59.0, 118.0, 141.0, 225.0, 391.7)
        for unit_type in FC3:
            radios = get_radios(unit_type)
            assert radios is not None
            spans = [(r.min_mhz, r.max_mhz) for radio in radios for r in radio.ranges]
            for freq in needed:
                self.assertTrue(
                    any(lo <= freq <= hi for lo, hi in spans),
                    f"{unit_type} declares no band containing {freq} MHz, which the shipped plan uses",
                )

    def test_they_are_all_flagged_kneeboard_only(self) -> None:
        for unit_type in FC3:
            self.assertTrue(is_kneeboard_only(unit_type), f"{unit_type} must never be injected")

    def test_a_full_fidelity_aircraft_is_not_flagged(self) -> None:
        # The flag has to stay narrow: an F-16C really does have settable radios.
        for unit_type in ("F-16C_50", "FA-18C_hornet", "AJS37", "F-14BU"):
            self.assertFalse(is_kneeboard_only(unit_type), unit_type)

    def test_an_unknown_type_is_not_flagged(self) -> None:
        self.assertFalse(is_kneeboard_only("NoSuchAircraft"))


class TestNothingIsWrittenIntoTheMission(unittest.TestCase):
    """The point of the flag, asserted at the level that decides it."""

    def test_a_kneeboard_only_group_is_skipped_before_the_write(self) -> None:
        from unittest import mock

        from mission_tools import Group
        from presets_injector.presets_injector_worker import PresetsInjectorWorker
        from presets_injector.presets_manager import PresetDefinition, PresetsManager

        worker = PresetsInjectorWorker(presets_file=None, input_mission=None, output_mission=None)
        worker.presets_manager = PresetsManager()

        group = Group(
            group_dcs={"units": [{"skill": "Client", "type": "Su-27"}]},
            aircraft_type="plane",
            country="Russia",
            coalition="red",
            human_pilot=True,
            name="Red 1",
            unit_type="Su-27",
        )
        worker.groups = {"Red 1": group}

        preset = PresetDefinition(name="plan_red")
        with mock.patch.object(worker.presets_manager, "get_radios_for", return_value=preset):
            worker.process_groups(silent=True)

        self.assertIn(("red", "Su-27"), worker._injected_presets, "the plate must still be recorded")
        self.assertNotIn("Radio", group.group_dcs["units"][0], "no Radio table may be written")
        self.assertNotIn("radioSet", group.group_dcs)


if __name__ == "__main__":
    unittest.main()
