"""Tests for waypoints_manager — WaypointDefinition, FlightPlanDefinition, WaypointsManager."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from waypoints_injector.waypoints_manager import FlightPlanDefinition, WaypointDefinition, WaypointsManager


class TestWaypointDefinitionToDict(unittest.TestCase):
    def _minimal(self) -> WaypointDefinition:
        return WaypointDefinition(type="Turning Point", action="Turning Point", alt=1000.0)

    def test_known_fields_present(self) -> None:
        d = self._minimal().to_dict()
        self.assertEqual(d["type"], "Turning Point")
        self.assertEqual(d["action"], "Turning Point")
        self.assertEqual(d["alt"], 1000.0)

    def test_name_absent_when_none(self) -> None:
        d = self._minimal().to_dict()
        self.assertNotIn("name", d)

    def test_name_present_when_set(self) -> None:
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=1000.0, name="Alpha")
        self.assertEqual(wp.to_dict()["name"], "Alpha")

    def test_extra_properties_merged(self) -> None:
        wp = WaypointDefinition(
            type="Turning Point",
            action="Turning Point",
            alt=1000.0,
            properties={"task": "CAS", "score": 99},
        )
        d = wp.to_dict()
        self.assertEqual(d["task"], "CAS")
        self.assertEqual(d["score"], 99)

    def test_speed_and_speed_type(self) -> None:
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=500.0, speed=150.0, speed_type="IAS")
        d = wp.to_dict()
        self.assertEqual(d["speed"], 150.0)
        self.assertEqual(d["speed_type"], "IAS")

    def test_eta_fields(self) -> None:
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=0.0, ETA=3600.0, ETA_locked=True)
        d = wp.to_dict()
        self.assertEqual(d["ETA"], 3600.0)
        self.assertTrue(d["ETA_locked"])


class TestWaypointDefinitionFromDict(unittest.TestCase):
    def test_known_fields_populated(self) -> None:
        data = {"type": "Turning Point", "action": "Turning Point", "alt": 2000.0, "speed": 120.0}
        wp = WaypointDefinition.from_dict(data)
        self.assertEqual(wp.type, "Turning Point")
        self.assertEqual(wp.speed, 120.0)

    def test_extra_fields_become_properties(self) -> None:
        data = {"type": "Turning Point", "action": "Turning Point", "alt": 2000.0, "unknown_field": 42}
        wp = WaypointDefinition.from_dict(data)
        self.assertEqual(wp.properties["unknown_field"], 42)

    def test_roundtrip(self) -> None:
        original = WaypointDefinition(
            type="Turning Point",
            action="Turning Point",
            alt=3000.0,
            speed=200.0,
            name="Bravo",
            properties={"task": "None"},
        )
        d = original.to_dict()
        reconstructed = WaypointDefinition.from_dict(d)
        self.assertEqual(reconstructed.type, original.type)
        self.assertEqual(reconstructed.speed, original.speed)


class TestFlightPlanDefinitionToDict(unittest.TestCase):
    def test_empty_flight_plan(self) -> None:
        plan = FlightPlanDefinition(name="TestPlan")
        d = plan.to_dict()
        self.assertEqual(d["name"], "TestPlan")
        self.assertEqual(d["waypoints"], [])
        self.assertIsNone(d["category"])
        self.assertIsNone(d["coalition"])

    def test_with_waypoints(self) -> None:
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=1000.0)
        plan = FlightPlanDefinition(name="Route1", waypoints=[wp], category="plane", coalition="blue")
        d = plan.to_dict()
        self.assertEqual(len(d["waypoints"]), 1)
        self.assertEqual(d["category"], "plane")
        self.assertEqual(d["coalition"], "blue")

    def test_aircraft_type_and_country(self) -> None:
        plan = FlightPlanDefinition(name="P", aircraft_type="F-16C_50", country="USA")
        d = plan.to_dict()
        self.assertEqual(d["aircraft_type"], "F-16C_50")
        self.assertEqual(d["country"], "USA")


class TestWaypointsManagerReadYaml(unittest.TestCase):
    def _write_yaml(self, path: Path, data: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            yaml.dump(data, f)

    def test_loads_waypoints(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            f = Path(td) / "waypoints.yaml"
            self._write_yaml(
                f,
                {
                    "waypoints": {
                        "WP1": {
                            "type": "Turning Point",
                            "action": "Turning Point",
                            "alt": 1000.0,
                        }
                    }
                },
            )
            manager = WaypointsManager()
            manager.read_yaml(f)
            self.assertIn("WP1", manager.waypoints)

    def test_loads_flight_plan_settings(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            f = Path(td) / "waypoints.yaml"
            self._write_yaml(
                f,
                {
                    "waypoints": {
                        "WP1": {"type": "Turning Point", "action": "Turning Point", "alt": 1000.0}
                    },
                    "settings": {
                        "BluePlane": {
                            "coalition": "blue",
                            "category": "plane",
                            "waypoints": {"WP1": {}},
                        }
                    },
                },
            )
            manager = WaypointsManager()
            manager.read_yaml(f)
            self.assertIn("BluePlane", manager.flight_plans)
            self.assertEqual(len(manager.flight_plans["BluePlane"].waypoints), 1)

    def test_missing_yaml_raises_or_logs(self) -> None:
        manager = WaypointsManager()
        # Should not crash; logger.error with exception_type raises FileNotFoundError
        with self.assertRaises(FileNotFoundError):
            manager.read_yaml(Path("/nonexistent/path/nope.yaml"))

    def test_empty_yaml_handled_gracefully(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            f = Path(td) / "empty.yaml"
            f.write_text("", encoding="utf-8")
            manager = WaypointsManager()
            manager.read_yaml(f)
            self.assertEqual(len(manager.waypoints), 0)


class TestWaypointsManagerGetFlightPlanFor(unittest.TestCase):
    def _manager_with_plans(self) -> WaypointsManager:
        m = WaypointsManager()
        m.flight_plans["blue_plane"] = FlightPlanDefinition(name="blue_plane", coalition="blue", category="plane")
        m.flight_plans["blue_helo"] = FlightPlanDefinition(name="blue_helo", coalition="blue", category="helicopter")
        m.flight_plans["f16_specific"] = FlightPlanDefinition(
            name="f16_specific", coalition="blue", aircraft_type="F-16C_50"
        )
        return m

    def test_returns_none_when_no_match(self) -> None:
        m = WaypointsManager()
        self.assertIsNone(m.get_flight_plan_for())

    def test_finds_by_coalition_and_category(self) -> None:
        m = self._manager_with_plans()
        result = m.get_flight_plan_for(coalition="blue", category="plane")
        self.assertIsNotNone(result)

    def test_finds_by_aircraft_type(self) -> None:
        m = self._manager_with_plans()
        result = m.get_flight_plan_for(coalition="blue", aircraft_type="F-16C_50")
        self.assertIsNotNone(result)

    def test_get_waypoint_by_name(self) -> None:
        m = WaypointsManager()
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=500.0)
        m.waypoints["Alpha"] = wp
        self.assertEqual(m.get_waypoint("Alpha"), wp)

    def test_get_waypoint_not_found_returns_none(self) -> None:
        m = WaypointsManager()
        self.assertIsNone(m.get_waypoint("Nonexistent"))

    def test_get_all_waypoints_returns_copy(self) -> None:
        m = WaypointsManager()
        wp = WaypointDefinition(type="Turning Point", action="Turning Point", alt=0.0)
        m.waypoints["X"] = wp
        all_wps = m.get_all_waypoints()
        self.assertIn("X", all_wps)
        all_wps.pop("X")
        self.assertIn("X", m.waypoints)

    def test_get_all_flight_plans_returns_copy(self) -> None:
        m = self._manager_with_plans()
        all_plans = m.get_all_flight_plans()
        self.assertIn("blue_plane", all_plans)
        all_plans.pop("blue_plane")
        self.assertIn("blue_plane", m.flight_plans)


if __name__ == "__main__":
    unittest.main()
