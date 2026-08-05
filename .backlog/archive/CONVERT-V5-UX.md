# CONVERT-V5-UX

Status: ✅ done

> Reopened (2026-06-28): the 6.7.1 fix removed only the annotated-`missionConfig.lua`
> block from the report. The same misleading "missionConfig.lua edits" messages were
> still emitted through other channels. Fixed in 6.7.2 (#533). See section 3.

Two convert-v5 output/UX improvements (both in `v5_converter.py`).

## 1 — Triage leftover v5 files (CONVERT-V5-CLEANUP-FILES)

A v5 mission folder keeps a lot of cruft the v6 toolchain no longer uses (build
scripts, npm tooling, generated artifacts) plus mission-specific stray files.
`convert-v5` ignored all of it. It now scans the root (and `src/` top level) and
triages, in three outcomes:

- **Tooling files** at the root (`*.cmd`, `*.cmd.sample`, `*.ps1`, `package.json`,
  `package-lock.json`, `yarn.lock`, `configuration.json`, `7za.exe`) → moved to
  `backup_v5/` (reversible, like the converted pipeline configs). `configuration.json`
  is additionally flagged as **secret-bearing** (its v5 `checkwx_apikey`).
- **Regenerable artifacts** (`node_modules/`, `build/`, `cache/`) → **deleted** outright
  (gitignored, rebuilt on demand — not worth archiving) and reported.
- **Unrecognized files** (anything else the converter does not manage) → only **listed**
  for the maker to review; never touched.

Never touches `.git/`, `backup_v5/`, `src/mission/`, generated v6 files, dotfiles.
Idempotent. (checkwx note: not migrated — v6 uses `avwx-engine`, no API key.)

## 2 — Report no longer embeds a misleading "annotated missionConfig.lua" (CONVERT-V5-REPORT-ANNOTATION)

The report embedded a pseudo `missionConfig.lua` with `if … then` guards and
`-- [v6 …]` comments — an artifact that is never executed (the original is backed up
untouched; the live file is the generated `mission-script.lua`), which made it look
like a file was being edited. Removed. The migration is already reported as the
line→effect tables (commented doFiles, wrapped/extracted init calls, enabled modules),
which stay. Console wording unchanged (decided).

## 3 — Drop the "missionConfig.lua edits" report noise (CONVERT-V5-INIT-COMMENTED-NOISE)

The 6.7.1 fix (section 2) removed only the annotated-`missionConfig.lua` block. `convert-v5`
still described a whole family of edits to a file it deletes — across the console,
`convert-v5-report.md`, and the manual-review / leftovers sections:

- `init_commented` warning (per guarded `initialize()`) → `report.warnings` + `report.manual_review`;
- `dofiles_commented` / `init_wrapped` actions + console blocks + report `.md` tables;
- `review.remove_dofiles` + `cleanup.remove_dofiles`.

All point at the migrated buffer `convert-v5` never writes (original backed up then deleted;
live file is the generated `mission-script.lua`), so there is nothing on disk to review. All
removed from `convert-v5`. The detected modules (which drive `mission.yaml`) stay. The
`mission-script.lua generated` action is now shown **only when the file carries callback
stubs** (empty skeleton → no message) and reworded as an edit invitation + `mission.yaml`
reminder. The standalone `migrate-config` command, which **does** write the migrated
`*_v6.lua`, keeps its messages. Orphaned FR/EN catalog keys dropped.

## Decisions (validated by David)

- Init-commented noise: **delete** the warning outright (not reformulate), reopen this lot.
- Extend to the doFiles + wrapped-init families for consistency; `migrate-config` untouched.
- `mission-script.lua` action: conditional on callbacks present; empty skeleton → no message.

- Cleanup: a+b. (a) tooling → backup_v5; (a) regenerable → delete + signal;
  (b) unrecognized → inform only. Secret signalled.
- Report: rapport only; remove the annotated block entirely.

## Out of scope

- Console wording of the missionConfig migration messages (kept).
- Doc anchors (separate lot DOC-GUIDE-ANCHORS).

---

## 01 — Leftover-file triage + report annotation removal

Status: ✅ done (shipped in 6.7.1, #528)

### Tasks

- [ ] `_cleanup_legacy_v5_files` + `_archive_file_to_backup_v5`; call as convert() step 5.
- [ ] Report fields + `🧹 Legacy v5 files` report section + console output (unrecognized + secret).
- [ ] i18n keys (FR/EN): `convert_v5.cleanup.*`, `report.legacy_files.*`.
- [ ] Remove the annotated-missionConfig block from `to_markdown`; drop the field,
      the action append, the 3 unused i18n keys; update backup README.txt text.
- [ ] Tests: cleanup triage (tooling→backup, secret flag, regenerable delete, unrecognized
      listed/untouched, protected entries, src known-v6 exclusion, idempotence);
      report has no `~~~~lua` block but keeps the mapping tables.
- [ ] Migration guide note (FR/EN); CHANGELOG; PATCH bump.

### Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.

---

## 02 — Drop the "missionConfig.lua edits" report noise

Status: ✅ done

### Context

The 6.7.1 fix (ticket 01) removed only the annotated-`missionConfig.lua` block from the
report. `convert-v5` still described a series of edits to a file it deletes — across the
console, `convert-v5-report.md`, and the manual-review / leftovers sections:

- `init_commented` warning (per guarded `initialize()`) → `report.warnings` + `report.manual_review`;
- `dofiles_commented` / `init_wrapped` actions + console blocks + report `.md` tables;
- `review.remove_dofiles` (manual review) + `cleanup.remove_dofiles` (leftovers).

All point at the migrated buffer that `convert-v5` never writes (original backed up then
deleted; live file is the generated `mission-script.lua`). The standalone `migrate-config`
command **does** write that buffer, so its messages stay legitimate and untouched.

### Decision (validated by David)

- **Delete** the noise (not reformulate). Keep only the detected modules (drive `mission.yaml`).
- `mission-script.lua generated` action: show **only when callbacks are stubbed** (empty
  skeleton → no message), reworded as an invitation to edit it + reminder that `mission.yaml`
  does the bulk.
- Nettoyer aussi la famille doFiles, par cohérence.

### Tasks

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

### Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- A converted mission no longer lists any `missionConfig.lua` edit (init/doFile/wrap)
  in its console output, report, or review/cleanup sections.
