"""
VEAF Presets Injector Package

This package provides classes for managing radio presets data from YAML files.
"""

from .presets_manager import (
    Channel,
    ChannelDefinition,
    ChannelCollection,
    RadioDefinition,
    RadioCollection,
    PresetDefinition,
    PresetCollection,
    PresetAssignment,
    PresetAssignmentCollection,
    PresetsManager
)
from .presets_injector_worker import PresetsInjectorWorker
from .presets_injector_README import PresetsInjectorREADME

__all__ = [
    "Channel",
    "ChannelDefinition",
    "ChannelCollection",
    "RadioDefinition",
    "RadioCollection",
    "PresetDefinition",
    "PresetCollection",
    "PresetAssignment",
    "PresetAssignmentCollection",
    "PresetsManager",
    "PresetsInjectorWorker",
    "PresetsInjectorREADME"
]