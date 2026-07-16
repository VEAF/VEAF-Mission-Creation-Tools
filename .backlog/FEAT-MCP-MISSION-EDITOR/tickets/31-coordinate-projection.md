# FEAT-MCP-MISSION-EDITOR-031 — Coordinate projection foundation (port) + ADR 0015

Status: ⬜ ready
Type: feat
Files: `docs/adr/0015-coordinate-projection-port.md`, `src/python/veaf-tools/veaf_libs/coordinates.py`, `test/python/veaf_libs/test_coordinates.py`

## Problem

Placement actions take **DCS local coordinates** (`x`/`y`, metres in the theatre's own projection).
Makers think in lat/long off a map. The DCS `coord.*` conversions live in the **in-game Lua
runtime** and are unavailable design-time; the repo has no Python projection.

## Decision — copy the existing implementation into Python

Copy the tested implementation from Dup's plugin (no shared upstream, no drift-tracking):

- Source: `d:\dev\_dcs-other\bfr-claude-plugins\plugins\dcs-mission-tools\tools\src\lib\projection.lua`
  (**MIT**; original BFR code). VEAF is Apache-2.0 — MIT-compatible; keep a short attribution header.
- It carries the hard part: WGS84 Transverse Mercator forward/inverse **plus per-theatre tables**
  (`lon0`, `x0`, `y0`) for **caucasus, syria, persiangulf, marianaislands**.
- Its test file ships **5 reference cases** `(theatre, x, y, lat, lon)` with tolerances (5e-6° on
  lat/lon, 0.5 m round-trip) — reused verbatim as our Python fixtures.

## What to build

- `veaf_libs/coordinates.py`: straight Python copy — `latlon_to_xy(theatre, lat, lon)` /
  `xy_to_latlon(theatre, x, y)`, the theatre table, unsupported-theatre error (names the theatre,
  case-insensitive), matching the Lua behaviour. Short attribution header crediting
  `bfr-claude-plugins` (MIT).
- ADR 0015: the copy decision, provenance (repo + path + commit), supported theatres, tolerances.

## Acceptance criteria

- [ ] The 5 reference cases pass within the source tolerances (5e-6°, 0.5 m round-trip).
- [ ] `x/y → lat/lon → x/y` round-trips stable on all four theatres.
- [ ] Unsupported theatre → clear error naming it; theatre name case-insensitive.
- [ ] Attribution header present; ADR 0015 accepted.
- [ ] ruff + mypy clean (full-tree; new module typed from the start — no exclusion).

## Out of scope

- **MGRS** — not in the source, not needed now. If a maker ever needs it, add it at its simplest
  later (theatre-independent standard, composed with this projection).
