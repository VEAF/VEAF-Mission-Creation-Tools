"""
VEAF Waypoints Injector Package

This package provides classes for managing waypoint data and injecting/extracting
waypoints from DCS missions.
"""

from .waypoints_injector_README import WaypointsExtractorREADME, WaypointsInjectorREADME
from .waypoints_injector_worker import WaypointsExtractorWorker, WaypointsInjectorWorker
from .waypoints_manager import FlightPlanDefinition, WaypointDefinition, WaypointsManager

__all__ = [
    "WaypointDefinition",
    "FlightPlanDefinition",
    "WaypointsManager",
    "WaypointsInjectorWorker",
    "WaypointsExtractorWorker",
    "WaypointsInjectorREADME",
    "WaypointsExtractorREADME",
]
