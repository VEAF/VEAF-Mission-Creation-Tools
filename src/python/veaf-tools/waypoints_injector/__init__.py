"""
VEAF Waypoints Injector Package

This package provides classes for managing waypoint data and injecting/extracting
waypoints from DCS missions.
"""

from .waypoints_manager import (
    WaypointDefinition,
    FlightPlanDefinition,
    WaypointsManager
)
from .waypoints_injector_worker import (
    WaypointsInjectorWorker,
    WaypointsExtractorWorker
)
from .waypoints_injector_README import (
    WaypointsInjectorREADME,
    WaypointsExtractorREADME
)

__all__ = [
    "WaypointDefinition",
    "FlightPlanDefinition",
    "WaypointsManager",
    "WaypointsInjectorWorker",
    "WaypointsExtractorWorker",
    "WaypointsInjectorREADME",
    "WaypointsExtractorREADME"
]
