# FIX-SECURED-FORALL-AND-UPDATER-BAT — two defects from the GermanyCW Open Training of 2026-09-29

Status: ✅ done (PR #1028, merged 2026-09-29) · archived 2026-10-03

Found on the private1 server session of 2026-09-29 (`VEAF_OpenTraining_GermanyCW_ICAO_ETAR_20260928.miz`,
security enabled) and grouped in one PR.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | secured "for all" radio commands refuse every click | ✅ |
| 02 | the updater writes its batch file in the wrong encoding | ✅ |

## Definition of done

- 01: Lua tests showing a secured ForAll command is posted per group, keeps its parameters, runs for
  an authorised group and is refused below the level; unchanged when security is disabled.
- 02: the generated script is ASCII and enters an accented mission folder (run on Windows); the
  encoding guard also covers `Path.read_text()` / `Path.write_text()`.
- `CHANGELOG.md` entry; `veafSecurity` page updated in FR and EN.

## Tickets, in full

## 01 — secured "for all" radio commands refuse every click

Status: ✅ done

### Measured (2026-09-29)

- `dcs.log` of private1: `VEAF-RADIO|W|26606: refusing a secured command posted without a group` at
  11:19:40, 11:20:56 and 11:21:13 UTC, `veaf.SecurityDisabled=[false]`, no startup warning.
- The activation that went through 30 s later (`combatZone_WahnerHeide_Easy`) is a **training** zone
  (`:setTraining(true)` in the mission's `veaf-config.lua`): its *activate* entry is not secured
  (`veafCombatZone.lua`, `isTraining()` branch). The 16 non-training zones of the mission post a
  secured activate; Letzlingen and Werneuchen had just been opened by the refused pilot.
- No menu is built per group for a ForAll command: `_placeCommandOnMenu` sends every ForAll command
  to `_addDcsCommand(nil, ...)`, which wraps a secured one into `_proxyMethod` with `groupId = nil`.
  `_proxyMethod` refuses that since #676 (6.14.0, 2026-08-09).

### Fix

- A secured ForAll command is posted once per human group (same coalition filter and spawned-unit
  rule as ForGroup), with its parameters unchanged — ForGroup appends the unit name, ForAll methods do
  not expect it.
- Only while security is enabled: with security disabled `_proxyMethod` runs anything, and posting for
  all keeps the entry visible to a game master or a spectator, who have no group.
- `_addDcsCommand` warns when a secured command still reaches it without a group while security is on.

### Done when

Lua tests in `test/lua/test_veafRadio.lua` cover the cases in the PRD's definition of done.

## 02 — the updater writes its batch file in the wrong encoding

Status: ✅ done

### Measured (2026-09-29, French Windows, ANSI cp1252, OEM cp850)

- `_launch_deferred_update` writes `apply-update.cmd` with `write_text()` (ANSI) and its first command
  is `cd /d "<mission folder>"`. cmd reads a batch file in the console code page: written in cp1252,
  `cd` into `Mission élève Nörvenich` fails (`rc=1`) and the update aborts.
- Writing in `oem` fixes that folder but raises `UnicodeEncodeError` for `Misja Łódź` (`Ł` is not in
  cp850), and would still break after a `chcp 65001`.
- `cd /d "%~dp0.."` lets cmd resolve its own location (the script lives in
  `<mission>\.veaf-update-pending\`): the file becomes pure ASCII, and it entered `Misja Łódź`.
- The same `cd` ran under `enabledelayedexpansion`, which eats a `!` in the path; enabling it after
  the `cd` removes that case.
- `Path.read_text()` / `write_text()` without `encoding=`: this call is the only one in
  `src/python/veaf-tools/`.

### Done when

The script is ASCII, written with `encoding="ascii"`, tested on Windows from an accented folder, and
`test_text_files_opened_as_utf8.py` flags `read_text` / `write_text` without an encoding.
