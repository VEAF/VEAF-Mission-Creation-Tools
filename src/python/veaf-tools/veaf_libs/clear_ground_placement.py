"""Put a group the tools place on ground measured clear, and say what was done (FEAT-CLEAR-GROUND-AT-AUTHORING 04).

The rule, David's arbitration of 2026-09-26: **a position the tools chose is the tools'
responsibility**, and a group they put in a wood is a defect of theirs; **a position the mission maker
drew stays where they drew it**. The caller decides which of the two it holds (``keep_position``);
this module only serves the first.

It never refuses a placement (ADR 0018). When the catalogue does not cover the place, or covers it and
holds nothing large enough, or the group's size is only known at runtime, the group stays where it was
asked to go and the message says so, in terms a mission maker can act on.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from veaf_libs.clear_ground_catalogue import (
    PLACEMENT_MARGIN_METERS,
    ClearGroundStatus,
    catalogue_for_theatre,
    find_clear_positions,
)
from veaf_libs.group_footprint import marker_footprint

#: How far from the asked position a group may be moved. One kilometre: far enough to leave a wood a
#: battery was dropped into, near enough that the group still guards what it was put next to.
SEARCH_RADIUS_METERS = 1000.0


@dataclass(frozen=True)
class Placement:
    """Where a group goes, and what to tell the user about it.

    Args:
        dx: Translation to apply along mission ``x``, in metres (0 when the group stays).
        dy: Translation along mission ``y``.
        message: What happened, when there is something to say; ``None`` when the asked position was
            already clear.
    """

    dx: float
    dy: float
    message: str | None


def _footprint(units: list[dict[str, Any]], coalition: str) -> tuple[float, float, float | None, str]:
    """Centre, required radius and a label for a group's units.

    Args:
        units: The group's units, with mission ``x``/``y`` and ``name``.
        coalition: Their side.

    Returns:
        ``(x, y, radius, label)``; the radius is ``None`` when a marker's size is unknown, and the
        label then says why.
    """
    cx = sum(float(u["x"]) for u in units) / len(units)
    cy = sum(float(u["y"]) for u in units) / len(units)
    required = 0.0
    labels = []
    for unit in units:
        reach = math.hypot(float(unit["x"]) - cx, float(unit["y"]) - cy)
        marker = marker_footprint(str(unit.get("name", "")), coalition=coalition)
        if marker is None:
            required = max(required, reach)
            continue
        if marker.radius is None:
            return cx, cy, None, f"'{marker.what}' ({marker.reason})"
        required = max(required, reach + marker.radius)
        labels.append(f"'{marker.what}'")
    what = ", ".join(labels) if labels else f"{len(units)} vehicle{'s' if len(units) > 1 else ''}"
    return cx, cy, required, what


def occupied_by(mission_content: dict[str, Any]) -> list[tuple[float, float, float]]:
    """Where a mission already has ground units: ``(x, y, radius)`` each, a marker's footprint included.

    The catalogue knows the scenery and nothing else, so without this two groups asked into the same
    wood are moved onto the same clearing and spawn into each other.

    Args:
        mission_content: The parsed ``mission`` table.

    Returns:
        One entry per vehicle or static unit; the radius is 0 for a plain unit, the worst-case footprint
        of the group a ``#command`` marker spawns (0 when that size is unknown).
    """

    def values(table: Any) -> list[Any]:
        return list(table.values()) if isinstance(table, dict) else list(table or [])

    found: list[tuple[float, float, float]] = []
    for side_name, side in (mission_content.get("coalition") or {}).items():
        for country in values(side.get("country") if isinstance(side, dict) else None):
            for category in ("vehicle", "static"):
                for group in values((country.get(category) or {}).get("group")):
                    for unit in values(group.get("units")):
                        marker = marker_footprint(str(unit.get("name", "")), coalition=str(side_name))
                        radius = marker.radius if marker is not None and marker.radius is not None else 0.0
                        found.append((float(unit["x"]), float(unit["y"]), radius))
    return found


def place_on_clear_ground(
    theatre: str | None,
    units: list[dict[str, Any]],
    *,
    coalition: str,
    occupied: list[tuple[float, float, float]] | None = None,
) -> Placement:
    """Decide where a stationary ground group goes, given where its units were asked to stand.

    Args:
        theatre: The mission's theatre.
        units: The group's units, each with mission ``x``/``y`` and its ``name``.
        coalition: The group's side, which decides the batteries a random SAM marker may draw.
        occupied: Ground the mission already uses (:func:`occupied_by`); a position whose footprint
            reaches any of it is not offered.

    Returns:
        The translation to apply to the whole group, and what to say about it.
    """
    if not units or not theatre:
        return Placement(0.0, 0.0, None)
    cx, cy, required, what = _footprint(units, coalition)
    if required is None:
        return Placement(
            0.0,
            0.0,
            f"the size of {what} is only known when it spawns, so it was placed as requested; "
            "the runtime moves it off scenery then",
        )
    answer = find_clear_positions(
        catalogue_for_theatre(theatre),
        cx,
        cy,
        search_radius=SEARCH_RADIUS_METERS,
        required_radius=required,
        limit=None,
    )
    if answer.status is ClearGroundStatus.NOT_COVERED:
        return Placement(
            0.0,
            0.0,
            f"no clear-ground catalogue covers this place on {theatre}, so it was placed as requested; "
            f"sweep it with 'veaf-tools dcs clear-ground-sweep {theatre} --around {cx:.0f},{cy:.0f}'",
        )
    if answer.status is ClearGroundStatus.NONE_LARGE_ENOUGH:
        return Placement(
            0.0,
            0.0,
            f"no clear position for {what} ({required:.0f} m of clear ground needed) within "
            f"{SEARCH_RADIUS_METERS:.0f} m, placed as requested",
        )
    taken = occupied or []
    best = next(
        (
            candidate
            for candidate in answer.candidates
            if all(
                math.hypot(candidate.x - ox, candidate.y - oy) >= required + orad + PLACEMENT_MARGIN_METERS
                for ox, oy, orad in taken
            )
        ),
        None,
    )
    if best is None:
        return Placement(
            0.0,
            0.0,
            f"no clear position for {what} ({required:.0f} m of clear ground needed) within "
            f"{SEARCH_RADIUS_METERS:.0f} m that the mission's other ground units leave free, placed as requested",
        )
    # A candidate on a cell next to the asked point — diagonals included — is the asked point: the grid
    # cannot tell them apart, and moving a group by one cell would only be noise. Seen on GermanyCW
    # (combatZone_Borkenberge_Hard, 2026-09-28): "moved 25 m" for a battery whose centre probed clear.
    if best.distance <= best.spacing * math.sqrt(2) + 1e-6:
        return Placement(0.0, 0.0, None)
    return Placement(
        best.x - cx,
        best.y - cy,
        f"moved {best.distance:.0f} m onto clear ground: {required:.0f} m of clear ground needed for {what}, "
        f"and the asked position has less (clear-ground catalogue of {theatre})",
    )


def translate_group(group: dict[str, Any], dx: float, dy: float) -> None:
    """Move a mission-table group, its units and its route points, rigidly, in place.

    Args:
        group: The group, as built for the mission table.
        dx: Translation along mission ``x``, in metres.
        dy: Translation along mission ``y``, in metres.
    """
    if not dx and not dy:
        return
    group["x"] = float(group["x"]) + dx
    group["y"] = float(group["y"]) + dy
    for unit in group.get("units") or []:
        unit["x"] = float(unit["x"]) + dx
        unit["y"] = float(unit["y"]) + dy
    for point in (group.get("route") or {}).get("points") or []:
        point["x"] = float(point["x"]) + dx
        point["y"] = float(point["y"]) + dy
