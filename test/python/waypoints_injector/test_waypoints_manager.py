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
                    "waypoints": {"WP1": {"type": "Turning Point", "action": "Turning Point", "alt": 1000.0}},
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


class TestFlightPlanSpecificity(unittest.TestCase):
    """FIX-WAYPOINTS-PLAN-PRIORITY — the most specific plan wins, not the first compatible one.

    The old behaviour returned the first plan whose stated criteria matched, so declaration order
    decided. The shipped default template demonstrated the cost without anyone noticing:
    `all_blue_planes` was declared before `f16_flight_plan`, a blue F-16C matched the first, and the
    F-16 plan was configuration no aircraft could ever reach.

    What these tests pin above all is that the outcome no longer depends on the order the plans happen
    to be written in — which is why the same overlap is asserted twice, once in each order.
    """

    def _manager(self, *plans: FlightPlanDefinition) -> WaypointsManager:
        manager = WaypointsManager()
        for plan in plans:
            manager.flight_plans[plan.name] = plan
        return manager

    #: A blue F-16C plane, the case the shipped template got wrong.
    F16 = dict(coalition="blue", category="plane", aircraft_type="F-16C_50")

    def test_the_narrow_plan_wins_when_declared_last(self) -> None:
        """The old defect, stated as plainly as it can be."""
        broad = FlightPlanDefinition(name="broad", coalition="blue", category="plane")
        narrow = FlightPlanDefinition(name="narrow", coalition="blue", category="plane", aircraft_type="F-16C_50")
        manager = self._manager(broad, narrow)
        self.assertEqual(manager.get_flight_plan_for(**self.F16).name, "narrow")

    def test_and_when_declared_first(self) -> None:
        """The same overlap the other way round: the answer must not move."""
        narrow = FlightPlanDefinition(name="narrow", coalition="blue", category="plane", aircraft_type="F-16C_50")
        broad = FlightPlanDefinition(name="broad", coalition="blue", category="plane")
        manager = self._manager(narrow, broad)
        self.assertEqual(manager.get_flight_plan_for(**self.F16).name, "narrow")

    def test_a_catch_all_never_beats_a_stated_criterion(self) -> None:
        """A plan with no criteria matches everything, so it must always lose to anything else."""
        catch_all = FlightPlanDefinition(name="catch_all")
        specific = FlightPlanDefinition(name="specific", coalition="blue")
        self.assertEqual(self._manager(catch_all, specific).get_flight_plan_for(**self.F16).name, "specific")
        self.assertEqual(self._manager(specific, catch_all).get_flight_plan_for(**self.F16).name, "specific")

    def test_a_catch_all_is_still_used_when_nothing_else_matches(self) -> None:
        """Losing every contest is not the same as being ignored."""
        catch_all = FlightPlanDefinition(name="catch_all")
        red_only = FlightPlanDefinition(name="red_only", coalition="red")
        manager = self._manager(red_only, catch_all)
        self.assertEqual(manager.get_flight_plan_for(**self.F16).name, "catch_all")

    def test_a_tie_is_broken_by_declaration_order(self) -> None:
        """Two plans of equal specificity: the first declared wins, deterministically.

        Kept from the old behaviour on purpose. The alternative is an outcome that depends on dictionary
        iteration, which would make the same file build differently for no visible reason.
        """
        first = FlightPlanDefinition(name="first", coalition="blue", category="plane")
        second = FlightPlanDefinition(name="second", coalition="blue", category="plane")
        self.assertEqual(self._manager(first, second).get_flight_plan_for(**self.F16).name, "first")
        self.assertEqual(self._manager(second, first).get_flight_plan_for(**self.F16).name, "second")

    def test_a_plan_stating_a_different_value_is_not_a_candidate(self) -> None:
        """Specificity only decides between plans that match; it never makes a wrong plan win."""
        wrong = FlightPlanDefinition(
            name="wrong", coalition="red", category="plane", aircraft_type="F-16C_50", country="USA"
        )
        right = FlightPlanDefinition(name="right", coalition="blue")
        manager = self._manager(wrong, right)
        self.assertEqual(manager.get_flight_plan_for(**self.F16).name, "right")

    def test_nothing_matches_returns_none(self) -> None:
        manager = self._manager(FlightPlanDefinition(name="red_helos", coalition="red", category="helicopter"))
        self.assertIsNone(manager.get_flight_plan_for(**self.F16))

    def test_country_counts_towards_specificity(self) -> None:
        """All four criteria are equal; a country-bearing plan is not a second-class citizen."""
        without = FlightPlanDefinition(name="without", coalition="blue", category="plane")
        with_country = FlightPlanDefinition(name="with_country", coalition="blue", category="plane", country="USA")
        manager = self._manager(without, with_country)
        self.assertEqual(manager.get_flight_plan_for(country="USA", **self.F16).name, "with_country")

    def test_specificity_counts_stated_criteria(self) -> None:
        """The score itself, so a failure points at the cause rather than at a plan name."""
        self.assertEqual(FlightPlanDefinition(name="none").specificity, 0)
        self.assertEqual(FlightPlanDefinition(name="one", coalition="blue").specificity, 1)
        self.assertEqual(
            FlightPlanDefinition(
                name="all", coalition="blue", category="plane", aircraft_type="F-16C_50", country="USA"
            ).specificity,
            4,
        )


class TestShippedTemplateMatching(unittest.TestCase):
    """The shipped default template must not contain a plan no aircraft can reach.

    This is the file every mission folder is created from, and its `f16_flight_plan` was dead
    configuration presented as the illustration of "give one airframe its own plan". A unit test on
    invented plans would not have caught that — it took asking the real matcher about the real file.
    """

    TEMPLATE = Path(__file__).resolve().parents[3] / "src/defaults/mission-folder/src/waypoints.yaml"

    def setUp(self) -> None:
        self.manager = WaypointsManager()
        self.manager.read_yaml(self.TEMPLATE)

    def test_the_template_is_readable_and_declares_plans(self) -> None:
        self.assertGreater(len(self.manager.flight_plans), 2, "far fewer plans than the template ships")

    def test_a_blue_f16_reaches_the_f16_plan(self) -> None:
        plan = self.manager.get_flight_plan_for(coalition="blue", category="plane", aircraft_type="F-16C_50")
        self.assertIsNotNone(plan)
        self.assertEqual(plan.name, "f16_flight_plan")

    def test_another_blue_plane_still_gets_the_broad_plan(self) -> None:
        """The narrow plan must win for its own type and for nothing else."""
        plan = self.manager.get_flight_plan_for(coalition="blue", category="plane", aircraft_type="FA-18C_hornet")
        self.assertEqual(plan.name, "all_blue_planes")

    def test_every_plan_in_the_template_is_reachable(self) -> None:
        """A plan nothing can reach is dead configuration, and shipping one teaches the wrong lesson."""
        reachable = set()
        for coalition in ("blue", "red", "neutrals"):
            for category in ("plane", "helicopter"):
                for aircraft_type in (None, "F-16C_50", "FA-18C_hornet", "Mi-8MT"):
                    plan = self.manager.get_flight_plan_for(
                        coalition=coalition, category=category, aircraft_type=aircraft_type
                    )
                    if plan:
                        reachable.add(plan.name)

        unreachable = sorted(set(self.manager.flight_plans) - reachable)
        self.assertEqual(
            unreachable,
            [],
            "these plans in the shipped template cannot be reached by any aircraft, so they are dead "
            "configuration shipped as an example: " + ", ".join(unreachable),
        )
