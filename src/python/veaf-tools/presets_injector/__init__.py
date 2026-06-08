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
from .radio_frequency_validator import (
    ChannelFrequency,
    FrequencyRange,
    get_valid_ranges,
    validate_frequencies,
    validate_frequency,
    warn_invalid_channel_frequencies,
    warn_invalid_frequencies,
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
    "ChannelFrequency",
    "FrequencyRange",
    "get_valid_ranges",
    "validate_frequency",
    "validate_frequencies",
    "warn_invalid_channel_frequencies",
    "warn_invalid_frequencies",
]
