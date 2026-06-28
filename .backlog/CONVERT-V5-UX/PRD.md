# CONVERT-V5-UX

Status: 🔄 in-progress

> Reopened (2026-06-28): the 6.7.1 fix removed only the annotated-`missionConfig.lua`
> block from the report. The same misleading "init commented out" message was still
> emitted through two other channels (warnings + manual-review). See section 3.

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

## 3 — Drop the leftover "init commented out" noise (CONVERT-V5-INIT-COMMENTED-NOISE)

The 6.7.1 fix (section 2) removed the annotated-`missionConfig.lua` block from the
report, but the migrator still emitted, for every guarded `veafXxx.initialize()`, a
`convert_v5.warning.init_commented` warning that `v5_converter` propagated to **both**
`report.warnings` (⚠ section) **and** `report.manual_review` (🛠 section) — a dozen-plus
duplicated lines on a real mission. They describe a file that is deleted (`src.unlink()`
after backup): the migrated `new_content` with `-- [v6 migration]` comments is never
written to disk (the live file is the generated `mission-script.lua`), so there is no
line N to review. The warning emission is removed (the internal commenting of
`new_content` is unchanged), and the orphaned FR/EN `init_commented` catalog entries
are dropped. Module detection and the genuine notices (commented `doFile`s, wrapped
bare `initialize()`) stay.

## Decisions (validated by David)

- Init-commented noise: **delete** the warning outright (not reformulate), reopen this lot.

- Cleanup: a+b. (a) tooling → backup_v5; (a) regenerable → delete + signal;
  (b) unrecognized → inform only. Secret signalled.
- Report: rapport only; remove the annotated block entirely.

## Out of scope

- Console wording of the missionConfig migration messages (kept).
- Doc anchors (separate lot DOC-GUIDE-ANCHORS).
