# 03 — add_farp: a FARP on a lake, and on a tower frequency

Status: ⬜ ready

Files: `veaf_mission_mcp/add_farp.py`, `veaf_mission_mcp/surface.py`, `veaf_mission_mcp/actions.py` (schema text), tests.

## What happened

Falklands OT, report findings 7–9.
FARP Torres del Paine stood in a lake: its pad and ammo dump read `land.getSurfaceType` = 3 while the 250 m grid said 79 m (the grid knows only the sea, 0 m; an inland lake is ground to it). `add_farp` probes no surface at runtime and says nothing.
The same FARP was put on 128.5, the Franco Bianco tower, and nothing warns; `heliport_frequency` cannot be set afterwards by any action.

## Done when

- The `add_farp` result always says that lakes and rivers are not seen by the grid, and gives the `farp-spot` command that probes the surface in DCS (on `develop` since 2026-10-12; the 6.29.0 exe lacks it).
- `add_farp` warns when the FARP's frequency is the tower of an airfield of the theatre (`veaf_libs/data/airfield-frequencies.yaml`), and says which.
- Tests: a FARP on 128.5 on Falklands warns naming Franco Bianco; on a free frequency it does not; the lake sentence is in the result.

Whether a later action should set the frequency (finding 9's `fix_farp_freq.py`) is a separate question for David.
