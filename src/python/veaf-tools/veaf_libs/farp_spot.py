"""Find, in DCS, a flat spot clear of trees and buildings for a FARP near a point (FIX-FARP-PLACEMENT 03).

On a theatre with no clear-ground catalogue and no elevation grid (MarianaIslands, 2026-10-12), the only
way to find a usable FARP spot was a probe written for the mission
(``VEAF-Open-Training-Mission-Marianas-v6/tools/find_farp_spot.py``); it found the one spot within
1.2 km of Merizo, where the FARP was then moved. This module is that probe, made a tool.

For each point of a 50 m grid within the radius, DCS is asked:

- the surface type, which must be ground (``land.SurfaceType.LAND``, 1);
- the small ``Disposition.getSimpleZones`` query — a free 5 m spot within 20 m — at the point and at 8
  points 40 m around it; it is the only reliable use of that call (known limitation
  ``disposition-getsimplezones-is-a-lottery``);
- ``land.getHeight`` at those 9 points, whose range must not exceed the maximum drop.

**On the empty survey mission**, the one ``clear-ground-check`` uses: the Disposition query counts
vehicles as obstacles, so a mission holding units would hide spots under them.

The grid is sent in bands of rows: a radius of 1.2 km is some 1 800 points and up to 16 000 Disposition
queries, more than one call of the bridge may take.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

#: Runs a Lua chunk in the running mission and returns what it returned, as a string.
LuaExec = Callable[[str], str]

DEFAULT_RADIUS_METERS = 1200.0
#: The spot accepted for FARP Merizo on the Marianas reads 2.5 m over 80 m.
DEFAULT_MAX_DROP_METERS = 3.0
#: Distance between two points tried.
GRID_STEP_METERS = 50
#: The ring around a point that must be clear and flat too: a four-pad FARP's reach.
RING_METERS = 40
#: Width of a band of the grid sent in one call: the Marianas probe's, which stayed under the timeout.
BAND_METERS = 300

# One line per spot: x, z, height range — tab-separated. A band that raises answers `!\t<error>`.
_BAND_CHUNK_LUA = """
-- survey:farp-spot
local cx, cz = %(x)d, %(z)d
local radius, step, ring, maxdrop = %(radius)d, %(step)d, %(ring)d, %(max_drop)r
local dzmin, dzmax = %(dz_min)d, %(dz_max)d
local out = {}
local function free(x, z)
  if land.getSurfaceType({ x = x, y = z }) ~= land.SurfaceType.LAND then
    return false
  end
  local p = { x = x, y = land.getHeight({ x = x, y = z }), z = z }
  local ok, c = pcall(Disposition.getSimpleZones, p, 20, 5, 10)
  return ok and type(c) == "table" and #c > 0
end
local done, problem = pcall(function()
  for dx = -radius, radius, step do
    for dz = dzmin, dzmax, step do
      local x, z = cx + dx, cz + dz
      if dx * dx + dz * dz <= radius * radius and free(x, z) then
        local h = land.getHeight({ x = x, y = z })
        local hmin, hmax, ok = h, h, true
        for k = 0, 7 do
          local a = math.pi * k / 4
          local px, pz = x + ring * math.cos(a), z + ring * math.sin(a)
          if not free(px, pz) then
            ok = false
            break
          end
          local ph = land.getHeight({ x = px, y = pz })
          hmin, hmax = math.min(hmin, ph), math.max(hmax, ph)
        end
        if ok and hmax - hmin <= maxdrop then
          out[#out + 1] = string.format("%%.0f\\t%%.0f\\t%%.1f", x, z, hmax - hmin)
        end
      end
    end
  end
end)
if not done then
  return "!\\t" .. tostring(problem):gsub("[\\t\\n]", " ")
end
return table.concat(out, "\\n")
"""


class FarpSpotError(RuntimeError):
    """DCS raised while searching, or answered something that is not a list of spots."""


@dataclass(frozen=True)
class FarpSpot:
    """A flat, clear spot found for a FARP, in mission coordinates."""

    x: float
    y: float
    drop: float
    distance: float

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict.

        Returns:
            The spot's fields.
        """
        return {"x": self.x, "y": self.y, "drop": self.drop, "distance": self.distance}


def parse_point(spec: str) -> tuple[float, float]:
    """Parse ``x,y`` (mission coordinates, metres).

    Args:
        spec: The ``--at`` value.

    Returns:
        The point.

    Raises:
        ValueError: If the value is not two numbers.
    """
    parts = spec.split(",")
    try:
        if len(parts) != 2:
            raise ValueError(spec)
        return float(parts[0]), float(parts[1])
    except ValueError as e:
        raise ValueError(f"{spec!r}: expected x,y (mission coordinates, metres)") from e


def band_chunk(x: float, y: float, *, radius: float, max_drop: float, dz_min: int, dz_max: int) -> str:
    """Return the Lua chunk searching one band of the grid.

    Args:
        x: Mission ``x`` (north) of the centre.
        y: Mission ``y`` (east) of the centre — DCS ``z``.
        radius: The search radius, metres.
        max_drop: The largest height range accepted over a spot, metres.
        dz_min: First east offset of the band, metres.
        dz_max: Last east offset of the band, metres.

    Returns:
        The chunk.
    """
    return _BAND_CHUNK_LUA % {
        "x": round(x),
        "z": round(y),
        "radius": round(radius),
        "step": GRID_STEP_METERS,
        "ring": RING_METERS,
        "max_drop": float(max_drop),
        "dz_min": dz_min,
        "dz_max": dz_max,
    }


def find_farp_spots(
    exec_lua: LuaExec,
    x: float,
    y: float,
    *,
    radius: float = DEFAULT_RADIUS_METERS,
    max_drop: float = DEFAULT_MAX_DROP_METERS,
    on_band: Callable[[int, int], None] | None = None,
) -> list[FarpSpot]:
    """List the flat, clear spots within *radius* of a point, nearest first.

    Args:
        exec_lua: The transport, to the running survey mission on the right theatre.
        x: Mission ``x`` (north) of the point.
        y: Mission ``y`` (east) of the point.
        radius: How far to search, metres.
        max_drop: The largest height range accepted over a spot (its centre and the 40 m ring), metres.
        on_band: Called after each band with ``(bands done, bands in all)``.

    Returns:
        The spots found.

    Raises:
        FarpSpotError: If a band raised in DCS, or an answer line is not a spot.
    """
    r = round(radius)
    starts = list(range(-r, r + 1, BAND_METERS))
    spots: list[FarpSpot] = []
    for done, dz_min in enumerate(starts, start=1):
        dz_max = min(dz_min + BAND_METERS - GRID_STEP_METERS, r)
        answer = exec_lua(band_chunk(x, y, radius=r, max_drop=max_drop, dz_min=dz_min, dz_max=dz_max))
        for line in filter(None, answer.splitlines()):
            fields = line.split("\t")
            if fields[0] == "!":
                raise FarpSpotError(f"the search raised in DCS: {fields[-1]}")
            try:
                sx, sy, drop = float(fields[0]), float(fields[1]), float(fields[2])
            except (IndexError, ValueError) as e:
                raise FarpSpotError(f"unexpected farp-spot answer: {line[:80]!r}") from e
            spots.append(FarpSpot(sx, sy, drop, round(math.hypot(sx - x, sy - y), 1)))
        if on_band:
            on_band(done, len(starts))
    return sorted(spots, key=lambda s: (s.distance, s.drop))
