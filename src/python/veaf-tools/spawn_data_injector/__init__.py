"""Render and inject the VEAF spawn-data Lua module from YAML.

``veafUnits.lua`` no longer hard-codes its ``UnitsDatabase`` / ``GroupsDatabase``
literals; they live in ``veaf_libs/data/veaf-units.yaml`` (framework) and, per
mission, in ``src/spawn-groups.yaml`` (which may hold both ``units:`` and
``groups:``). At mission build the framework and mission YAML are merged,
rendered to a Lua module that assigns the two tables, and injected into the
``.miz`` after the framework bundle. See ADR 0005.
"""

from __future__ import annotations

from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data, render_spawn_data_lua
from spawn_data_injector.spawn_data_injector_worker import (
    SpawnDataInjectorWorker,
    SpawnDataResult,
    inject_spawn_data,
    merge_spawn_data,
)

__all__ = [
    "load_framework_spawn_data",
    "render_spawn_data_lua",
    "SpawnDataInjectorWorker",
    "SpawnDataResult",
    "inject_spawn_data",
    "merge_spawn_data",
]
