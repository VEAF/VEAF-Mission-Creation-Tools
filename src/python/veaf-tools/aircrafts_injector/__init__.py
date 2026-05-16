"""
VEAF Aircrafts Injector Package

This package provides classes for managing aircraft data and injecting aircraft groups into DCS missions.
"""

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
]
