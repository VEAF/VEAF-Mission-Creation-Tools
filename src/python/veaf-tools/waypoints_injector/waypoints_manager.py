"""
Waypoint management module for VEAF Waypoints Injector Package.

Handles loading and processing waypoint definitions from YAML files.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from veaf_libs.i18n import t, tn
from veaf_libs.logger import logger


@dataclass
class WaypointDefinition:
    """Represents a single waypoint in DCS mission format."""

    type: str  # "Turning Point", "TakeOffGround", "TakeOff", "LandingGround", "Landing", etc.
    action: str  # Action type (e.g., "Turning Point", "Fly Over Ground", etc.)
    alt: float  # Altitude in meters
    alt_type: str = "BARO"  # Altitude type: "BARO" or "RADIO"
    speed: float = 0  # Speed in m/s (0 means default)
    speed_type: str = "TAS"  # Speed type: "TAS" or "IAS"
    x: float = 0  # X coordinate
    y: float = 0  # Y coordinate
    name: str | None = None  # Waypoint name
    ETA: float = 0  # Estimated Time of Arrival
    ETA_locked: bool = False  # Whether ETA is locked
    properties: dict[str, Any] = field(default_factory=dict)  # Additional DCS-specific properties

    def to_dict(self) -> dict[str, Any]:
        """Convert waypoint to dictionary for DCS mission."""
        result = {
            "type": self.type,
            "action": self.action,
            "alt": self.alt,
            "alt_type": self.alt_type,
            "speed": self.speed,
            "speed_type": self.speed_type,
            "x": self.x,
            "y": self.y,
            "ETA": self.ETA,
            "ETA_locked": self.ETA_locked,
        }

        if self.name:
            result["name"] = self.name

        # Add any additional properties
        result.update(self.properties)

        return result

    @staticmethod
    def from_dict(data: dict[str, Any]) -> "WaypointDefinition":
        """Create a waypoint from a dictionary."""
        # Extract known fields
        known_fields = {
            "type",
            "action",
            "alt",
            "alt_type",
            "speed",
            "speed_type",
            "x",
            "y",
            "name",
            "ETA",
            "ETA_locked",
        }

        # Separate known fields from properties
        properties = {k: v for k, v in data.items() if k not in known_fields}
        known_data = {k: v for k, v in data.items() if k in known_fields}

        return WaypointDefinition(properties=properties, **known_data)


@dataclass
class FlightPlanDefinition:
    """Represents a complete flight plan for aircraft groups."""

    name: str  # Name of the flight plan
    waypoints: list[WaypointDefinition] = field(default_factory=list)  # List of waypoints
    category: str | None = None  # "plane" or "helicopter"
    coalition: str | None = None  # "blue" or "red"
    aircraft_type: str | None = None  # Specific aircraft type (e.g., "F-16C_50")
    country: str | None = None  # Country name

    def to_dict(self) -> dict[str, Any]:
        """Convert flight plan to dictionary."""
        return {
            "name": self.name,
            "category": self.category,
            "coalition": self.coalition,
            "aircraft_type": self.aircraft_type,
            "country": self.country,
            "waypoints": [wp.to_dict() for wp in self.waypoints],
        }


class WaypointsManager:
    """
    Manager class for handling waypoint definitions.
    Loads waypoints from YAML files and provides access to waypoint templates.
    """

    def __init__(self):
        """Initialize the waypoints manager."""
        self.waypoints: dict[str, WaypointDefinition] = {}
        self.flight_plans: dict[str, FlightPlanDefinition] = {}

    def read_yaml(self, yaml_file: Path) -> None:
        """
        Load waypoint definitions from a YAML file.

        Args:
            yaml_file: Path to the YAML file containing waypoints
        """
        if not yaml_file.exists():
            logger.error(t("waypoints.yaml_not_found", path=yaml_file), exception_type=FileNotFoundError)
            return

        try:
            with open(yaml_file, encoding="utf-8") as f:
                data = yaml.safe_load(f)

            if not data:
                logger.warning(t("waypoints.yaml_empty", path=yaml_file))
                return

            # Load waypoints definitions
            if "waypoints" in data:
                self._load_waypoints(data["waypoints"])

            # Load flight plan settings
            if "settings" in data:
                self._load_flight_plan_settings(data["settings"])

            logger.info(
                t(
                    "waypoints_manager.loaded",
                    waypoints=tn("waypoints_manager.waypoints_frag", len(self.waypoints)),
                    plans=tn("waypoints_manager.plans_frag", len(self.flight_plans)),
                )
            )

        except Exception as e:
            logger.error(t("waypoints.yaml_load_failed", path=yaml_file, error=str(e)), exception_type=type(e))

    def _load_waypoints(self, waypoints_data: dict[str, Any]) -> None:
        """Load individual waypoint definitions."""
        for name, waypoint_data in waypoints_data.items():
            try:
                waypoint = WaypointDefinition.from_dict(waypoint_data)
                waypoint.name = name
                self.waypoints[name] = waypoint
                logger.debug(f"Loaded waypoint: {name}")
            except Exception as e:
                logger.warning(t("waypoints.waypoint_load_failed", name=name, error=str(e)))

    def _load_flight_plan_settings(self, settings_data: dict[str, Any]) -> None:
        """Load flight plan settings that define which groups get which waypoints."""
        for plan_name, plan_data in settings_data.items():
            try:
                plan = FlightPlanDefinition(
                    name=plan_name,
                    category=plan_data.get("category"),
                    coalition=plan_data.get("coalition"),
                    aircraft_type=plan_data.get("type"),
                    country=plan_data.get("country"),
                )

                # Load waypoints for this plan
                if "waypoints" in plan_data:
                    for wp_name in plan_data["waypoints"].keys():
                        if wp_name in self.waypoints:
                            plan.waypoints.append(self.waypoints[wp_name])
                        else:
                            logger.warning(t("waypoints.plan_waypoint_not_found", name=wp_name, plan=plan_name))

                self.flight_plans[plan_name] = plan
                logger.debug(f"Loaded flight plan: {plan_name} with {len(plan.waypoints)} waypoint(s)")
            except Exception as e:
                logger.warning(t("waypoints.plan_load_failed", plan=plan_name, error=str(e)))

    def get_flight_plan_for(
        self,
        coalition: str | None = None,
        category: str | None = None,
        aircraft_type: str | None = None,
        country: str | None = None,
    ) -> FlightPlanDefinition | None:
        """
        Get a flight plan matching the given criteria.

        **The first compatible plan wins, in declaration order.** Not the most specific one: the loop
        below returns as soon as every criterion a plan states matches, treating the ones it omits as
        wildcards. So a narrow plan declared after a broad one is never reached.

        This docstring claimed an ``aircraft_type > category > coalition > all`` priority until
        2026-08-24. It was never implemented, and the shipped default template demonstrated the
        consequence without anyone noticing: ``all_blue_planes`` is declared before ``f16_flight_plan``,
        so a blue F-16C matched the first and the second was dead configuration. Whether the priority
        should be built is a separate question — see ``FIX-WAYPOINTS-PLAN-PRIORITY``; what is fixed here
        is the description, so the next reader is not misled the same way.

        Args:
            coalition: "blue" or "red"
            category: "plane" or "helicopter"
            aircraft_type: Specific aircraft type
            country: Country name

        Returns:
            FlightPlanDefinition or None if no match found
        """
        # Try to find exact match with aircraft type first
        for plan in self.flight_plans.values():
            if (
                (plan.aircraft_type == aircraft_type or plan.aircraft_type is None)
                and (plan.coalition == coalition or plan.coalition is None)
                and (plan.category == category or plan.category is None)
                and (plan.country == country or plan.country is None)
            ):
                return plan

        return None

    def get_waypoint(self, name: str) -> WaypointDefinition | None:
        """Get a waypoint by name."""
        return self.waypoints.get(name)

    def get_all_waypoints(self) -> dict[str, WaypointDefinition]:
        """Get all loaded waypoints."""
        return self.waypoints.copy()

    def get_all_flight_plans(self) -> dict[str, FlightPlanDefinition]:
        """Get all loaded flight plans."""
        return self.flight_plans.copy()
