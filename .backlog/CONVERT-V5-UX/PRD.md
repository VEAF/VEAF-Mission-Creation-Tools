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
