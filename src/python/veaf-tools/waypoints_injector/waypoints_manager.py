"""
Waypoint management module for VEAF Waypoints Injector Package.

Handles loading and processing waypoint definitions from YAML files.
"""

from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional, Any
import yaml
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
    name: Optional[str] = None  # Waypoint name
    ETA: float = 0  # Estimated Time of Arrival
    ETA_locked: bool = False  # Whether ETA is locked
    properties: Dict[str, Any] = field(default_factory=dict)  # Additional DCS-specific properties

    def to_dict(self) -> Dict[str, Any]:
        """Convert waypoint to dictionary for DCS mission."""
        result = {
            'type': self.type,
            'action': self.action,
            'alt': self.alt,
            'alt_type': self.alt_type,
            'speed': self.speed,
            'speed_type': self.speed_type,
            'x': self.x,
            'y': self.y,
            'ETA': self.ETA,
            'ETA_locked': self.ETA_locked,
        }
        
        if self.name:
            result['name'] = self.name
        
        # Add any additional properties
        result.update(self.properties)
        
        return result

    @staticmethod
    def from_dict(data: Dict[str, Any]) -> 'WaypointDefinition':
        """Create a waypoint from a dictionary."""
        # Extract known fields
        known_fields = {'type', 'action', 'alt', 'alt_type', 'speed', 'speed_type', 'x', 'y', 'name', 'ETA', 'ETA_locked'}
        
        # Separate known fields from properties
        properties = {k: v for k, v in data.items() if k not in known_fields}
        known_data = {k: v for k, v in data.items() if k in known_fields}
        
        return WaypointDefinition(
            properties=properties,
            **known_data
        )


@dataclass
class FlightPlanDefinition:
    """Represents a complete flight plan for aircraft groups."""
    
    name: str  # Name of the flight plan
    waypoints: List[WaypointDefinition] = field(default_factory=list)  # List of waypoints
    category: Optional[str] = None  # "plane" or "helicopter"
    coalition: Optional[str] = None  # "blue" or "red"
    aircraft_type: Optional[str] = None  # Specific aircraft type (e.g., "F-16C_50")
    country: Optional[str] = None  # Country name
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert flight plan to dictionary."""
        return {
            'name': self.name,
            'category': self.category,
            'coalition': self.coalition,
            'aircraft_type': self.aircraft_type,
            'country': self.country,
            'waypoints': [wp.to_dict() for wp in self.waypoints]
        }


class WaypointsManager:
    """
    Manager class for handling waypoint definitions.
    Loads waypoints from YAML files and provides access to waypoint templates.
    """
    
    def __init__(self):
        """Initialize the waypoints manager."""
        self.waypoints: Dict[str, WaypointDefinition] = {}
        self.flight_plans: Dict[str, FlightPlanDefinition] = {}

    def read_yaml(self, yaml_file: Path) -> None:
        """
        Load waypoint definitions from a YAML file.
        
        Args:
            yaml_file: Path to the YAML file containing waypoints
        """
        if not yaml_file.exists():
            logger.error(f"YAML file not found: {yaml_file}", exception_type=FileNotFoundError)
            return
        
        try:
            with open(yaml_file, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)
            
            if not data:
                logger.warning(f"YAML file is empty: {yaml_file}")
                return
            
            # Load waypoints definitions
            if 'waypoints' in data:
                self._load_waypoints(data['waypoints'])
            
            # Load flight plan settings
            if 'settings' in data:
                self._load_flight_plan_settings(data['settings'])
            
            logger.info(f"Loaded {len(self.waypoints)} waypoint(s) and {len(self.flight_plans)} flight plan template(s)")
        
        except Exception as e:
            logger.error(f"Failed to load YAML file {yaml_file}: {str(e)}", exception_type=type(e))

    def _load_waypoints(self, waypoints_data: Dict[str, Any]) -> None:
        """Load individual waypoint definitions."""
        for name, waypoint_data in waypoints_data.items():
            try:
                waypoint = WaypointDefinition.from_dict(waypoint_data)
                waypoint.name = name
                self.waypoints[name] = waypoint
                logger.debug(f"Loaded waypoint: {name}")
            except Exception as e:
                logger.warning(f"Failed to load waypoint {name}: {str(e)}")

    def _load_flight_plan_settings(self, settings_data: Dict[str, Any]) -> None:
        """Load flight plan settings that define which groups get which waypoints."""
        for plan_name, plan_data in settings_data.items():
            try:
                plan = FlightPlanDefinition(
                    name=plan_name,
                    category=plan_data.get('category'),
                    coalition=plan_data.get('coalition'),
                    aircraft_type=plan_data.get('type'),
                    country=plan_data.get('country')
                )
                
                # Load waypoints for this plan
                if 'waypoints' in plan_data:
                    for wp_name in plan_data['waypoints'].keys():
                        if wp_name in self.waypoints:
                            plan.waypoints.append(self.waypoints[wp_name])
                        else:
                            logger.warning(f"Waypoint '{wp_name}' referenced in plan '{plan_name}' not found")
                
                self.flight_plans[plan_name] = plan
                logger.debug(f"Loaded flight plan: {plan_name} with {len(plan.waypoints)} waypoint(s)")
            except Exception as e:
                logger.warning(f"Failed to load flight plan {plan_name}: {str(e)}")

    def get_flight_plan_for(
        self,
        coalition: Optional[str] = None,
        category: Optional[str] = None,
        aircraft_type: Optional[str] = None,
        country: Optional[str] = None
    ) -> Optional[FlightPlanDefinition]:
        """
        Get a flight plan matching the given criteria.
        
        Tries to find a plan matching: aircraft_type > category > coalition > all
        
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
            if (plan.aircraft_type == aircraft_type or plan.aircraft_type is None) and \
               (plan.coalition == coalition or plan.coalition is None) and \
               (plan.category == category or plan.category is None) and \
               (plan.country == country or plan.country is None):
                return plan
        
        return None

    def get_waypoint(self, name: str) -> Optional[WaypointDefinition]:
        """Get a waypoint by name."""
        return self.waypoints.get(name)

    def get_all_waypoints(self) -> Dict[str, WaypointDefinition]:
        """Get all loaded waypoints."""
        return self.waypoints.copy()

    def get_all_flight_plans(self) -> Dict[str, FlightPlanDefinition]:
        """Get all loaded flight plans."""
        return self.flight_plans.copy()
