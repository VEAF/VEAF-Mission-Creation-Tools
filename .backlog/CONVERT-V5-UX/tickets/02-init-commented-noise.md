# 02 — Drop the "missionConfig.lua edits" report noise

Status: ✅ done

## Context

The 6.7.1 fix (ticket 01) removed only the annotated-`missionConfig.lua` block from the
report. `convert-v5` still described a series of edits to a file it deletes — across the
console, `convert-v5-report.md`, and the manual-review / leftovers sections:

- `init_commented` warning (per guarded `initialize()`) → `report.warnings` + `report.manual_review`;
- `dofiles_commented` / `init_wrapped` actions + console blocks + report `.md` tables;
- `review.remove_dofiles` (manual review) + `cleanup.remove_dofiles` (leftovers).

All point at the migrated buffer that `convert-v5` never writes (original backed up then
deleted; live file is the generated `mission-script.lua`). The standalone `migrate-config`
command **does** write that buffer, so its messages stay legitimate and untouched.

## Decision (validated by David)

- **Delete** the noise (not reformulate). Keep only the detected modules (drive `mission.yaml`).
- `mission-script.lua generated` action: show **only when callbacks are stubbed** (empty
  skeleton → no message), reworded as an invitation to edit it + reminder that `mission.yaml`
  does the bulk.
- Nettoyer aussi la famille doFiles, par cohérence.

## Tasks

- [x] Remove the `init_commented` warning emission in `config_migrator.py` (keep the
      internal `-- [v6 migration]` commenting of `new_content`).
- [x] Stop surfacing `removed_dofiles` / `wrapped_calls` in `convert-v5` (actions, console,
      report `.md` tables, manual-review, leftovers). Leave `migrate-config` (`config.py`)
      and the neutral `MigrationResult` fields intact.
- [x] Make `mission_script_generated` conditional on `callback_hints`; reword it (FR/EN).
- [x] Drop all orphaned catalog keys from `en.json` + `fr.json` (parity kept).
- [x] Tests: no warning on guarded `initialize()`; no `doFile`/wrap edits in actions or
      manual-review; mission-script action present iff callbacks; report tables gone.
- [x] CHANGELOG `[Unreleased]`; PATCH bump (6.7.1 → 6.7.2); `poetry install`.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- A converted mission no longer lists any `missionConfig.lua` edit (init/doFile/wrap)
  in its console output, report, or review/cleanup sections.
