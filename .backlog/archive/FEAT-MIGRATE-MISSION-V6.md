# Lot FEAT-MIGRATE-MISSION-V6 — promote `src/mission/` (the exploded `.miz`) from v5 to v6 on disk

Status: ✅ done
Branch: feature/migrate-mission-v6 → PR #517 → merged into develop

## Problem Statement

`convert-v5` converts a v5 mission folder's Lua/config to v6 (`missionConfig.lua` →
`mission-script.lua`, pipeline `.lua/.json` → `.yaml`, generates `mission.yaml`) but
**deliberately leaves the exploded mission untouched** (see `v5_converter.py` module
docstring). The DCS trigger migration v5→v6 is instead done **in memory at build
time** by the builder (`migrate_from_v5=True` by default): the v5 VEAF injection
triggers/dict keys are neutralised on the fly and the v6 injection is layered on top to
produce the output `.miz`. `src/mission/` therefore stays v5 forever, and the migration
is re-run on every build.

`src/mission/` is already a *generated, normalised* artifact — the extractor does
`read_miz`→`write_miz`→extract with a deterministic key order (`luadata._sort`,
priority keys `id`/`name`/`type` first) — and the framework already anticipates a
`src/mission/` that contains injected groups after a v5→v6 conversion
(aircrafts-injector test docstring: *"After a v5→v6 conversion the source
`src/mission/mission` already contains [groups]"* → idempotent skip/replace by name).
Promoting it to v6 on disk is therefore consistent with the existing design, not a hack.

## Solution

**Extend `convert-v5`** with a final **promotion step** that rewrites `src/mission/` to
v6 on disk via a **base build → extract** round-trip:

1. **base build** — `MissionBuilderWorker.work()` alone (clears legacy v5 triggers +
   reinjects v6 framework triggers + scripts/config; the data injectors are **not**
   run) → temp `.miz`;
2. copy current `src/mission/` to `backup_v5/src/mission/`;
3. extract the temp `.miz` back into `src/mission/` (restore from backup if the extract
   fails).

`src/mission/` is the live extract of a previously-built `.miz` (cycle: build → edit →
extract → edit → build), so it already holds the injected data (spawnable groups,
waypoints in routes, presets in units, warehouses). The base build **preserves all of
it** — `clear_veaf_triggers` only removes VEAF triggers / dict / map keys, never groups
/ routes / units — so nothing is lost; only the legacy v5 trigger layer is purged.
Running the data injectors (full build) is unnecessary (the data is already present)
and would require refactoring `build.py`'s pipeline + risks orphaning data removed from
the YAMLs.

Default **on**, **non-blocking** (if the base build fails, the configs stay converted
and `src/mission/` is left untouched, with a clear warning), **opt-out** via
`--no-promote`. Payoffs: (1) a definitive v6 switch (the source is clean v6, no v5
legacy); (2) `migrate_from_v5` becomes redundant for promoted missions.

## User Stories

1. As a mission-maker, I want a definitive on-disk v6 switch for my mission, so that
   the source is a clean v6 mission with no v5 legacy and no per-build re-migration.
2. As a mission-maker, I want the promotion to run automatically as the last step of
   `convert-v5`, so that I get a v6 source without a separate command.
3. As a mission-maker, I want a `--no-promote` opt-out and a safe `backup_v5/` copy, so
   that I stay in control and can recover the v5 source.

## Implementation Decisions

- Promotion is a final step of `convert-v5`, not a separate command: base build
  (`MissionBuilderWorker`) → copy `src/mission/` to `backup_v5/` → extract back.
- The base build runs the trigger/script/config layer only, **not** the data
  injectors (the data is already in `src/mission/`).
- Default-on, non-blocking (configs stay converted on base-build failure), `--no-promote`
  opt-out; outcome surfaced in the convert report.
- Restore from backup if the extract fails.
- Deprecate (not remove) `migrate_from_v5`: warn when it actually migrates, keep the
  flag for back-compat.

## Testing Decisions

- Idempotence audit done — all injectors are safe on rebuild-after-promote (no
  duplicates): aircrafts (skip/replace by name), spawn-data (Lua stripped on extract +
  trigger remove/reinject), waypoints (replace by name), presets (overwrite of
  `unit["Radio"]`/`frequency`), warehouses (dict keyed by type, `setdefault`+overwrite),
  weather (scalar set + `update`).
- Per-injector unit tests lock the idempotence contract (a second apply over an
  already-injected mission produces no duplicate).
- TDD for the `promote_mission_to_v6` orchestrator and the `convert-v5` wiring.

## Out of Scope

- Removing `migrate_from_v5` outright (only deprecation + warning here).
- Running the data injectors during promotion (deliberately avoided — see Solution).

## Further Notes

Approach changed during implementation: from a standalone `migrate-mission` command (a
full in-memory build → extract) to a **base build → extract promotion step inside
`convert-v5`**, which preserves all editor content while purging only the legacy v5
trigger layer.

---

## FEAT-MIGRATE-MISSION-V6-001 — idempotence audit + regression tests

Status: ✅ done
Type: spike
Files: `test/python/`

### What to build

Audit done — all injectors are idempotent on rebuild-after-promote (see lot summary):
aircrafts (skip/replace by name), spawn-data (Lua stripped on extract + trigger
remove/reinject), waypoints (replace by name), presets (overwrite), warehouses
(dict keyed by type), weather (scalar set + `update`). Add per-injector unit tests
asserting a second apply over an already-injected mission produces no duplicate (lock
the contract).

### Acceptance criteria

- [x] Per-injector idempotence contract documented (aircrafts, spawn-data, waypoints, presets, warehouses, weather)
- [x] Per-injector tests assert no duplicate on a second apply over an already-injected mission

### Blocked by

None — can start immediately

---

## FEAT-MIGRATE-MISSION-V6-002 — `convert-v5` promotion step

Status: ✅ done
Type: feat
Files: `mission_builder/`, `mission_extractor/`, `veaf_tools/commands/convert_v5.py`, `test/python/`

### What to build

New `promote_mission_to_v6` orchestrator: base build via `MissionBuilderWorker` (trigger/
script/config layer only, no data injectors) → copy `src/mission/` to
`backup_v5/src/mission/` → extract the temp `.miz` back into `src/mission/`; restore
from backup on extract failure. Wire into `convert-v5`: **default-on**, **non-blocking**,
`--no-promote` opt-out; surface the outcome in the report. TDD.

### Acceptance criteria

- [x] `promote_mission_to_v6` orchestrator: base build → backup → extract back into `src/mission/`
- [x] Current `src/mission/` copied to `backup_v5/src/mission/` before overwrite; restore on failure
- [x] Wired into `convert-v5`: default-on, non-blocking, `--no-promote` opt-out
- [x] Outcome surfaced in the convert report
- [x] TDD coverage

### Blocked by

FEAT-MIGRATE-MISSION-V6-001 (idempotence confirmed before the round-trip is safe)

---

## FEAT-MIGRATE-MISSION-V6-003 — deprecate `migrate_from_v5`

Status: ✅ done
Type: chore
Files: `mission_builder/mission_builder_worker.py`, `veaf_tools/commands/build.py`, `test/python/`

### What to build

Once a mission can be promoted on disk, the in-memory build migration is redundant for
migrated missions. Emit a build warning when `migrate_from_v5` actually migrates
something (source still v5) inviting the maker to re-run `convert-v5` (promotion); keep
the flag for back-compat. Plan the code removal once the ecosystem is migrated.

### Acceptance criteria

- [x] Build warning emitted when `migrate_from_v5` actually migrates (source still v5)
- [x] Warning points the maker to re-run `convert-v5` (promotion)
- [x] Flag kept for back-compat (no removal yet)

### Blocked by

FEAT-MIGRATE-MISSION-V6-002 (`convert-v5` promotion must exist before inviting makers to use it)

---

## FEAT-MIGRATE-MISSION-V6-004 — docs

Status: ✅ done
Type: doc
Files: `doc/`

### What to build

Document the v6 promotion in the Migration Guide (when/why, `backup_v5`,
definitive-switch semantics, `--no-promote` opt-out) as part of `convert-v5`.

### Acceptance criteria

- [x] Migration Guide covers when/why to promote, `backup_v5`, definitive-switch semantics
- [x] `convert-v5` `--no-promote` opt-out documented

### Blocked by

FEAT-MIGRATE-MISSION-V6-002 (document the promotion once it exists)
