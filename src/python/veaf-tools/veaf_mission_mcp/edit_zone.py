"""`edit_zone` — reshape, move, rename, link and remove a trigger zone.

Ticket 06 of ``FEAT-MCP-MUTATION-ACTIONS``. ``add_trigger_zone`` creates a **circular** zone and
nothing edited one afterwards, so adjusting a VEAF combat zone — which *is* a trigger zone — meant
deleting it and rebuilding it.

**Two measurements came before any code**, as the ticket required:

- **A polygon zone's real shape**, read out of ``veaf-demo-mission.miz`` (``czBatumi``): ``type: 2``
  plus a ``verticies`` list — DCS's own spelling, kept verbatim because correcting the typo would
  write a field DCS ignores — while ``x``, ``y`` and ``radius`` **stay present**. A polygon is
  therefore not a circle with extra fields, and turning one into the other does not strip the rest.
- **What the VEAF runtime handles.** ``veafCombatZone.lua`` branches on exactly two zone types:
  ``0`` → ``mist.getUnitsInZones``, ``2`` → ``mist.getUnitsInPolygon(triggerZone.verticies)``. There
  is **no ``else``**, so a zone of any other type would silently contain no units — worse than not
  offering the shape. Hence the action writes only 0 and 2.

**David's call on the vertex count (2026-08-12)**: accept three or more, because "follow the ridge
line" is the actual use case and mist handles an arbitrary polygon — but **warn** whenever the count
is not four, since the DCS Mission Editor only draws quad zones and whether it preserves more is an
in-game question no unit test can settle.

Two refusals the ticket left open, decided here: a **dangling unit link** is refused rather than
warned (a zone linked to a unit that does not exist simply never follows anything, in silence), and a
**name collision** is refused (zones are referenced by name from ``mission.yaml``, so two of a name
makes every reference ambiguous).
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

from veaf_mission_mcp.mission_table import CATEGORIES, indexed, listed

#: DCS zone types. The VEAF runtime handles exactly these two, and nothing else.
_ZONE_CIRCULAR, _ZONE_POLYGON = 0, 2

#: DCS's own spelling of the vertex list. Not a typo to fix: renaming it writes a field DCS ignores.
_VERTICES_KEY = "verticies"

#: What the Mission Editor's quad-zone tool draws. More is legal for the runtime, not for its UI.
_EDITOR_VERTEX_COUNT = 4


def edit_zone(
    miz_path: Path,
    *,
    zone_name: str,
    new_name: str | None = None,
    position: dict[str, float] | None = None,
    radius: float | None = None,
    vertices: list[dict[str, float]] | None = None,
    make_circular: bool = False,
    link_unit: str | None = None,
    remove: bool = False,
) -> dict[str, Any]:
    """Edit one trigger zone in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        zone_name: The zone's **exact** current name.
        new_name: A new name. Refused on a collision; references do not follow, and the result says so.
        position: New centre, ``{"x": ..., "y": ...}``. A polygon's vertices travel with it.
        radius: New radius in metres; must be positive.
        vertices: Three or more ``{"x": ..., "y": ...}`` points, making the zone a polygon. A count
            other than four warns, since the editor only draws quads.
        make_circular: Turn a polygon back into a circle, dropping its vertices.
        link_unit: A unit name for the zone to follow (a carrier, typically). Empty string unlinks.
            A unit that does not exist is refused.
        remove: Delete the zone. Cannot be combined with any other change.

    Returns:
        ``{zone, changed, warnings}``.

    Raises:
        ValueError: If the archive is not a valid mission, the zone does not exist, nothing was
            given, `remove` is combined with another change, the new name collides, the radius is not
            positive, a vertex list is too short or malformed, or a linked unit does not exist.
    """
    changes = (new_name, position, radius, vertices, link_unit)
    if remove and (any(value is not None for value in changes) or make_circular):
        raise ValueError("remove cannot be combined with another change — delete or edit, not both")
    if not remove and not make_circular and all(value is None for value in changes):
        raise ValueError(
            "no change given — pass at least one of new_name, position, radius, vertices, "
            "make_circular, link_unit, remove"
        )

    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    zones = _zones_list(mission.mission_content)
    zone = _find_zone(zones, zone_name)

    changed: dict[str, Any] = {}
    warnings: list[str] = []

    if remove:
        zones.remove(zone)
        changed["removed"] = {"name": zone_name, "zone_id": zone.get("zoneId")}
        warnings.append(
            "a combat zone, a QRA or a mission.yaml entry may reference this zone by name; nothing "
            "here can see those references, so check what pointed at it"
        )
    else:
        if new_name is not None:
            _apply_rename(zone, zones, new_name, changed, warnings)
        if vertices is not None:
            _apply_vertices(zone, vertices, changed, warnings)
        if make_circular:
            _apply_circular(zone, changed)
        if position is not None:
            _apply_position(zone, position, changed)
        if radius is not None:
            _apply_radius(zone, radius, changed)
        if link_unit is not None:
            _apply_link(zone, mission.mission_content, link_unit, changed)

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"zone": new_name or zone_name, "changed": changed, "warnings": warnings}


def _zones_list(mission_content: dict[str, Any]) -> list[dict[str, Any]]:
    """Return ``triggers.zones`` as a list, normalising it in place so a caller can mutate it.

    Args:
        mission_content: The parsed ``mission`` table.

    Returns:
        The zone list.
    """
    triggers = mission_content.setdefault("triggers", {})
    zones = indexed(triggers.get("zones"))
    triggers["zones"] = zones
    return zones


def _find_zone(zones: list[dict[str, Any]], zone_name: str) -> dict[str, Any]:
    """Return the zone named `zone_name`, or raise naming the zones that exist.

    Args:
        zones: The mission's zones.
        zone_name: The exact name to find.

    Returns:
        The zone table.

    Raises:
        ValueError: If no zone carries that name.
    """
    for zone in zones:
        if isinstance(zone, dict) and str(zone.get("name", "")) == zone_name:
            return zone
    names = [str(zone.get("name", "")) for zone in zones if isinstance(zone, dict)]
    raise ValueError(f"No zone named {zone_name!r} in this mission. Zones present: {listed(names)}")


def _apply_rename(
    zone: dict[str, Any],
    zones: list[dict[str, Any]],
    new_name: str,
    changed: dict[str, Any],
    warnings: list[str],
) -> None:
    """Rename the zone, refusing a collision and warning that references do not follow.

    Args:
        zone: The zone to mutate.
        zones: Every zone, for the collision check.
        new_name: The proposed name.
        changed: The report to record the change in.
        warnings: The warning list.

    Raises:
        ValueError: If another zone already carries that name.
    """
    for other in zones:
        if other is not zone and isinstance(other, dict) and str(other.get("name", "")) == new_name:
            raise ValueError(
                f"a zone named {new_name!r} already exists — zones are referenced by name from "
                "mission.yaml, so two of a name makes every reference ambiguous"
            )
    changed["name"] = {"from": zone.get("name"), "to": new_name}
    zone["name"] = new_name
    warnings.append(
        "references to this zone do NOT follow the rename: a combat zone is wired by zone name in "
        "mission.yaml, and its member groups by a name prefix — both need updating by hand"
    )


def _apply_vertices(
    zone: dict[str, Any], vertices: list[dict[str, float]], changed: dict[str, Any], warnings: list[str]
) -> None:
    """Make the zone a polygon with `vertices`.

    Args:
        zone: The zone to mutate.
        vertices: The polygon's points.
        changed: The report to record the change in.
        warnings: The warning list, told when the count leaves what the editor draws.

    Raises:
        ValueError: If there are fewer than three points, or one lacks a coordinate.
    """
    if len(vertices) < 3:
        raise ValueError(
            f"a polygon zone needs at least three vertices, got {len(vertices)}: two points are a "
            "line, and mist.getUnitsInPolygon would contain nothing"
        )
    cleaned: list[dict[str, float]] = []
    for number, vertex in enumerate(vertices, start=1):
        if not isinstance(vertex, dict) or "x" not in vertex or "y" not in vertex:
            raise ValueError(f"vertex {number} must be an object with x and y, got {vertex!r}")
        cleaned.append({"x": float(vertex["x"]), "y": float(vertex["y"])})

    changed["type"] = {"from": zone.get("type"), "to": _ZONE_POLYGON}
    changed["vertices"] = {"from": len(indexed(zone.get(_VERTICES_KEY))), "to": len(cleaned)}
    zone["type"] = _ZONE_POLYGON
    zone[_VERTICES_KEY] = cleaned
    if len(cleaned) != _EDITOR_VERTEX_COUNT:
        warnings.append(
            f"{len(cleaned)} vertices: the VEAF runtime handles any polygon (mist.getUnitsInPolygon), "
            "but the DCS Mission Editor only draws 4-point quad zones — open the mission in the "
            "editor and save it once to confirm it keeps the shape"
        )


def _apply_circular(zone: dict[str, Any], changed: dict[str, Any]) -> None:
    """Turn a polygon back into a circle, dropping its vertices.

    Args:
        zone: The zone to mutate.
        changed: The report to record the change in.
    """
    changed["type"] = {"from": zone.get("type"), "to": _ZONE_CIRCULAR}
    zone["type"] = _ZONE_CIRCULAR
    zone.pop(_VERTICES_KEY, None)


def _apply_position(zone: dict[str, Any], position: dict[str, float], changed: dict[str, Any]) -> None:
    """Move the zone's centre, carrying a polygon's vertices by the same delta.

    Leaving the vertices behind would keep the shape where it was while the centre moved, so the zone
    would cover terrain nobody chose — the zone equivalent of the route shear in
    :mod:`veaf_mission_mcp.set_group_properties`.

    Args:
        zone: The zone to mutate.
        position: The new centre.
        changed: The report to record the change in.

    Raises:
        ValueError: If `position` lacks a coordinate.
    """
    if "x" not in position or "y" not in position:
        raise ValueError(f"position must carry x and y, got {position!r}")
    origin_x, origin_y = float(zone.get("x", 0.0)), float(zone.get("y", 0.0))
    target_x, target_y = float(position["x"]), float(position["y"])
    delta_x, delta_y = target_x - origin_x, target_y - origin_y

    changed["position"] = {
        "from": {"x": origin_x, "y": origin_y},
        "to": {"x": target_x, "y": target_y},
        "delta": {"x": delta_x, "y": delta_y},
    }
    zone["x"], zone["y"] = target_x, target_y
    existing = indexed(zone.get(_VERTICES_KEY))
    if existing:
        zone[_VERTICES_KEY] = [
            {"x": float(vertex["x"]) + delta_x, "y": float(vertex["y"]) + delta_y}
            for vertex in existing
            if isinstance(vertex, dict)
        ]


def _apply_radius(zone: dict[str, Any], radius: float, changed: dict[str, Any]) -> None:
    """Set the zone's radius.

    Args:
        zone: The zone to mutate.
        radius: The new radius, in metres.
        changed: The report to record the change in.

    Raises:
        ValueError: If `radius` is not positive.
    """
    if radius <= 0:
        raise ValueError(f"radius must be positive, got {radius}")
    changed["radius"] = {"from": zone.get("radius"), "to": radius}
    zone["radius"] = radius


def _apply_link(zone: dict[str, Any], mission_content: dict[str, Any], link_unit: str, changed: dict[str, Any]) -> None:
    """Link the zone to a unit so it follows it, or unlink it when given an empty name.

    DCS links by ``unitId``, not by name, so the id is resolved here. A **missing** unit is refused
    rather than warned: a zone linked to nothing simply never moves, in silence, and the mission maker
    would be left looking at the zone rather than at the link.

    Args:
        zone: The zone to mutate.
        mission_content: The parsed mission, to resolve the unit's id.
        link_unit: The unit's name, or ``""`` to unlink.
        changed: The report to record the change in.

    Raises:
        ValueError: If no unit carries that name.
    """
    if not link_unit:
        changed["link_unit"] = {"from": zone.get("linkUnit"), "to": None}
        zone.pop("linkUnit", None)
        return
    unit_id, names = _find_unit_id(mission_content, link_unit)
    if unit_id is None:
        raise ValueError(f"No unit named {link_unit!r} in this mission. Units present: {listed(names)}")
    changed["link_unit"] = {"from": zone.get("linkUnit"), "to": {"name": link_unit, "unit_id": unit_id}}
    zone["linkUnit"] = unit_id


def _find_unit_id(mission_content: dict[str, Any], unit_name: str) -> tuple[int | None, list[str]]:
    """Return the ``unitId`` of the unit named `unit_name`, and every unit name in the mission.

    Args:
        mission_content: The parsed ``mission`` table.
        unit_name: The exact unit name to find.

    Returns:
        ``(unit id or None, all unit names)``.
    """
    names: list[str] = []
    found: int | None = None
    for coalition in (mission_content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if not isinstance(group, dict):
                        continue
                    for unit in indexed(group.get("units")):
                        if not isinstance(unit, dict):
                            continue
                        name = str(unit.get("name", ""))
                        names.append(name)
                        if name == unit_name and unit.get("unitId") is not None:
                            found = int(unit["unitId"])
    return found, names
