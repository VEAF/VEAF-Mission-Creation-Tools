# FIX-MISSILEGUARDIAN-INIT-CRASH

**Status:** ✅ done

## Problem

Reported by Tripack: with `MISSILEGUARDIAN: true` in `mission.yaml`, F10 marker
spawns via aliases (and `_spawn`) do nothing at runtime even though
`SHORTCUTS: true`. CTLD and CSAR also fail to initialize.

DCS log:

```
ERROR SCRIPTING (Main): Mission script error: [string "l10n/DEFAULT/veaf-scripts.lua"]:39761:
attempt to call field 'dumpMissionsList' (a nil value)
  [C]: in function 'dumpMissionsList'
  ...: in function 'initialize'
  [string "l10n/DEFAULT/veaf-config.lua"]:122: in main chunk
```

## Root cause

`veafMissileGuardian.initialize()` called `veafMissileGuardian.dumpMissionsList(...)`,
a function never defined in the module — a leftover from copy-pasting
`veafCombatMission`. The runtime error aborted the whole generated
`veaf-config.lua` main chunk mid-initialization. Every module initialized
*after* MissileGuardian therefore never ran, most importantly
`veafCommands.initialize()`, which registers the single central F10 marker
dispatcher. Without it, `_spawn` and all shortcut aliases are inert regardless
of `SHORTCUTS: true`. `ctld.initialize()` / `csar.initialize()` were also skipped.

"Worked before" because MissileGuardian is a brand-new module (v0.0.2); earlier
missions did not enable it.

## Fix

1. Remove the stray `dumpMissionsList` call from `veafMissileGuardian.initialize()`
   (the module has no missions list to export). Add a regression test asserting
   `initialize()` does not raise.
2. Stop auto-enabling the module: `MISSILEGUARDIAN` is a 2021 WIP relic (never
   past `0.0.2`) that sat in the `full` tier, so `prepare --tier full` / `convert-v5`
   turned it on by default — the reason it reached Tripack's mission at all. Move it
   to **no tier** (opt-in only, still in the `custom` picker).

## Definition of Done

- [x] `veafMissileGuardian.initialize()` no longer references `dumpMissionsList`.
- [x] Regression test `TestVeafMGInitialize:test_initialize_no_crash`.
- [x] `MISSILEGUARDIAN` removed from the `full` tier (`tiers=frozenset()`), still
      selectable in `custom`; tests updated (`test_missileguardian_is_opt_in_only`,
      `module_lowest_tier` → `None`).
- [x] `poetry run test-lua` + `poetry run pytest` green; ruff/mypy clean.
- [x] `stylua --check src/scripts/veaf/` clean (CI-enforced).
- [x] CHANGELOG (Fixed + Changed) + PATCH bump (6.7.8).
