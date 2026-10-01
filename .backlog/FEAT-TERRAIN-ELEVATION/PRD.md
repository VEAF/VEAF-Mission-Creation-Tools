# FEAT-TERRAIN-ELEVATION — a ground-elevation table per theatre, read with no DCS running

Status: 🔄 in-progress

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
| 01 | [Sweep + storage, measured on one theatre](tickets/01-sweep-and-storage.md) | ✅ |
| 02 | [Point, maximum per cell, profile, line of sight](tickets/02-queries.md) | ✅ |
| 03 | [The objective-mission prompt uses them](tickets/03-objective-prompt.md) | ✅ |
