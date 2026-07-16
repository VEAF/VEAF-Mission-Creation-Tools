"""VMCT actions on the declarative source ``mission.yaml`` (wave 4).

The first genuinely *VMCT* action family: edit the design-time source the build consumes to
*generate* the ``.miz``, rather than patching a built artifact (editor-parity / embedded-Lua
/ ``veaf-config.lua`` families). Both actions go through the comment-preserving
``mission_yaml_editor`` brick and back the file up before every write.

Scope is deliberately generic — a module toggle and a config-mapping setter — not a
per-module schema validator: the calling LLM owns the shape of the config it passes, the same
way it owns unit types for ``add_group`` (see ``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md``).
"""

from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml, save_yaml


def _modules_block(path: Path) -> tuple[Any, Any]:
    """Return the loaded document and its ``modules:`` mapping, or raise if malformed.

    Args:
        path: Path to the ``mission.yaml``.

    Returns:
        A ``(document, modules_mapping)`` tuple, both round-trip aware.

    Raises:
        ValueError: If the document has no ``modules:`` mapping.
    """
    data = load_yaml(path)
    modules = data.get("modules") if hasattr(data, "get") else None
    if not hasattr(modules, "get"):
        raise ValueError(f"Mission config has no 'modules:' mapping: {path}")
    return data, modules


def _shape_of(value: Any) -> dict[str, Any]:
    """Classify a module's value into ``mandatory`` / ``scalar`` / ``extended``.

    Args:
        value: The value stored under a module key in the ``modules:`` block.

    Returns:
        `{"shape": ..., "enabled": bool | None, "config": dict | None}`.
    """
    if value is None:
        return {"shape": "mandatory", "enabled": None, "config": None}
    if isinstance(value, bool):
        return {"shape": "scalar", "enabled": value, "config": None}
    if hasattr(value, "get"):
        enabled = value.get("enabled")
        return {
            "shape": "extended",
            "enabled": enabled if isinstance(enabled, bool) else None,
            "config": {key: value[key] for key in value},
        }
    return {"shape": "scalar", "enabled": None, "config": None}


def describe_mission_config(mission_yaml_path: Path) -> dict[str, Any]:
    """List the ``modules:`` block of a ``mission.yaml`` and each module's state.

    Read-only situational awareness before a ``set_mission_module`` write — the VMCT
    counterpart of ``describe_mission`` (which reads the built ``.miz``).

    Args:
        mission_yaml_path: Path to the mission's source ``mission.yaml``.

    Returns:
        `{"modules": {name: {"shape": ..., "enabled": ..., "config": ...}}}`, where ``shape``
        is one of ``mandatory`` (bare key), ``scalar`` (boolean) or ``extended`` (mapping).

    Raises:
        ValueError: If the document has no ``modules:`` mapping.
    """
    _data, modules = _modules_block(mission_yaml_path)
    return {"modules": {name: _shape_of(modules[name]) for name in modules}}


def set_mission_module(
    mission_yaml_path: Path,
    module_id: str,
    value: bool | dict[str, Any],
) -> dict[str, Any]:
    """Set a module to a boolean toggle or an extended config mapping, in place.

    Replaces the module's value if the key is present, inserts it otherwise. Comments and
    formatting of the rest of the file are preserved; the file is backed up first.

    Args:
        mission_yaml_path: Path to the mission's source ``mission.yaml``.
        module_id: The module key (e.g. ``"CTLD"``, ``"COMBATZONE"``).
        value: ``True``/``False`` for the scalar form, or a mapping for the extended
            config block (e.g. ``{"enabled": True, "combat_zones": [...]}``).

    Returns:
        `{"module": module_id, "shape": "scalar" | "extended", "inserted": bool,
        "backup": <backup path as str>}`.

    Raises:
        ValueError: If the document has no ``modules:`` mapping.
    """
    data, modules = _modules_block(mission_yaml_path)
    inserted = module_id not in modules
    shape = "scalar" if isinstance(value, bool) else "extended"
    modules[module_id] = value
    backup = save_yaml(mission_yaml_path, data)
    return {"module": module_id, "shape": shape, "inserted": inserted, "backup": str(backup)}
