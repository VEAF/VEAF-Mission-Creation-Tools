"""Find the map objects around a point, with the ids a combat zone's ``scenery_targets`` needs.

A combat zone completes when what it spawned is destroyed. A **map object** — a bridge, a building that
is part of the map itself — is not spawned by anybody, so a zone can only count it by id, against the
destroyed-scenery register (``veaf.isSceneryDestroyed``). Those ids exist only inside DCS: this module
asks a running mission for them, through ``dcs-serve``, with ``world.searchObjects`` over the scenery
category (FEAT-OBJECTIVE-MISSION-PROMPT).

**On the empty survey mission**, the one ``clear-ground-check`` uses: scenery does not depend on the
mission, and that mission is the transport a mission maker already has.

Each object comes back with the point it was found around, its id, its DCS type name, its position and
its distance to the point, nearest first: the id to write is the one whose type and distance match the
target — the building at the centre, not the shed next to it.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Runs a Lua chunk in the running mission and returns what it returned, as a string.
LuaExec = Callable[[str], str]

#: Default search radius, in metres: one site — a bridge and its approaches, a building and its yard —
#: and not the whole town around it.
DEFAULT_RADIUS_METERS = 150.0

# One line per object: point number, id, type name, x, z — tab-separated, since a type name may hold
# spaces. `getName` is the id, as a number: measured in game on 2026-08-28 (`veafMissionDb`), and it is
# the number the destroyed-scenery register keys on; an object whose name is not a number has no id the
# register could hold, and is left out. A point whose search raises answers `<point>\t!\t<error>`, so
# one bad point does not take the others' answers with it.
_LOOKUP_CHUNK_LUA = """
-- survey:scenery %(count)d
local pts = { %(points)s }
local out = {}
for i, p in ipairs(pts) do
  local searched, problem = pcall(function()
    local volume = {
      id = world.VolumeType.SPHERE,
      params = { point = { x = p.x, y = land.getHeight({ x = p.x, y = p.z }), z = p.z }, radius = p.r },
    }
    world.searchObjects(Object.Category.SCENERY, volume, function(object)
      local ok, line = pcall(function()
        local id = tonumber(object:getName())
        if not id then
          return nil
        end
        local at = object:getPoint()
        -- `%%.0f`, not `%%d`: Lua 5.1's `%%d` is a C int, and an id past 2^31 would wrap
        return string.format("%%d\\t%%.0f\\t%%s\\t%%.1f\\t%%.1f", i, id, tostring(object:getTypeName()), at.x, at.z)
      end)
      if ok and line then
        out[#out + 1] = line
      end
      return true
    end)
  end)
  if not searched then
    out[#out + 1] = string.format("%%d\\t!\\t%%s", i, tostring(problem):gsub("[\\t\\n]", " "))
  end
end
return table.concat(out, "\\n")
"""


class SceneryLookupError(RuntimeError):
    """DCS answered something that is not a list of scenery objects."""


@dataclass(frozen=True)
class SceneryObject:
    """One map object found around a point."""

    point: int
    id: int
    type_name: str
    x: float
    y: float
    distance: float

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict.

        Returns:
            The object's fields.
        """
        return {
            "point": self.point,
            "id": self.id,
            "type": self.type_name,
            "x": self.x,
            "y": self.y,
            "distance": self.distance,
        }


def parse_point(spec: str) -> tuple[float, float, float]:
    """Parse ``x,y`` or ``x,y,radius`` (mission coordinates, metres).

    Args:
        spec: The ``--around`` value.

    Returns:
        The point and its search radius.

    Raises:
        ValueError: If the value is not two or three numbers, or the radius is not positive.
    """
    parts = [part.strip() for part in spec.split(",")]
    if len(parts) not in (2, 3):
        raise ValueError(f"{spec!r}: expected x,y or x,y,radius (mission coordinates, metres)")
    try:
        numbers = [float(part) for part in parts]
    except ValueError as e:
        raise ValueError(f"{spec!r}: expected numbers, as x,y or x,y,radius") from e
    radius = numbers[2] if len(numbers) == 3 else DEFAULT_RADIUS_METERS
    if radius <= 0:
        raise ValueError(f"{spec!r}: the radius must be positive")
    return numbers[0], numbers[1], radius


def lookup_scenery(exec_lua: LuaExec, points: list[tuple[float, float, float]]) -> list[SceneryObject]:
    """List the map objects around each point, nearest first within each point.

    Args:
        exec_lua: The transport, to a running mission on the right theatre.
        points: ``(x, y, radius)`` in mission coordinates (``x`` north, ``y`` east), metres.

    Returns:
        Every object found, sorted by point then distance.

    Raises:
        SceneryLookupError: If an answer line is not an object.
    """
    # mission `y` is DCS `z`: the chunk is written in DCS axes
    lua_points = ", ".join(f"{{ x = {float(x)!r}, z = {float(y)!r}, r = {float(r)!r} }}" for x, y, r in points)
    answer = exec_lua(_LOOKUP_CHUNK_LUA % {"count": len(points), "points": lua_points})
    found: list[SceneryObject] = []
    for line in filter(None, answer.splitlines()):
        fields = line.split("\t")
        if len(fields) == 3 and fields[1] == "!":
            # one point's search raised in DCS: say so, and keep the other points' answers
            logger.warning(t("cmd.scenery_objects.point_failed", point=fields[0], error=fields[2]))
            continue
        try:
            index, object_id, type_name, x, y = (
                int(fields[0]),
                int(float(fields[1])),
                fields[2],
                float(fields[3]),
                float(fields[4]),
            )
        except (IndexError, ValueError) as e:
            raise SceneryLookupError(f"unexpected scenery answer: {line[:80]!r}") from e
        px, py, _radius = points[index - 1]
        found.append(SceneryObject(index, object_id, type_name, x, y, round(math.hypot(x - px, y - py), 1)))
    return sorted(found, key=lambda o: (o.point, o.distance))


def offer_lookup(theatre: str, points: list[tuple[float, float, float]]) -> dict[str, Any]:
    """What finding the map objects around some points would take — an offer, nothing launched.

    Args:
        theatre: The theatre, as DCS spells it.
        points: ``(x, y, radius)`` in mission coordinates, metres.

    Returns:
        The command to run, and what it needs.
    """
    around = " ".join(f"--around {float(x)!r},{float(y)!r},{float(r)!r}" for x, y, r in points)
    return {
        "launched": False,
        "offer": (
            f"To use a map object (a bridge, a building of the map) as an objective, I need its DCS id. The "
            f"command below needs DCS and {theatre}: it writes an empty survey mission, tells you what to do "
            "in DCS, lists the map objects around each point with their id, type and distance, and says "
            "when DCS can be closed. Nothing runs until you say so."
        ),
        "command": f".\\veaf-tools.exe dcs scenery-objects {theatre} {around}",
        "theatre": theatre,
        "points": len(points),
    }
