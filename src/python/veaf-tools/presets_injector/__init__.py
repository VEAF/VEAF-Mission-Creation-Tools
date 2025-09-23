"""
VEAF Presets Injector Package

This package provides classes for managing radio presets data from YAML files.
"""

from .presets_manager import (
    RadioChannel,
    Radio,
    PresetCollection,
    PresetsDefinition,
    PresetAssignment,
    PresetsManager
)
from .presets_injector_worker import PresetsInjectorWorker

__all__ = [
    "RadioChannel",
    "Radio",
    "PresetCollection",
    "PresetsDefinition",
    "PresetAssignment",
    "PresetsManager",
    "PresetsInjectorWorker"
]