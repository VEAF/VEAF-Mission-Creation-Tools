"""
VEAF Presets Injector Package

This package provides classes for managing radio presets data from YAML files.
"""

from .presets_injector_README import PresetsInjectorREADME
from .presets_injector_worker import PresetsInjectorWorker
from .presets_manager import (
    Channel,
    ChannelCollection,
    ChannelDefinition,
    PresetAssignment,
    PresetAssignmentCollection,
    PresetCollection,
    PresetDefinition,
    PresetsManager,
    RadioCollection,
    RadioDefinition,
)

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
    "PresetsInjectorREADME",
]
