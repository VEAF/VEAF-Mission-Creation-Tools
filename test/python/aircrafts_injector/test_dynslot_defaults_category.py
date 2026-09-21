"""FIX-DYNSLOT-TEMPLATE-CATEGORY — dynamic-slot templates must be category-correct.

DCS files dynamic-slot template groups under the *helicopter* table regardless of the real
aircraft, so the extraction (which used to route by the group's DCS location) filed every
airplane template under ``helicopters:``. The fix categorizes by the unit's **real** DCS
category (via ``dcsUnits.yaml``). This guards both the shipped default and the extraction logic.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest import mock

import yaml
from aircrafts_injector import aircrafts_injector_worker
from aircrafts_injector.aircrafts_injector_worker import (
    AircraftGroupsExtractorWorker,
    aircraft_bucket_for_type,
    aircraft_category_for_group,
)
from mission_tools.miz_tools import DcsMission

_REPO_ROOT = Path(__file__).parents[3]
_DYNSLOT = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"


def _iter_groups(data: dict):
    for bucket in ("airplanes", "helicopters"):
        coalitions = (data.get(bucket) or {}).get("coalitions") or {}
        for coalition, countries in coalitions.items():
            for country, groups in (countries or {}).items():
                for group_name, group in (groups or {}).items():
                    yield bucket, coalition, country, group_name, group


class AircraftCategoryForGroupTest(unittest.TestCase):
    """The type-based categorization helper."""

    def test_airplane_type_overrides_helicopter_location(self) -> None:
        group = {"units": [{"type": "A-10C_2"}]}
        self.assertEqual(aircraft_category_for_group(group, fallback="helicopters"), "airplanes")

    def test_helicopter_type_overrides_airplane_location(self) -> None:
        group = {"units": [{"type": "AH-64D"}]}
        self.assertEqual(aircraft_category_for_group(group, fallback="airplanes"), "helicopters")

    def test_unknown_type_falls_back_to_location(self) -> None:
        group = {"units": [{"type": "NotARealUnit_XYZ"}]}
        self.assertEqual(aircraft_category_for_group(group, fallback="helicopters"), "helicopters")

    def test_no_units_falls_back_to_location(self) -> None:
        self.assertEqual(aircraft_category_for_group({"units": []}, fallback="airplanes"), "airplanes")


class ModAircraftBucketTest(unittest.TestCase):
    """FEAT-DYNSLOT-CATALOGUE-REFRESH ticket 03 — a mod type ``dcsUnits.yaml`` cannot carry.

    ``dcsUnits.yaml`` is generated from the datamine pin and holds stock content only, and the
    file forbids hand edits. So an A-4E-C or a Bronco used to fall through to the fallback — the
    DCS table the group was found in — and DCS files dynamic-slot templates under ``helicopter``
    whatever the aircraft. That is how a Skyhawk came to ship as a helicopter in both coalitions.
    """

    def test_a_mod_airplane_is_an_airplane_despite_the_helicopter_table(self) -> None:
        for mod_type in ("A-4E-C", "Bronco-OV-10A", "T-45"):
            with self.subTest(type=mod_type):
                group = {"units": [{"type": mod_type}]}
                self.assertEqual(aircraft_category_for_group(group, fallback="helicopters"), "airplanes")

    def test_the_units_db_still_answers_for_stock_types(self) -> None:
        self.assertEqual(aircraft_bucket_for_type("AH-64D_BLK_II"), "helicopters")
        self.assertEqual(aircraft_bucket_for_type("A-10C_2"), "airplanes")

    def test_the_units_db_wins_over_the_mod_table(self) -> None:
        """The override can never contradict the generated truth — it only fills its gaps.

        No type is in both tables today, so asserting on the real ones would prove nothing about
        precedence: the mod table is made to claim a stock helicopter is an airplane, and the
        generated database has to win anyway. This is what keeps a stale entry harmless the day
        its airframe enters the datamine.
        """
        with mock.patch.dict(
            aircrafts_injector_worker._MOD_AIRCRAFT_BUCKET,
            {"ah-64d_blk_ii": "airplanes"},
        ):
            self.assertEqual(aircraft_bucket_for_type("AH-64D_BLK_II"), "helicopters")

    def test_a_genuinely_unknown_type_stays_unknown(self) -> None:
        self.assertIsNone(aircraft_bucket_for_type("NotARealUnit_XYZ"))


class ShippedDynSlotCategoryTest(unittest.TestCase):
    """The committed default dynamic-slot-templates.yaml must be category-correct."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.data = yaml.safe_load(_DYNSLOT.read_text(encoding="utf-8")) or {}

    def test_every_template_sits_in_its_dcs_category_bucket(self) -> None:
        groups = list(_iter_groups(self.data))
        self.assertGreater(len(groups), 0, "no templates found in shipped dynamic-slot-templates.yaml")
        for bucket, coalition, country, group_name, group in groups:
            units = group.get("units")
            if isinstance(units, dict):
                units = list(units.values())
            self.assertTrue(units, f"{group_name} ({coalition}/{country}) has no units")
            utype = units[0].get("type")
            # Resolved through the production path (units DB, then the mod table), so a mod
            # airframe is enforced here instead of being skipped as it used to be.
            expected = aircraft_bucket_for_type(str(utype))
            self.assertIsNotNone(
                expected,
                f"unit type '{utype}' in {group_name} is unknown to dcsUnits.yaml and absent from "
                f"the mod table — add it to _MOD_AIRCRAFT_BUCKET rather than trusting the fallback",
            )
            self.assertEqual(
                bucket,
                expected,
                f"{group_name} ({coalition}/{country}) is under '{bucket}:' but '{utype}' is a DCS "
                f"{str(expected)[:-1]} → must be under '{expected}:'",
            )


class ExtractionRoutesByTypeTest(unittest.TestCase):
    """find_matching_groups must route an airplane filed under the helicopter table to airplanes."""

    def test_airplane_under_helicopter_table_is_extracted_as_airplane(self) -> None:
        dummy = Path("/dev/null")
        worker = AircraftGroupsExtractorWorker(
            input_mission=dummy, input_lua=None, output_spawnables=dummy, output_dynamic_templates=dummy
        )
        worker.dcs_mission = DcsMission(
            file_path=dummy,
            mission_content={
                "coalition": {
                    "blue": {
                        "country": [
                            {
                                "name": "USA",
                                "plane": {"group": []},
                                # DCS files the A-10C dynamic-slot template under helicopter:
                                "helicopter": {
                                    "group": [
                                        {
                                            "name": "A-10C II Template",
                                            "dynSpawnTemplate": True,
                                            "units": [{"type": "A-10C_2"}],
                                        }
                                    ]
                                },
                            }
                        ]
                    }
                }
            },
        )
        worker.find_matching_groups(silent=True)
        cats = {info["aircraft_category"] for info in worker.matched_groups.values()}
        self.assertEqual(cats, {"airplanes"}, "A-10C template should be routed to airplanes, not helicopters")


if __name__ == "__main__":
    unittest.main()
