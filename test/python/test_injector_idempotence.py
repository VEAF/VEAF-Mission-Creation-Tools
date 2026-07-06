"""Injector idempotence contract (FEAT-MIGRATE-MISSION-V6-001).

Promoting ``src/mission/`` to v6 means a built mission can be re-extracted and
rebuilt; every injector must therefore be idempotent — re-applying it over a
mission that already holds its output must not create duplicates.

Only the injectors with **add** semantics can duplicate and are locked here:
- waypoints — appends to a route, deduping by waypoint name;
- warehouses — fills nested dicts keyed by aircraft type via ``setdefault``.

The aircraft-group injector has its own dedicated idempotence tests
(``test_aircrafts_injector_worker.py``). Presets and weather are pure field
overwrites (``unit["Radio"]`` / ``start_time`` / merged weather dict), idempotent
by construction — see ``test_weather_injector_worker.test_set_weather_merges_data``.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from mission_tools import DcsMission, Group
from warehouses_injector.warehouses_injector_worker import apply_warehouses
from waypoints_injector.waypoints_injector_worker import WaypointsInjectorWorker
from waypoints_injector.waypoints_manager import WaypointDefinition


class TestWaypointsInjectionIdempotent(unittest.TestCase):
    """Re-injecting the same named waypoints replaces, never appends, duplicates."""

    def _group_with_takeoff(self) -> Group:
        return Group(
            group_dcs={"name": "Hornet", "route": {"points": [{"name": "Takeoff", "x": 0, "y": 0}]}},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
        )

    def test_second_injection_does_not_duplicate(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        group = self._group_with_takeoff()
        waypoints = [
            WaypointDefinition(type="Turning Point", action="Turning Point", alt=5000.0, name="WP1", x=1.0, y=1.0),
            WaypointDefinition(type="Turning Point", action="Turning Point", alt=5000.0, name="WP2", x=2.0, y=2.0),
        ]

        worker._inject_waypoints_into_group(group, waypoints)
        first = [p.get("name") for p in group.group_dcs["route"]["points"]]

        worker._inject_waypoints_into_group(group, waypoints)
        second = [p.get("name") for p in group.group_dcs["route"]["points"]]

        # Takeoff preserved + WP1 + WP2, and stable across the rebuild.
        self.assertEqual(first, ["Takeoff", "WP1", "WP2"])
        self.assertEqual(second, first)


class TestWarehousesInjectionIdempotent(unittest.TestCase):
    """Re-applying a warehouses config keeps one entry per aircraft type."""

    def _mission_with_blue_airport(self) -> tuple[DcsMission, dict]:
        warehouses_content: dict = {"airports": {1: {"coalition": "BLUE"}}}
        mission = DcsMission(
            file_path=Path("dummy.miz"),
            mission_content={"coalition": {}},
            warehouses_content=warehouses_content,
            theatre_content="Caucasus",
        )
        return mission, warehouses_content

    def test_second_apply_does_not_duplicate(self) -> None:
        mission, warehouses_content = self._mission_with_blue_airport()
        # An unknown type defaults to the "planes" sub-table — no units-DB coupling.
        config = {"blue": {"defaults": {"aircrafts": {"TestJet": {"amount": 5}}}}}

        apply_warehouses(mission, config)
        planes_first = dict(warehouses_content["airports"][1]["aircrafts"]["planes"])

        apply_warehouses(mission, config)
        planes_second = warehouses_content["airports"][1]["aircrafts"]["planes"]

        self.assertEqual(list(planes_first.keys()), ["TestJet"])
        self.assertEqual(list(planes_second.keys()), ["TestJet"])
        self.assertEqual(planes_second["TestJet"]["initialAmount"], 5)


if __name__ == "__main__":
    unittest.main()
