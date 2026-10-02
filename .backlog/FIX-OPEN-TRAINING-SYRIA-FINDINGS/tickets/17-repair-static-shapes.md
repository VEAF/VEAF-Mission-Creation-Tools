# 17 — An action fills the shape_name of statics placed before #1023

Status: ⬜ ready

Files: a new `veaf_mission_mcp/repair_static_shapes.py`, `veaf_mission_mcp/actions.py`, tests, the
mission-maker action catalogue.

## What happened

Caucasus Open Training v6, `tools/retours-vmct.md` point 17: the `shape_name` fix of #1023 applies to new
placements only. The 42 statics placed before it had none, `validate` reported them, and the mission wrote
its own `tools/fix_shape_names.py` (GermanyCW-v6 lost four objectives the same way, its journal §12: DCS
refuses a static of those types without `shape_name`).

## Done when

- `repair_static_shapes(target)` fills every missing `shape_name` the units database knows
  (`get_unit_shape_name`), reports what it filled and what it could not, and writes nothing when there is
  nothing to fill.
- `validate`'s warning names the action.
