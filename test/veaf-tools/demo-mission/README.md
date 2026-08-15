# VEAF demonstration mission (v6)

The reference VEAF mission, in the **v6** mission-folder format. It is the first thing a new mission
maker opens, so it is kept current with the v6 tooling — converted from v5 on 2026-08-15
(`MIGRATE-DEMO-MISSION-V6`).

## What it is

- `mission.yaml` — the declarative mission config the v6 build consumes: modules, security, combat
  zones, assets, shortcuts, sanctuary, airwaves, and the build pipeline.
- `src/` — the exploded mission source (`src/mission/`), the pipeline inputs (`presets.yaml`,
  `waypoints.yaml`, `spawnables.yaml`, `versions.yaml`, `dynamic-slot-templates.yaml`) and custom
  scripts.
- `veaf-demo-mission.miz` — a built `.miz` kept for `test_edit_zone.py`, which reads a zone's shape
  from it (version-agnostic).

Build it with `veaf-tools mission build` (dev mode against this repo, or with `published/` installed).

## The v6 features it shows

These are things a **v5** mission could not declare — they are why the demo is worth opening rather
than diffing against a v5 mission:

- **Combat zones and a full operation declared in YAML** (`modules.COMBATZONE`). The chained
  `czCrossKobuleti` zones and the `goriOperation` operation — with its `tasking_orders` and their
  `dependencies` — used to live in hand-written Lua; here they are declarative.
- **A staggered custom script** (`custom_scripts` → `src/scripts/demo-delayed-hello.lua` with
  `delay_seconds: 10`). This is `FEAT-CUSTOM-SCRIPT-LOAD-DELAY`, and it is invisible in every other
  shipped example: the script loads in its own trigger 10 s after mission start, not at t=0 with the
  rest — the mechanism AIEN needs to see a populated world.
- **Declarative module config** throughout — `ASSETS`, `SHORTCUTS`, `SANCTUARY`, `AIRWAVES` all carry
  their settings in `mission.yaml` rather than in `missionConfig.lua`.

## Note

`convert-v5` migrated this folder; its former v5 config and presets were copied to
`test/veaf-tools/migration-v5-fixture/` so the migration tests keep a v5 regression case of their own
(`MIGRATE-DEMO-MISSION-V6` ticket 01). Do not run `convert-v5` here again — it is already v6.
