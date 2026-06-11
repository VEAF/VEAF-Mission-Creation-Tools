---
status: accepted
---

# Static vs dynamic VEAF script loading (and the two loader files)

VEAF missions can load their Lua in two ways. The build injects **six paired
triggers** into the `.miz` so the *same* mission works in both modes, selected at
runtime by whether the `VEAF_DYNAMIC_*PATH` globals are set. Two files —
`VeafDynamicLoader.lua` and `veafDynamicConfig.lua` — looked redundant; this note
documents what each does and concludes neither is obsolete (DYNLOAD-CLARIFY
spike, todo-2026.06.09 item 2).

## The two loaders are different layers, not duplicates

| File | Location | Loads | Scope |
|------|----------|-------|-------|
| `VeafDynamicLoader.lua` | `src/scripts/` (VEAF framework) | every `src/scripts/veaf/*.lua` module, in dependency order, then sets dev flags (`veaf.Development = true`, trace logging, `SecurityDisabled`, `authenticated`) | the **VEAF framework** |
| `veafDynamicConfig.lua` | `src/defaults/mission-folder/src/scripts/` (mission scaffold, shipped per mission) | the **mission's** scripts listed in its `scriptsToLoad` table (today: `mission-script.lua`) | the **single mission** |

`VeafDynamicLoader.lua` resolves modules under `VEAF_DYNAMIC_SCRIPTSPATH`;
`veafDynamicConfig.lua` resolves mission scripts under `VEAF_DYNAMIC_MISSIONPATH`.
They cover two independent layers (shared framework vs per-mission code), so a
mission maker can live-edit mission scripts without touching the framework, and a
framework dev can live-edit VEAF scripts without rebuilding every mission.

## The loading flow (built by `mission_builder_worker.py`)

The build prepends six triggers (after the dcs-bridge trigger), as three
dynamic/static pairs gated on the runtime presence of the path globals:

1. set `VEAF_DYNAMIC_SCRIPTSPATH` (dynamic builds only)
2. set `VEAF_DYNAMIC_MISSIONPATH` (dynamic builds only)
3. **dynamic** — `loadfile` the community scripts + `VeafDynamicLoader.lua` from `VEAF_DYNAMIC_SCRIPTSPATH`
4. **static** — `a_do_script_file` the VEAF scripts embedded as `.miz` map resources
5. **dynamic** — `loadfile` `veafDynamicConfig.lua` from `VEAF_DYNAMIC_MISSIONPATH`
6. **static** — `a_do_script_file` the mission scripts embedded as map resources

- **Dynamic mode** (dev/test): paths are set, so triggers 3 & 5 fire and scripts
  are read from disk at runtime — instant iteration, no `.miz` rebuild. This is
  the mode the `defaults/mission-folder` scaffold's `veafDynamicConfig.lua` and
  the framework's `VeafDynamicLoader.lua` exist for.
- **Static mode** (distribution): the path globals are unset, so triggers 4 & 6
  fire and scripts run from resources embedded in the `.miz` — self-contained,
  no external folder needed. The two loader files are bypassed entirely.

## Decision

Keep both files. Neither is obsolete:

- `VeafDynamicLoader.lua` is the framework loader and is referenced by build
  trigger 3; removing it breaks dynamic mode for the VEAF scripts.
- `veafDynamicConfig.lua` is the mission loader and is referenced by build
  trigger 5; removing it breaks dynamic mode for mission scripts.

No cleanup ticket is warranted for these two files. The `defaults/mission-folder`
audit (DEFAULTS-AUDIT-001) independently confirmed `veafDynamicConfig.lua` is a
live default.

## Consequences

- The dynamic/static split is documented (here + `CONTEXT.md`), so the two
  loaders are no longer mistaken for duplicates.
- **Out of scope / deferred**: this spike covers how the *current* build emits
  loading triggers. Whether a **legacy v5** mission's own VEAF loading triggers
  are detected and removed during `build --migrate-from-v5` (vs. left in place
  alongside the freshly-injected ones) is a separate question owned by the
  TODO0609-TRIGGERS-VERIFY lot — the build inserts its six triggers and shifts
  existing triggers up without inspecting them for legacy VEAF loaders.
