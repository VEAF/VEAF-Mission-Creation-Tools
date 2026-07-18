"""`add_trigger_zone` — editor-parity write action: insert a circular trigger zone.

Adds a named circular zone to the mission's ``triggers.zones`` table, the same way a
Mission Maker would draw one in the DCS Mission Editor. This is the trigger zone a VEAF
combat zone needs (``group_validation`` requires it for a ``modules.COMBATZONE`` entry);
combined with ``add_group`` it lets an LLM lay down a full combat zone. Mutation goes
through the backup helper; not deduplicated.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

# DCS circular trigger zone; a neutral translucent white fill by default.
_ZONE_TYPE_CIRCULAR = 0
_DEFAULT_COLOR: list[float] = [1, 1, 1, 0.15]


def add_trigger_zone(
    miz_path: Path,
    *,
    name: str,
    position: dict[str, float],
    radius: float,
    hidden: bool = False,
    color: list[float] | None = None,
) -> dict[str, Any]:
    """Add a circular trigger zone to a mission's source `.miz`, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        name: The zone's name (as referenced by VEAF modules / DCS triggers).
        position: The zone centre, `{"x": ..., "y": ...}`.
        radius: The zone radius, in metres.
        hidden: Whether the zone is hidden in the editor (default false).
        color: RGBA fill as `[r, g, b, a]` (0..1). Defaults to translucent white.

    Returns:
        `{"zone_id": <int>, "name": <str>}`.

    Raises:
        ValueError: If the archive is not a valid mission.
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    zone_id = insert_trigger_zone(
        mission.mission_content, name=name, position=position, radius=radius, hidden=hidden, color=color
    )

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"zone_id": zone_id, "name": name}


def insert_trigger_zone(
    mission_content: dict[str, Any],
    *,
    name: str,
    position: dict[str, float],
    radius: float,
    hidden: bool = False,
    color: list[float] | None = None,
) -> int:
    """Append a circular trigger zone to `mission_content` in place; return its fresh `zoneId`.

    The content-level core shared by the `.miz` action :func:`add_trigger_zone` and the wave-8
    composite builders (which mutate a mission folder's exploded content). Does no I/O.

    Args:
        mission_content: The parsed ``mission`` table to mutate.
        name: The zone's name.
        position: The zone centre, `{"x": ..., "y": ...}`.
        radius: The zone radius, in metres.
        hidden: Whether the zone is hidden in the editor.
        color: RGBA fill `[r, g, b, a]` (0..1); defaults to translucent white.

    Returns:
        The fresh ``zoneId`` assigned to the inserted zone.
    """
    zones = _zones_list(mission_content)
    zone_id = _max_zone_id(zones) + 1
    zones.append(
        {
            "name": name,
            "x": position["x"],
            "y": position["y"],
            "radius": radius,
            "zoneId": zone_id,
            "type": _ZONE_TYPE_CIRCULAR,
            "hidden": hidden,
            "color": color if color is not None else list(_DEFAULT_COLOR),
            "properties": {},
        }
    )
    return zone_id


def _zones_list(mission_content: dict[str, Any]) -> list[dict[str, Any]]:
    """Return the ``triggers.zones`` container as a list, normalising it in place.

    ``triggers.zones`` may deserialize as a list or as an id-keyed dict; a fresh mission
    may have no ``triggers`` table at all. This normalises it to a list held under
    ``triggers.zones`` so the caller can append.
    """
    triggers = mission_content.setdefault("triggers", {})
    zones = triggers.get("zones")
    if isinstance(zones, dict):
        zones = list(zones.values())
        triggers["zones"] = zones
    elif not isinstance(zones, list):
        zones = []
        triggers["zones"] = zones
    return zones


def _max_zone_id(zones: list[dict[str, Any]]) -> int:
    """Return the highest ``zoneId`` in ``zones`` (0 if none)."""
    return max((int(z.get("zoneId", 0) or 0) for z in zones if isinstance(z, dict)), default=0)
