"""The worst-case footprint of a group, computed before it exists (FEAT-CLEAR-GROUND-AT-AUTHORING 04).

To put a group on ground measured clear, the tools must know how much ground it takes. For a group
written unit by unit that is its own extent. For a combat-zone **marker** — a unit named
``#command="-sa10"`` — the real group is drawn at runtime by ``veafUnits.placeGroup``, and this module
computes the largest footprint that draw can produce, from the same data the runtime reads.

**Why it can be computed at all.** ``placeGroup`` sizes every cell of a group's grid from the unit's
``size`` in ``veaf-units.yaml`` or, failing that, ``veafUnits.DefaultCellWidth``/``Height`` (10 m),
times ``1 + spacing``. It never reads a unit's real dimensions: the block that read ``desc.box`` is
commented out (``veafUnits.lua``, ``processUnit``). So the grid's extent is a function of the group
definition and the command's ``spacing`` alone; what is random is only where a unit stands inside its
cell, and which cell a unit without one gets — both bounded here by taking the worst case.

**What cannot be computed.** ``armorgroup``, ``infantrygroup``, ``transportgroup``, ``combatgroup``
and ``convoy`` assemble their group in Lua from dice rolls; their size is left unknown, and the caller
leaves such a marker to the runtime's ``settleGroup``, saying so.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from functools import cache
from typing import Any

#: ``veafUnits.DefaultCellWidth`` / ``DefaultCellHeight``.
DEFAULT_CELL_METERS = 10.0
#: ``veafCombatZone.DefaultSpawnRadiusForUnits``: how far from its marker a zone element may spawn.
DEFAULT_ZONE_SPAWN_RADIUS = 50.0
#: ``veafSpawn`` seeds ``spacing 5`` for every ``_spawn`` kind that places a group
#: (``veafSpawnParser.lua``, ``CommandDescriptors``).
DEFAULT_SPAWN_SPACING = 5.0

#: ``veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS``, every side and era together: the batteries
#: ``-samVLR`` draws from. Copied, and held to the Lua table by a test that reads it.
LONG_RANGE_AIR_DEFENSE_GROUPS: tuple[str, ...] = (
    "patriot",
    "hawk",
    "generateAirDefenseGroup-BLUE-WW2-5",
    "sa10",
    "sa5",
    "sa2",
    "generateAirDefenseGroup-RED-WW2-5",
)

#: ``_spawn`` kinds whose group is assembled from dice rolls in Lua: no definition to measure.
_DYNAMIC_KINDS = frozenset({"armorgroup", "infantrygroup", "transportgroup", "combatgroup", "convoy"})

_TAG_COMMAND = re.compile(r'#command\s*=\s*"([^"]+)"', re.IGNORECASE)
#: `veafInterpreter.Starter` / `Trailer`, which the runtime matches case-sensitively.
_TAG_INTERPRETER = re.compile(r'#veafInterpreter\["(.+?)"\]')
_TAG_SPAWN_RADIUS = re.compile(r"#spawnradius\s*=\s*([\d\-]+)", re.IGNORECASE)


@dataclass(frozen=True)
class Footprint:
    """How much ground a group needs, or why that is not known.

    Args:
        radius: Worst-case distance from the group's centre to any of its units, in metres, spawn
            scatter included; ``None`` when unknown.
        what: What was measured, for a message (``"-sa10"``, ``"4 units"``).
        reason: Why ``radius`` is unknown, for a message.
    """

    radius: float | None
    what: str
    reason: str = ""


def grid_radius(group: dict[str, Any], spacing: float) -> float:
    """Worst-case radius of a group drawn by ``veafUnits.placeGroup`` (not a convoy).

    Every column is as wide, and every row as tall, as the largest cell that may land in it: the cell
    of a unit fixed there, or of any unit without a fixed cell, since those go anywhere. A unit then
    stands anywhere inside its cell, so the bound is the half-diagonal of the whole grid — which a
    heading does not change — plus the ``random`` scatter.

    Args:
        group: A group definition from ``veaf-units.yaml``.
        spacing: The spawn command's ``spacing``.

    Returns:
        The radius, in metres.
    """
    units = [u if isinstance(u, dict) else {"type": u} for u in group.get("units") or []]
    count = 0
    for unit in units:
        number = unit.get("number", 1)
        count += int(number["max"]) if isinstance(number, dict) else int(number)
    disposition = group.get("disposition")
    if disposition:
        rows, cols = int(disposition["h"]), int(disposition["w"])
    else:
        side = math.ceil(math.sqrt(max(1, count)))
        rows = cols = side

    def cell_size(unit: dict[str, Any]) -> tuple[float, float]:
        size = unit.get("size")
        if isinstance(size, dict):
            width, height = float(size["width"]), float(size["height"])
        elif size is not None:
            width = height = float(size)
        else:
            width = height = DEFAULT_CELL_METERS
        width, height = width * (1 + spacing), height * (1 + spacing)
        if not unit.get("fitToUnit"):
            width = height = max(width, height)
        return width, height

    # A column or row no unit lands in is **zero** wide in `placeGroup` — the grid shrinks to the
    # cells actually occupied. So a unit without a fixed cell adds at most its own size, whether it
    # widens a column already occupied or opens a new one: the bound adds one cell per such unit to
    # the occupied columns and rows, and never exceeds the whole grid.
    col_widths: dict[int, float] = {}
    row_heights: dict[int, float] = {}
    free: list[tuple[float, float]] = []
    for unit in units:
        number = unit.get("number", 1)
        copies = int(number["max"]) if isinstance(number, dict) else int(number)
        if "cell" not in unit:
            free += [cell_size(unit)] * copies
            continue
        row, col = divmod(int(unit["cell"]) - 1, cols)
        width, height = cell_size(unit)
        col_widths[col] = max(col_widths.get(col, 0.0), width)
        row_heights[row] = max(row_heights.get(row, 0.0), height)
    free_width = max((w for w, _ in free), default=0.0)
    free_height = max((h for _, h in free), default=0.0)
    widest = max([free_width, *col_widths.values()])
    tallest = max([free_height, *row_heights.values()])
    total_width = min(sum(col_widths.values()) + len(free) * free_width, cols * widest)
    total_height = min(sum(row_heights.values()) + len(free) * free_height, rows * tallest)

    radius = math.hypot(total_width / 2, total_height / 2)
    if any(u.get("random") for u in units) and spacing > 0:
        # `math.random(-((spacing - 1) * DefaultCellWidth) / 2, ...)` along each axis.
        scatter = abs(spacing - 1) * DEFAULT_CELL_METERS / 2
        radius += math.hypot(scatter, scatter)
    return radius


@cache
def _groups_by_alias() -> dict[str, dict[str, Any]]:
    from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data  # noqa: PLC0415

    groups: dict[str, dict[str, Any]] = {}
    for group in load_framework_spawn_data()["groups"]:
        for alias in group.get("aliases") or []:
            groups[str(alias).lower()] = group
    return groups


@cache
def _shortcuts() -> dict[str, dict[str, Any]]:
    from veaf_libs.veaf_shortcuts_scanner import get_shortcuts  # noqa: PLC0415

    return {alias.lower(): dict(entry) for entry in get_shortcuts() for alias in entry["aliases"]}


def _options(command: str) -> tuple[str, dict[str, str]]:
    """Split ``_spawn group, name sa10, spacing 1`` into its kind and its options."""
    head, *rest = [part.strip() for part in command.split(",")]
    words = head.split()
    kind = words[1].lower() if len(words) > 1 else ""
    options: dict[str, str] = {}
    for part in rest:
        if not part:
            continue
        key, _, value = part.partition(" ")
        options[key.lower()] = value.strip()
    return kind, options


def _number(value: str, default: float) -> float:
    """Read ``200`` or ``100-300`` (worst case: the upper bound)."""
    numbers = [float(n) for n in re.findall(r"\d+(?:\.\d+)?", value or "")]
    return max(numbers) if numbers else default


def command_footprint(command: str, *, coalition: str = "red") -> Footprint:
    """The worst-case footprint of the group a marker command spawns.

    Args:
        command: The ``#command`` value — a shortcut (``-sa10``, ``-samLR, spacing 3``) or a raw
            ``_spawn`` command.
        coalition: The marker's side, which decides the batteries ``samgroup`` draws from.

    Returns:
        The footprint, spawn radius of the command included; ``radius`` is ``None`` when the command
        builds its group from dice rolls, or is not a spawn at all.
    """
    text = command.strip()
    shortcut_name, _, remainder = text.partition(",")
    shortcut = _shortcuts().get(shortcut_name.strip().lower()) if text.startswith("-") else None
    random_ranges: dict[str, Any] = {}
    if shortcut is not None:
        random_ranges = shortcut.get("randomParameters") or {}
        text = shortcut.get("veafCommand", "") + ("," + remainder if remainder else "")
    kind, options = _options(text)
    if not text.lower().startswith("_spawn") or not kind:
        return Footprint(None, command, "it is not a _spawn command")
    if kind in _DYNAMIC_KINDS:
        return Footprint(None, command, f"a '{kind}' group is assembled at runtime, its size is not known in advance")
    # A destination makes `placeGroup` lay the units in one column instead of the group's grid
    # (`hasDest = options.destination ~= nil`), and the group drives away anyway. `isconvoy` does not:
    # it sets `options.convoy`, which the layout never reads.
    if {"dest", "destination"} & options.keys():
        return Footprint(None, command, "it is a convoy, laid out in a column and meant to move")
    spacing = _number(options.get("spacing", ""), DEFAULT_SPAWN_SPACING)
    scatter = _number(options.get("radius", ""), 0.0)
    if kind == "unit":
        return Footprint(scatter, command)

    groups = _groups_by_alias()
    if kind == "group":
        candidates = [groups.get(options.get("name", "").lower())]
    elif kind == "longrangesam":
        candidates = [groups.get(alias.lower()) for alias in LONG_RANGE_AIR_DEFENSE_GROUPS]
    elif kind == "samgroup":
        # `generateAirDefenseGroup` rolls the asked defense one level up or down, and tries the
        # era-specific definition first: every level in reach and every era, for the marker's side.
        side = "BLUE" if coalition.lower() == "blue" else "RED"
        defense = random_ranges.get("defense")
        asked = options.get("defense")
        if asked:
            low = high = int(_number(asked, 3))
        elif defense:
            low, high = int(defense["min"]), int(defense["max"])
        else:
            low, high = 1, 5
        levels = {str(level) for level in range(low - 1, high + 2)}
        prefix = f"generateairdefensegroup-{side.lower()}-"
        candidates = [
            g for alias, g in groups.items() if alias.startswith(prefix) and alias.rsplit("-", 1)[-1] in levels
        ]
    else:
        return Footprint(None, command, f"'{kind}' is not a ground group spawn")
    known = [g for g in candidates if g]
    if not known:
        return Footprint(None, command, "the group it names is not in veaf-units.yaml")
    return Footprint(max(grid_radius(g, spacing) for g in known) + scatter, command)


def marker_footprint(unit_name: str, *, coalition: str = "red") -> Footprint | None:
    """The footprint a combat-zone marker unit stands for, or ``None`` when the name is no marker.

    The zone element's own spawn radius — ``#spawnradius``, or
    :data:`DEFAULT_ZONE_SPAWN_RADIUS` — is added: the group may appear that far from its marker.

    Args:
        unit_name: The unit's name, as written in the mission.
        coalition: The unit's side.

    A ``#veafInterpreter["…"]`` unit is sized from its command too, with no zone scatter: the command
    runs at the unit's own position; when that size cannot be known it stays a plain vehicle. It used to count as one vehicle, so the demo mission's SA-11 site
    was given « 0 m of clear ground » (FIX-DEMO-MISSION-FINDINGS ticket 07).

    Returns:
        The footprint, or ``None`` when the unit carries neither ``#command`` nor ``#veafInterpreter``.
    """
    match = _TAG_COMMAND.search(unit_name)
    if not match:
        interpreted = _TAG_INTERPRETER.search(unit_name)
        if not interpreted:
            return None
        footprint = command_footprint(interpreted.group(1), coalition=coalition)
        # A size that cannot be known keeps the unit a plain vehicle, as before: an interpreter unit
        # often runs no spawn at all (`-destroy`, a TACAN), and placement must not refuse the group.
        return footprint if footprint.radius is not None else None
    footprint = command_footprint(match.group(1), coalition=coalition)
    if footprint.radius is None:
        return footprint
    radius_tag = _TAG_SPAWN_RADIUS.search(unit_name)
    zone_scatter = _number(radius_tag.group(1), DEFAULT_ZONE_SPAWN_RADIUS) if radius_tag else DEFAULT_ZONE_SPAWN_RADIUS
    return Footprint(footprint.radius + zone_scatter, footprint.what)
