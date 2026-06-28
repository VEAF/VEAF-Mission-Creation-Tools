# UX-AIRCRAFT-SKIPPED-REPORT

Status: ✅ done

## Problem

Two small `build` console-output issues, surfaced while diagnosing Tripack's mission:

1. The **spawn-data** pipeline step printed `Pipeline : données de spawn` with **no file
   name**, unlike every other step (`presets.yaml`, `waypoints.yaml`, `spawnables.yaml`,
   `versions.yaml`, warehouses) which name their file. Confusing: the maker can't tell the
   step reads `src/spawn-groups.yaml`.
2. The **aircraft** step reported only `N injected`. When spawnable aircraft are **already
   present in the mission** (carried in `src/mission/`), `add` mode correctly skips them and
   prints `0 injected` — which reads like a failure even though nothing is wrong. The number
   of skipped (already-present) groups was invisible.

## Fix

1. `pipeline.console.spawn_data` takes a `{file}` suffix; `build` passes
   ` (spawn-groups.yaml)` when the file exists (the step still runs on the shipped
   framework data when absent).
2. `InjectionResult` gains `groups_skipped`; `inject_groups` counts the already-present
   skips; `build` prints `N already present in the mission (skipped)` after the injected
   count when non-zero. Verified on Tripack: `injected: 0 | skipped: 41`.
3. Same spirit for the **presets** and **waypoints** steps (audit of all `0`-counts):
   when human-piloted groups are examined but none match, they now add
   `N group(s) had no matching preset` / `no flight plan in <file> (left unchanged)`
   instead of a bare `injected into 0`. Warehouses already warned (`no_airports`);
   spawn-data/weather rarely hit 0 — left as-is.

## Out of scope

- Any behavior change to injection itself (skip logic unchanged — `add` keeps existing
  groups, see FIX in 6.x). This is reporting only.
