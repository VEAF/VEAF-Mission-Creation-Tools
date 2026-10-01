# 01 — `dcs terrain-sweep`: sweep a theatre's ground elevation, store the grid

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

## Done when

- An interrupted sweep resumes at its first pending cell; a sweep of another plan is refused without
  `--restart`.
- `--measure-at x,y` sweeps a fine reference patch instead and reports, for each candidate spacing, the
  interpolation error at a point and how far a cell maximum falls below the true one.
- Measured on one theatre: resolution chosen on the report, file size, sweep time, what
  `land.getHeight` answers over the sea and outside the map. Recorded below.

## Measurements

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
