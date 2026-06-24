# Lot FEAT-MIGRATE-MISSION-V6 — promote `src/mission/` (the exploded `.miz`) from v5 to v6 on disk

Status: ⬜ ready
Branch: feature/migrate-mission-v6 → PR → develop-v6

## Problem Statement

`convert-v5` converts a v5 mission folder's Lua/config to v6 (`missionConfig.lua` →
`mission-script.lua`, pipeline `.lua/.json` → `.yaml`, generates `mission.yaml`) but
**deliberately leaves the exploded mission untouched** (see `v5_converter.py` module
docstring). The DCS trigger migration v5→v6 is instead done **in memory at build
time** by the builder (`migrate_from_v5=True` by default — `mission_builder_worker.py`
~L1059): the v5 VEAF injection triggers/dict keys are neutralised on the fly and the
v6 injection is layered on top to produce the output `.miz`. `src/mission/` therefore
stays v5 forever, and the migration is re-run on every build.

`src/mission/` is already a *generated, normalised* artifact — the extractor does
`read_miz`→`write_miz`→extract with a deterministic key order (`luadata._sort`,
priority keys `id`/`name`/`type` first) — and the framework already anticipates a
`src/mission/` that contains injected groups after a v5→v6 conversion
(aircrafts-injector test docstring: *"After a v5→v6 conversion the source
`src/mission/mission` already contains [groups]"* → idempotent skip/replace by name).
Promoting it to v6 on disk is therefore consistent with the existing design, not a hack.

## Solution

A command (name TBD, e.g. `veaf-tools migrate-mission`) that promotes `src/mission/`
to v6 on disk via a **build→extract round-trip**: build the mission in memory (full v6
injection, v5 triggers migrated), then extract the result back into `src/mission/`,
after copying the current `src/mission/` to `backup_v5/src/mission/`. Two payoffs:
(1) a **definitive v6 switch** for the mission-maker (the source becomes a clean v6
mission, editable/buildable with no v5 legacy), and (2) it makes `migrate_from_v5`
**redundant** for migrated missions, paving the way to remove that build-time debt.
**Functional (not binary) fidelity** is expected and accepted — the build injects
data, so the exploded v6 differs from the exploded v5 by construction.

## User Stories

1. As a mission-maker, I want a definitive on-disk v6 switch for my mission, so that
   the source is a clean v6 mission with no v5 legacy and no per-build re-migration.

## Implementation Decisions

- Build→extract round-trip: build in memory (full v6 injection), then extract back
  into `src/mission/`.
- Safety copy of the current `src/mission/` to `backup_v5/src/mission/` before
  overwriting.
- Deprecate (not remove) `migrate_from_v5`: warn when it actually migrates, keep the
  flag for back-compat.

## Testing Decisions

- Idempotence spike: build → extract → rebuild asserts stability (group/trigger
  counts unchanged).
- TDD for the `migrate-mission` command.

## Out of Scope

- Removing `migrate_from_v5` outright (only deprecation + warning here).

## Further Notes

**Pre-req / risk**: the round-trip is only safe if **every** injector is idempotent on
rebuild when `src/mission/` already holds its output (no duplicates). Verified:
aircrafts (skip/replace by name, explicitly for the post-conversion case) and
spawn-data (Lua resource stripped on extract + VEAF trigger remove/reinject). **To
audit**: waypoints, presets, warehouses, weather.
