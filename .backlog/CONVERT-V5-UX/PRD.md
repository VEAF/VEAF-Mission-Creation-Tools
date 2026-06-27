# CONVERT-V5-UX

Status: ✅ done

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

## Decisions (validated by David)

- Cleanup: a+b. (a) tooling → backup_v5; (a) regenerable → delete + signal;
  (b) unrecognized → inform only. Secret signalled.
- Report: rapport only; remove the annotated block entirely.

## Out of scope

- Console wording of the missionConfig migration messages (kept).
- Doc anchors (separate lot DOC-GUIDE-ANCHORS).
