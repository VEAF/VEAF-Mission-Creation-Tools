"""
VEAF Mission Builder Package

This package provides classes for building mission files with the VEAF scripts.

Symbols are resolved **lazily** (PEP 562). Importing any one of them used to import all of them:
`from mission_builder.config_migrator import ConfigMigrator` ran this file first, which pulled the
mission builder worker, the guided-checklist model and, through it, **pydantic**. Reported by
Sharko — anything using `ConfigMigrator` as a library outside the packaged environment had to
install a dependency it never touches, and the two measurement harnesses holding this lot honest
are exactly that (FIX-CONVERT-V5-SILENT-LOSSES ticket 05).

`from mission_builder import X` keeps working unchanged; it simply imports what X needs and
nothing else.
"""

from importlib import import_module
from typing import Any

#: Exported name → the submodule that defines it.
_EXPORTS: dict[str, str] = {
    "ConfigMigrator": ".config_migrator",
    "MigrationResult": ".config_migrator",
    "MissionBuilderREADME": ".mission_builder_README",
    "MissionBuilderWorker": ".mission_builder_worker",
    "PromotionResult": ".mission_promoter",
    "promote_mission_to_v6": ".mission_promoter",
    "OtherMissionConverter": ".other_converter",
    "PIPELINE_CANDIDATES": ".v5_converter",
    "V5_PIPELINE_CANDIDATES": ".v5_converter",
    "V6_PIPELINE_CANDIDATES": ".v5_converter",
    "ConversionReport": ".v5_converter",
    "PipelineFile": ".v5_converter",
    "V5Converter": ".v5_converter",
    "convert_pipeline_file": ".v5_pipeline_converters",
}

__all__ = list(_EXPORTS)


def __getattr__(name: str) -> Any:
    """Import the submodule defining *name* on first access (PEP 562).

    Args:
        name: The attribute being read off the package.

    Returns:
        The requested symbol.

    Raises:
        AttributeError: when *name* is not one of this package's exports — same behaviour as a
            plain module, so a typo still fails loudly rather than importing something odd.
    """
    module = _EXPORTS.get(name)
    if module is None:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
    return getattr(import_module(module, __name__), name)


def __dir__() -> list[str]:
    """List the package's exports without importing any of them."""
    return sorted(__all__)
