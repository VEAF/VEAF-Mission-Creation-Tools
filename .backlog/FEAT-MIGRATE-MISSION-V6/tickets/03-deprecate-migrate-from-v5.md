# FEAT-MIGRATE-MISSION-V6-003 — deprecate `migrate_from_v5`

Status: ✅ done
Type: chore
Files: `mission_builder/mission_builder_worker.py`, `veaf_tools/commands/build.py`, `test/python/`

## What to build

Once a mission can be promoted on disk, the in-memory build migration is redundant for
migrated missions. Emit a build warning when `migrate_from_v5` actually migrates
something (source still v5) inviting the maker to re-run `convert-v5` (promotion); keep
the flag for back-compat. Plan the code removal once the ecosystem is migrated.

## Acceptance criteria

- [x] Build warning emitted when `migrate_from_v5` actually migrates (source still v5)
- [x] Warning points the maker to re-run `convert-v5` (promotion)
- [x] Flag kept for back-compat (no removal yet)

## Blocked by

FEAT-MIGRATE-MISSION-V6-002 (`convert-v5` promotion must exist before inviting makers to use it)
