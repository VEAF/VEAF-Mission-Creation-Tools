# FEAT-MIGRATE-MISSION-V6-002 — `migrate-mission` command

Status: ⬜ ready
Type: feat
Files: `veaf_tools/commands/`, `mission_builder/`, `mission_extractor/`, `veaf_libs/tui.py`, `test/python/`

## What to build

Build in memory (full v6 injection) → extract back into `src/mission/`, after copying
the current `src/mission/` to `backup_v5/src/mission/`. Emit a short report (what
changed, backup location). Add to the TUI (`CommandSpec`, per FIX-TUI-MISSING-COMMANDS
guard). TDD.

## Acceptance criteria

- [ ] Command builds in memory then extracts back into `src/mission/`
- [ ] Current `src/mission/` copied to `backup_v5/src/mission/` before overwrite
- [ ] Short report emitted (changes + backup location)
- [ ] `CommandSpec` added so the command appears in the TUI
- [ ] TDD coverage for the command

## Blocked by

FEAT-MIGRATE-MISSION-V6-001 (idempotence must be confirmed before the round-trip is safe)
