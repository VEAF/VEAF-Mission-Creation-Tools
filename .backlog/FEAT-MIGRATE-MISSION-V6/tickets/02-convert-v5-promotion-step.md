# FEAT-MIGRATE-MISSION-V6-002 — `convert-v5` promotion step

Status: ✅ done
Type: feat
Files: `mission_builder/`, `mission_extractor/`, `veaf_tools/commands/convert_v5.py`, `test/python/`

## What to build

New `promote_mission_to_v6` orchestrator: base build via `MissionBuilderWorker` (trigger/
script/config layer only, no data injectors) → copy `src/mission/` to
`backup_v5/src/mission/` → extract the temp `.miz` back into `src/mission/`; restore
from backup on extract failure. Wire into `convert-v5`: **default-on**, **non-blocking**,
`--no-promote` opt-out; surface the outcome in the report. TDD.

## Acceptance criteria

- [x] `promote_mission_to_v6` orchestrator: base build → backup → extract back into `src/mission/`
- [x] Current `src/mission/` copied to `backup_v5/src/mission/` before overwrite; restore on failure
- [x] Wired into `convert-v5`: default-on, non-blocking, `--no-promote` opt-out
- [x] Outcome surfaced in the convert report
- [x] TDD coverage

## Blocked by

FEAT-MIGRATE-MISSION-V6-001 (idempotence confirmed before the round-trip is safe)
