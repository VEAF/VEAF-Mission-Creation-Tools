"""FIX-SPAWNABLES-CATEGORY — the shipped default spawnables must be category-correct.

Background
----------
The committed default ``src/defaults/mission-folder/src/spawnables.yaml`` once filed all
50 fixed-wing CAP templates (F-15C, M-2000C, MiGs, …) under the top-level ``helicopters:``
bucket. The injector maps the YAML bucket straight onto the DCS table
(``airplanes`` → ``country.plane.group``, ``helicopters`` → ``country.helicopter.group``,
see :meth:`AircraftGroupsInjectorWorker.inject_groups`), so those planes landed under the
``helicopter`` group table in the built ``.miz``. At runtime MIST then feeds
``Unit.Category.HELICOPTER`` to ``coalition.addGroup`` for a fixed-wing unit — a genuine
category mismatch, not a cosmetic one.

These tests are the regression guard:

* :class:`ShippedSpawnablesCategoryTest` asserts the committed default places every template
  in the bucket matching its units' real DCS category (caught in **both** directions, so a
  helicopter mis-filed under ``airplanes`` fails too).
* :class:`InjectorBucketMappingTest` pins the bucket → DCS-table mapping the guarantee relies on.
"""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml
from aircrafts_injector.aircrafts_injector_worker import AircraftGroupsInjectorWorker
from mission_tools.miz_tools import DcsMission
from veaf_libs.dcs_units_parser import parse_dcs_units

_REPO_ROOT = Path(__file__).parents[3]
_SPAWNABLES = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "spawnables.yaml"
_DCS_UNITS = _REPO_ROOT / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "dcsUnits.yaml"

# DCS top-level category → spawnables.yaml bucket.
_CATEGORY_TO_BUCKET = {"Plane": "airplanes", "Helicopter": "helicopters"}


def _type_to_bucket() -> dict[str, str]:
    """Map every air unit type to its spawnables bucket via the canonical DCS units DB."""
    mapping: dict[str, str] = {}
    for unit in parse_dcs_units(_DCS_UNITS):
        bucket = _CATEGORY_TO_BUCKET.get(unit.category)
        if bucket is not None:
            mapping[unit.type_id] = bucket
    return mapping


def _iter_groups(data: dict):
    """Yield (bucket, coalition, country, group_name, group) for every template."""
    for bucket in ("airplanes", "helicopters"):
        coalitions = (data.get(bucket) or {}).get("coalitions") or {}
        for coalition, countries in coalitions.items():
            for country, groups in (countries or {}).items():
                for group_name, group in (groups or {}).items():
                    yield bucket, coalition, country, group_name, group


class ShippedSpawnablesCategoryTest(unittest.TestCase):
    """The committed default spawnables.yaml must be category-correct."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.data = yaml.safe_load(_SPAWNABLES.read_text(encoding="utf-8")) or {}
        cls.type_bucket = _type_to_bucket()

    def test_every_template_sits_in_its_dcs_category_bucket(self) -> None:
        """Each template's bucket must match its units' real DCS category (both directions)."""
        groups = list(_iter_groups(self.data))
        self.assertGreater(len(groups), 0, "no templates found in shipped spawnables.yaml")

        for bucket, coalition, country, group_name, group in groups:
            units = group.get("units")
            if isinstance(units, dict):
                units = list(units.values())
            self.assertTrue(units, f"{group_name} ({coalition}/{country}) has no units")
            for unit in units:
                utype = unit.get("type")
                expected = self.type_bucket.get(utype)
                self.assertIsNotNone(expected, f"unit type '{utype}' in {group_name} is unknown to dcsUnits.yaml")
                self.assertEqual(
                    bucket,
                    expected,
                    f"{group_name} ({coalition}/{country}) is under '{bucket}:' "
                    f"but unit '{utype}' is a DCS {expected[:-1]} → must be under '{expected}:'",
                )


class InjectorBucketMappingTest(unittest.TestCase):
    """Pin the bucket → DCS-table mapping the shipped-data guarantee depends on."""

    @staticmethod
    def _empty_mission() -> DcsMission:
        return DcsMission(file_path=Path("/dev/null"), mission_content={"coalition": {}})

    def _inject(self, bucket: str, unit_type: str) -> dict:
        worker = AircraftGroupsInjectorWorker(
            input_yaml=Path("/dev/null"), target_mission=Path("/dev/null"), output_mission=Path("/dev/null")
        )
        worker.dcs_mission = self._empty_mission()
        worker.yaml_data = {
            bucket: {
                "coalitions": {
                    "blue": {"USA": {"veafSpawn-Test": {"name": "veafSpawn-Test", "units": [{"type": unit_type}]}}}
                }
            }
        }
        result = worker.inject_groups(silent=True)
        self.assertEqual(result.groups_injected, 1)
        country = worker.dcs_mission.mission_content["coalition"]["blue"]["country"][0]
        return country

    def test_airplanes_bucket_lands_in_plane_table(self) -> None:
        country = self._inject("airplanes", "F-15C")
        self.assertEqual(len(country["plane"]["group"]), 1)
        self.assertEqual(country["helicopter"]["group"], [])

    def test_helicopters_bucket_lands_in_helicopter_table(self) -> None:
        country = self._inject("helicopters", "UH-1H")
        self.assertEqual(len(country["helicopter"]["group"]), 1)
        self.assertEqual(country["plane"]["group"], [])


if __name__ == "__main__":
    unittest.main()
