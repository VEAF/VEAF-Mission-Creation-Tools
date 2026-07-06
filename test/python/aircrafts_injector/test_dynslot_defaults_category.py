"""FIX-DYNSLOT-TEMPLATE-CATEGORY — dynamic-slot templates must be category-correct.

DCS files dynamic-slot template groups under the *helicopter* table regardless of the real
aircraft, so the extraction (which used to route by the group's DCS location) filed every
airplane template under ``helicopters:``. The fix categorizes by the unit's **real** DCS
category (via ``dcsUnits.yaml``). This guards both the shipped default and the extraction logic.
"""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml
from aircrafts_injector.aircrafts_injector_worker import (
    AircraftGroupsExtractorWorker,
    aircraft_category_for_group,
)
from mission_tools.miz_tools import DcsMission
from veaf_libs.dcs_units_parser import parse_dcs_units

_REPO_ROOT = Path(__file__).parents[3]
_DYNSLOT = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"
_DCS_UNITS = _REPO_ROOT / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "dcsUnits.yaml"

_CATEGORY_TO_BUCKET = {"Plane": "airplanes", "Helicopter": "helicopters"}


def _type_to_bucket() -> dict[str, str]:
    return {
        u.type_id: _CATEGORY_TO_BUCKET[u.category]
        for u in parse_dcs_units(_DCS_UNITS)
        if u.category in _CATEGORY_TO_BUCKET
    }


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


class ShippedDynSlotCategoryTest(unittest.TestCase):
    """The committed default dynamic-slot-templates.yaml must be category-correct."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.data = yaml.safe_load(_DYNSLOT.read_text(encoding="utf-8")) or {}
        cls.type_bucket = _type_to_bucket()

    def test_every_template_sits_in_its_dcs_category_bucket(self) -> None:
        groups = list(_iter_groups(self.data))
        self.assertGreater(len(groups), 0, "no templates found in shipped dynamic-slot-templates.yaml")
        for bucket, coalition, country, group_name, group in groups:
            units = group.get("units")
            if isinstance(units, dict):
                units = list(units.values())
            self.assertTrue(units, f"{group_name} ({coalition}/{country}) has no units")
            utype = units[0].get("type")
            expected = self.type_bucket.get(utype)
            if expected is None:
                continue  # type unknown to dcsUnits.yaml → not enforced (fallback path)
            self.assertEqual(
                bucket,
                expected,
                f"{group_name} ({coalition}/{country}) is under '{bucket}:' but '{utype}' is a DCS "
                f"{expected[:-1]} → must be under '{expected}:'",
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
