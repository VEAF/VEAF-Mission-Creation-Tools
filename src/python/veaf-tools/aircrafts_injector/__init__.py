"""
VEAF Aircrafts Injector Package

This package provides classes for managing aircraft data and injecting aircraft groups into DCS missions.
"""

# Aircraft-group sort criteria live in the low-level mission_tools package
# (shared with the v5 converter); re-exported here for backward compatibility.
from mission_tools import (
    KIND_DYNAMIC_TEMPLATE,
    KIND_SPAWNABLE,
    SPAWNABLE_NAME_PREFIX,
    classify_aircraft_group,
)

from .aircraft_groups_extractor_README import AircraftGroupsExtractorREADME
from .aircrafts_injector_injector_README import AircraftGroupsInjectorREADME
from .aircrafts_injector_worker import (
    AircraftGroupsExtractorWorker,
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
    InjectionResult,
    ValidationError,
)

__all__ = [
    "AircraftGroupsInjectorWorker",
    "AircraftGroupsExtractorWorker",
    "AircraftGroupsYAMLValidator",
    "ValidationError",
    "InjectionResult",
    "AircraftGroupsExtractorREADME",
    "AircraftGroupsInjectorREADME",
    "classify_aircraft_group",
    "KIND_SPAWNABLE",
    "KIND_DYNAMIC_TEMPLATE",
    "SPAWNABLE_NAME_PREFIX",
]
