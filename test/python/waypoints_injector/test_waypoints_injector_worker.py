"""Tests for WaypointsInjectorWorker and WaypointsExtractorWorker.

Covers init, load_config, add_group, process_groups, _inject_waypoints_into_group,
WaypointsExtractorWorker init, extract_from_lua, extract_from_mission.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

from mission_tools import DcsMission

from waypoints_injector.waypoints_injector_worker import (
    Group,
    WaypointsExtractorWorker,
    WaypointsInjectorWorker,
)
from waypoints_injector.waypoints_manager import FlightPlanDefinition, WaypointDefinition

# ---------------------------------------------------------------------------
# WaypointsInjectorWorker
# ---------------------------------------------------------------------------


class TestWaypointsInjectorWorkerInit(unittest.TestCase):
    def test_init_no_files(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        self.assertIsNone(worker.waypoints_file)
        self.assertIsNone(worker.input_mission)
        self.assertIsNone(worker.output_mission)
        self.assertEqual(worker.groups, {})
        self.assertIsNotNone(worker.waypoints_manager)
        self.assertIsNone(worker.dcs_mission)

    def test_init_stores_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            waypoints = Path(tmpdir) / "waypoints.yaml"
            mission = Path(tmpdir) / "mission.miz"
            out = Path(tmpdir) / "out.miz"
            waypoints.write_text("waypoints: {}", encoding="utf-8")
            mission.write_bytes(b"PK")
            worker = WaypointsInjectorWorker(waypoints_file=waypoints, input_mission=mission, output_mission=out)
            self.assertEqual(worker.waypoints_file, waypoints)
            self.assertEqual(worker.input_mission, mission)
            self.assertEqual(worker.output_mission, out)


class TestWaypointsInjectorLoadConfig(unittest.TestCase):
    def test_load_config_no_file_returns_manager(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        self.assertIsNotNone(worker.waypoints_manager)

    def test_load_config_nonexistent_file_raises(self) -> None:
        with self.assertRaises((RuntimeError, SystemExit)):
            WaypointsInjectorWorker(
                waypoints_file=Path("/nonexistent/waypoints.yaml"),
                input_mission=None,
                output_mission=None,
            )


class TestAddGroup(unittest.TestCase):
    def _worker(self) -> WaypointsInjectorWorker:
        return WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)

    def test_group_with_name_stored(self) -> None:
        worker = self._worker()
        group_dict = {"name": "Hornet Lead"}
        worker.add_group(group_dict, aircraft_type="plane", country="USA", coalition="blue", category="plane")
        self.assertIn("Hornet Lead", worker.groups)

    def test_group_without_name_not_stored(self) -> None:
        worker = self._worker()
        worker.add_group({}, aircraft_type="plane", country="USA", coalition="blue", category="plane")
        self.assertEqual(len(worker.groups), 0)

    def test_client_pilot_detected(self) -> None:
        worker = self._worker()
        group_dict = {
            "name": "Client Group",
            "units": [{"type": "FA-18C_hornet", "skill": "Client"}],
        }
        worker.add_group(group_dict, aircraft_type="plane", country="USA", coalition="blue", category="plane")
        group = worker.groups["Client Group"]
        self.assertTrue(group.human_pilot)
        self.assertEqual(group.unit_type, "FA-18C_hornet")

    def test_player_pilot_detected(self) -> None:
        worker = self._worker()
        group_dict = {
            "name": "Player Group",
            "units": [{"type": "Su-27", "skill": "Player"}],
        }
        worker.add_group(group_dict, aircraft_type="plane", country="Russia", coalition="red", category="plane")
        group = worker.groups["Player Group"]
        self.assertTrue(group.human_pilot)

    def test_ai_group_not_human(self) -> None:
        worker = self._worker()
        group_dict = {
            "name": "AI Patrol",
            "units": [{"type": "F-16C_50", "skill": "Excellent"}],
        }
        worker.add_group(group_dict, aircraft_type="plane", country="USA", coalition="blue", category="plane")
        self.assertFalse(worker.groups["AI Patrol"].human_pilot)

    def test_multiple_units_first_human_breaks(self) -> None:
        worker = self._worker()
        group_dict = {
            "name": "Mixed",
            "units": [
                {"type": "F-16C_50", "skill": "Client"},
                {"type": "F-16C_50", "skill": "Excellent"},
            ],
        }
        worker.add_group(group_dict, aircraft_type="plane", country="USA", coalition="blue", category="plane")
        self.assertTrue(worker.groups["Mixed"].human_pilot)


class TestInjectWaypointsIntoGroup(unittest.TestCase):
    def test_injects_route_into_group(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        group = Group(
            group_dcs={},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            category="plane",
            name="Alpha",
            unit_type="F-16C_50",
            human_pilot=True,
        )
        wp1 = WaypointDefinition(type="Turning Point", action="Turning Point", alt=1000.0, x=100.0, y=200.0)
        wp2 = WaypointDefinition(type="Turning Point", action="Turning Point", alt=2000.0, x=300.0, y=400.0)
        worker._inject_waypoints_into_group(group, [wp1, wp2])
        self.assertIn("route", group.group_dcs)
        points = group.group_dcs["route"]["points"]
        self.assertEqual(len(points), 2)
        self.assertEqual(points[0]["num"], 1)
        self.assertEqual(points[1]["num"], 2)
        self.assertFalse(group.group_dcs["route"]["routeRelativeTOD"])

    def test_inject_single_waypoint(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        group = Group(
            group_dcs={},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            category="plane",
        )
        wp = WaypointDefinition(type="TakeOffGround", action="TakeOffGround", alt=0.0)
        worker._inject_waypoints_into_group(group, [wp])
        self.assertEqual(len(group.group_dcs["route"]["points"]), 1)


class TestProcessGroups(unittest.TestCase):
    def _worker_with_human_group(self) -> WaypointsInjectorWorker:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        group = Group(
            group_dcs={},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            category="plane",
            name="Human Pilot",
            unit_type="F-16C_50",
            human_pilot=True,
        )
        worker.groups = {"Human Pilot": group}
        return worker

    def test_process_groups_with_flight_plan(self) -> None:
        worker = self._worker_with_human_group()
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=1000.0)
        fp = FlightPlanDefinition(name="test_plan", waypoints=[wp])
        mock_manager = MagicMock()
        mock_manager.get_flight_plan_for.return_value = fp
        worker.waypoints_manager = mock_manager
        worker.process_groups(silent=True)
        group = worker.groups["Human Pilot"]
        self.assertIn("route", group.group_dcs)

    def test_process_groups_no_flight_plan(self) -> None:
        worker = self._worker_with_human_group()
        mock_manager = MagicMock()
        mock_manager.get_flight_plan_for.return_value = None
        worker.waypoints_manager = mock_manager
        worker.process_groups(silent=True)
        # No route injected if no flight plan
        self.assertNotIn("route", worker.groups["Human Pilot"].group_dcs)

    def test_process_groups_no_waypoints_manager(self) -> None:
        worker = self._worker_with_human_group()
        worker.waypoints_manager = None
        worker.process_groups(silent=True)

    def test_process_groups_skips_ai(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        group = Group(
            group_dcs={},
            aircraft_type="plane",
            country="USA",
            coalition="blue",
            category="plane",
            name="AI Group",
            unit_type="F-16C_50",
            human_pilot=False,
        )
        worker.groups = {"AI Group": group}
        mock_manager = MagicMock()
        worker.waypoints_manager = mock_manager
        worker.process_groups(silent=True)
        mock_manager.get_flight_plan_for.assert_not_called()

    def test_process_groups_not_silent(self) -> None:
        worker = WaypointsInjectorWorker(waypoints_file=None, input_mission=None, output_mission=None)
        worker.groups = {}
        worker.waypoints_manager = MagicMock()
        worker.process_groups(silent=False)


# ---------------------------------------------------------------------------
# WaypointsExtractorWorker
# ---------------------------------------------------------------------------


class TestWaypointsExtractorWorkerInit(unittest.TestCase):
    def test_init_with_input_lua(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        self.assertEqual(worker.input_lua, Path("test.lua"))
        self.assertIsNone(worker.input_mission)

    def test_init_with_input_mission(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"))
        self.assertEqual(worker.input_mission, Path("test.miz"))
        self.assertIsNone(worker.input_lua)

    def test_init_neither_raises_value_error(self) -> None:
        with self.assertRaises(ValueError):
            WaypointsExtractorWorker()

    def test_init_both_raises_value_error(self) -> None:
        with self.assertRaises(ValueError):
            WaypointsExtractorWorker(input_mission=Path("a.miz"), input_lua=Path("b.lua"))

    def test_invalid_aircraft_type_raises(self) -> None:
        with self.assertRaises(ValueError):
            WaypointsExtractorWorker(input_lua=Path("test.lua"), aircraft_type="jet")

    def test_valid_aircraft_type_plane(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"), aircraft_type="plane")
        self.assertEqual(worker.aircraft_type, "plane")

    def test_valid_aircraft_type_helicopter(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"), aircraft_type="helicopter")
        self.assertEqual(worker.aircraft_type, "helicopter")

    def test_pattern_compiled(self) -> None:
        import re

        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"), group_name_pattern=r"^Alpha.*")
        self.assertIsInstance(worker.group_name_pattern, re.Pattern)

    def test_default_pattern_matches_all(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        self.assertIsNotNone(worker.group_name_pattern)
        assert worker.group_name_pattern is not None
        self.assertTrue(worker.group_name_pattern.match("anything"))


class TestExtractFromLua(unittest.TestCase):
    def test_extract_all_waypoints(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        worker.lua_data = {"waypoints": {"wp1": {"x": 100, "y": 200}, "wp2": {"x": 300, "y": 400}}}
        worker.extract_from_lua()
        self.assertIn("wp1", worker.matched_groups)
        self.assertIn("wp2", worker.matched_groups)

    def test_extract_with_pattern_filter(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"), group_name_pattern=r"^wp1$")
        worker.lua_data = {"waypoints": {"wp1": {"x": 100}, "wp2": {"x": 200}}}
        worker.extract_from_lua()
        self.assertIn("wp1", worker.matched_groups)
        self.assertNotIn("wp2", worker.matched_groups)

    def test_extract_no_waypoints_key(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        worker.lua_data = {"other_key": {}}
        worker.extract_from_lua()
        self.assertEqual(len(worker.matched_groups), 0)

    def test_extract_no_lua_data_raises(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        # lua_data is None — should raise ValueError
        with self.assertRaises((ValueError, SystemExit)):
            worker.extract_from_lua()

    def test_extract_non_dict_waypoints(self) -> None:
        worker = WaypointsExtractorWorker(input_lua=Path("test.lua"))
        worker.lua_data = {"waypoints": "not_a_dict"}
        worker.extract_from_lua()
        self.assertEqual(len(worker.matched_groups), 0)


class TestExtractFromMission(unittest.TestCase):
    def _make_mission_with_groups(self) -> DcsMission:
        return DcsMission(
            file_path=Path("test.miz"),
            mission_content={
                "coalition": {
                    "blue": {
                        "country": [
                            {
                                "name": "USA",
                                "plane": {
                                    "group": [
                                        {
                                            "name": "F-16 Squadron",
                                            "route": {"points": [{"x": 100.0, "y": 200.0, "alt": 1000.0}]},
                                        }
                                    ]
                                },
                            }
                        ]
                    },
                    "red": {
                        "country": [
                            {
                                "name": "Russia",
                                "helicopter": {
                                    "group": [
                                        {
                                            "name": "Mi-8 Flight",
                                            "route": {"points": [{"x": 50.0, "y": 60.0, "alt": 500.0}]},
                                        }
                                    ]
                                },
                            }
                        ]
                    },
                }
            },
        )

    def test_extract_finds_plane_groups(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"))
        worker.dcs_mission = self._make_mission_with_groups()
        worker.extract_from_mission()
        self.assertTrue(any("F-16 Squadron" in k for k in worker.matched_groups))

    def test_extract_finds_helicopter_groups(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"))
        worker.dcs_mission = self._make_mission_with_groups()
        worker.extract_from_mission()
        self.assertTrue(any("Mi-8 Flight" in k for k in worker.matched_groups))

    def test_extract_no_mission_raises(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"))
        with self.assertRaises((ValueError, SystemExit)):
            worker.extract_from_mission()

    def test_extract_with_pattern_filters(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"), group_name_pattern=r"^F-16.*")
        worker.dcs_mission = self._make_mission_with_groups()
        worker.extract_from_mission()
        matched_names = [v.get("group_name", "") for v in worker.matched_groups.values()]
        self.assertTrue(all("F-16" in n or n == "" for n in matched_names))

    def test_extract_skips_groups_without_waypoints(self) -> None:
        mission = DcsMission(
            file_path=Path("test.miz"),
            mission_content={
                "coalition": {
                    "blue": {
                        "country": [
                            {
                                "name": "USA",
                                "plane": {
                                    "group": [
                                        {
                                            "name": "Empty Group",
                                            "route": {"points": []},
                                        }
                                    ]
                                },
                            }
                        ]
                    }
                }
            },
        )
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"))
        worker.dcs_mission = mission
        worker.extract_from_mission()
        self.assertEqual(len(worker.matched_groups), 0)

    def test_extract_with_aircraft_type_filter(self) -> None:
        worker = WaypointsExtractorWorker(input_mission=Path("test.miz"), aircraft_type="plane")
        worker.dcs_mission = self._make_mission_with_groups()
        worker.extract_from_mission()
        # Should have the F-16 group but not helicopter
        matched_names = [v.get("group_name", "") for v in worker.matched_groups.values()]
        self.assertIn("F-16 Squadron", matched_names)
        self.assertNotIn("Mi-8 Flight", matched_names)


if __name__ == "__main__":
    unittest.main()
