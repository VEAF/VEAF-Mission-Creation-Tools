# 02 — Elevation at a point, maximum per cell, profile and line of sight

Status: ✅ done

Files: `veaf_libs/terrain_elevation.py`, `veaf_libs/mgrs.py` (new), `veaf_tools/commands/terrain.py`,
`veaf_mission_mcp/actions.py`, the locales, `doc/CLI_REFERENCE*.md`,
`doc/developer/mission-editing-mcp*.md`.

Offline, on the stored grid:

- **elevation at a point**: bilinear between the four surrounding samples, metres and feet;
- **maximum per cell**: over an area, per 10 km MGRS square (the F10 grid) or 30′ quadrangle, with the
  position of the highest sample;
- **profile**: along a route (two points or more), the terrain every half spacing, its maximum per leg;
- **line of sight**: from an observer at a height above the ground to a target at an altitude, with the
  4/3-Earth radar horizon, the first sample that masks it.

Every answer says "terrain only" (no buildings, pylons or trees) and the grid spacing; a point outside
the grid is "not covered", never 0.

## Done when

- One MCP action `terrain_elevation` (read-only) answers the four queries. No CLI query command: the
  prompt is the one consumer identified, and it goes through the MCP.
- MGRS squares checked against published conversions.
