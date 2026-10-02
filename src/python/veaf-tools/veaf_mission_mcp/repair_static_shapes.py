"""`repair_static_shapes` — give the statics placed without one the `shape_name` the editor writes.

The `shape_name` fix of #1023 applies to new placements only. The 42 statics Caucasus Open Training v6
placed before it had none, `validate` reported them, and the mission wrote its own
`tools/fix_shape_names.py`; GermanyCW-v6 lost four objectives the same way, DCS refusing a static of
those types without its shape (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 17). Same source as the placement
and the check: the units database (`get_unit_shape_name`).
"""

from pathlib import Path
from typing import Any

from veaf_libs.dcs_units_data import get_unit_shape_name
from veaf_libs.mission_table import indexed

from veaf_mission_mcp.mission_folder import commit_mission, open_mission


def _statics(content: dict[str, Any]) -> list[dict[str, Any]]:
    """Return every static unit of the mission, both coalitions."""
    units: list[dict[str, Any]] = []
    for coalition in (content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            container = country.get("static") if isinstance(country, dict) else None
            if not isinstance(container, dict):
                continue
            for group in indexed(container.get("group")):
                if isinstance(group, dict):
                    units.extend(u for u in indexed(group.get("units")) if isinstance(u, dict))
    return units


def repair_static_shapes(target: Path) -> dict[str, Any]:
    """Fill every missing static `shape_name` the units database knows, in place, backed up first.

    Args:
        target: The mission folder (durable) or a `.miz`.

    Returns:
        ``{"filled": [{unit, type, shape_name}], "unknown": [{unit, type}], "written": bool, "durable"?}``
        — ``unknown`` the statics still without a shape because the database has none for their type
        (DCS resolves many types without one); nothing is written when there is nothing to fill.

    Raises:
        ValueError: If the target is not a readable mission.
    """
    mission, content = open_mission(target)
    filled: list[dict[str, str]] = []
    unknown: list[dict[str, str]] = []
    for unit in _statics(content):
        if unit.get("shape_name"):
            continue
        unit_type = str(unit.get("type") or "")
        shape = get_unit_shape_name(unit_type)
        if shape is None:
            unknown.append({"unit": str(unit.get("name")), "type": unit_type})
            continue
        unit["shape_name"] = shape
        filled.append({"unit": str(unit.get("name")), "type": unit_type, "shape_name": shape})
    result: dict[str, Any] = {"filled": filled, "unknown": unknown, "written": bool(filled)}
    if filled:
        result["durable"] = commit_mission(mission, target)["durable"]
    return result
