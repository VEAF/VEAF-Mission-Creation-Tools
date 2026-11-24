# FEAT-TERRAIN-ELEVATION — a ground-elevation table per theatre, read with no DCS running

Status: ✅ done — merged 2026-10-01 (#1045) · archived 2026-11-24

Found writing the objective-mission prompt (FEAT-OBJECTIVE-MISSION-PROMPT, 2026-10-01): no action gives
the ground elevation, so a briefing's target altitudes, the floor of a low-level route and terrain
masking between a route and a SAM all end as "to check in game". David agreed (2026-10-01) to the
analysis below.

## Approach

The clear-ground catalogue's pattern (`veaf_libs/clear_ground_survey.py`): sweep a theatre once
through `dcs-serve`, in resumable batches, store the result per theatre under `veaf_libs/data/`, read it
offline. The probe here is `land.getHeight`, cheaper than the scenery probe and independent of the
units on the map.

**Store the elevation grid, derive the rest on demand** — as the catalogue stores probe answers and
derives clear radii. A table of maxima per cell answers only one of the needs:

| need | what it takes |
|---|---|
| a target's altitude in the briefing | the elevation **at the point** (a cell maximum is a wrong number) |
| the floor of a low-level route | the terrain along each segment |
| a minimum altitude per square, as on an aeronautical chart | the maximum per cell |
| whether a SAM sees the route | the terrain profile between two points |

## To measure before choosing

- **Resolution against size.** Estimate, not measured: ~10 M points per theatre at 250 m (several MB
  compressed), a few hundred kB at 1 km, like the clear-ground catalogues (250–300 kB). Sweep one theatre
  and measure before doing the others.
- **Terrain only.** `land.getHeight` ignores pylons and buildings; an aeronautical minimum altitude
  includes obstacles and a margin. Say "terrain only" on every figure, or add a stated margin.
- **Cell size** is a query parameter, not a storage choice: 30′ quadrangles (aeronautical charts, too
  coarse for low level) or 10 km MGRS squares (the F10 grid).
- DCS terrain is not a real-world DEM (SRTM): DCS's own must be swept. Reading its terrain files
  directly is believed impossible — to confirm.

## Tickets

| # | ticket | status |
|---|---|---|
| 01 | [Sweep + storage, measured on one theatre](FEAT-TERRAIN-ELEVATION.md) | ✅ |
| 02 | [Point, maximum per cell, profile, line of sight](FEAT-TERRAIN-ELEVATION.md) | ✅ |
| 03 | [The objective-mission prompt uses them](FEAT-TERRAIN-ELEVATION.md) | ✅ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a ground-elevation table per theatre, read with no DCS running.** Found writing the objective-mission prompt: no action gives target altitudes, a low-level route's floor or terrain masking. Sweep `land.getHeight` through dcs-serve like the clear-ground catalogue, store the grid, derive point elevation, maximum per cell and profiles on demand. Resolution to measure on one theatre first

## Tickets, in full

## 01 — `dcs terrain-sweep`: sweep a theatre's ground elevation, store the grid

Status: ✅ done

Files: `veaf_libs/terrain_survey.py` (new), `veaf_libs/terrain_elevation.py` (new),
`veaf_tools/commands/terrain.py` (new), the locales, `doc/CLI_REFERENCE*.md`.

The clear-ground sweep's flow (dcs-serve, empty survey mission, instructions, waiting, resumable
batches), with `land.getHeight` as the probe. The grid covers the whole theatre: its extent comes from
`--bounds`, else from the GUI's `Terrain.GetTerrainConfig('SW_bound' / 'NE_bound')` reached through
`net.dostring_in`, else from the airfields plus a margin, said so.

Storage: `<VEAF home>/terrain/<Theatre>.terrain`, swept on the workstation; **none shipped** (David,
2026-10-01: 5.5 MB a theatre, and a mission maker has DCS to sweep one in under three minutes). Binary — magic `VEAFTERR`, format version, a small JSON header (theatre, grid), then the
heights in whole metres as int16, row-delta encoded, lzma — reproducible byte for byte from the same
answers. First written as base64 in JSON; David: binary data written and read by Python only.

### Done when

- An interrupted sweep resumes at its first pending cell; a sweep of another plan is refused without
  `--restart`.
- `--measure-at x,y` sweeps a fine reference patch instead and reports, for each candidate spacing, the
  interpolation error at a point and how far a cell maximum falls below the true one.
- Measured on one theatre: resolution chosen on the report, file size, sweep time, what
  `land.getHeight` answers over the sea and outside the map. Recorded below.

### Measurements

Syria, 2026-10-01, on David's workstation (the theatre he chose, not Caucasus as first planned).

**Resolution** — `--measure-at` on three 20 km patches at 50 m: Mount Hermon (DCS 2797 m, real 2814),
Qurnat as Sawda (DCS 3076, real 3088), the Homs plain (428–678 m):

| spacing | at a point: 95 % / worst | a 10 km square's maximum too low: mean / worst |
|---|---|---|
| 100 m | 4 / 41 m | 2 / 10 m |
| **250 m** | **15 / 81 m** | **7 / 44 m** |
| 500 m | 39 / 147 m | 19 / 95 m |
| 1000 m | 78 / 227 m | 46 / 267 m |

250 m kept: 500 m misses a square's top by up to 95 m, too much for a low-level floor; 100 m gains some
30 m for six times the cells. The 250 m figures are quoted in every `terrain_elevation` answer.

**Extent** — DCS gave it: `net.dostring_in("gui", …)` from the mission works, `Terrain.GetTerrainConfig`
returns −460000,−400000 → 380000,500000. 3361 × 3601 = 12 102 961 cells.

**Time** — 2 min 31 s for the whole map, batches of 20 000.

**Size** — 9.1 MB in the first format (JSON, zlib, base64); 5.52 MB binary + lzma, read in 0.76 s.
Measured alternatives: zlib binary 7.0 MB; a 2-D predictor 5.2 MB (twice the encoding time, not kept);
rounding to 5 m 3.2 MB (lossy, not kept).

**Sea and depressions** — no height below 0 in 12.1 M points: the sea reads 0, and every point under
real sea level measured reads exactly 3 m (Tiberias, Jordan valley, Jericho, Dead Sea) — recorded as
`dcs-ground-is-never-below-sea-level`.

**Outside the map** — not measured: the grid stops at DCS's own extent.

## 02 — Elevation at a point, maximum per cell, profile and line of sight

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

### Done when

- One MCP action `terrain_elevation` (read-only) answers the four queries. No CLI query command: the
  prompt is the one consumer identified, and it goes through the MCP.
- MGRS squares checked against published conversions.

## 03 — The objective-mission prompt uses the elevation

Status: ✅ done

Files: `.prompts/new-objective-mission.fr.md`, `.prompts/new-objective-mission.en.md`.

The three places that say "no action gives the ground elevation" now call `terrain_elevation`: target
altitudes in the briefing, the floor of the TBA legs (height above the profile's maximum), and the
masking table between each route leg and each SAM. Where the theatre has no grid, the old wording stays:
an open point.
