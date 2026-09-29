# 02 — the updater writes its batch file in the wrong encoding

Status: ✅ done

## Measured (2026-09-29, French Windows, ANSI cp1252, OEM cp850)

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

## Done when

The script is ASCII, written with `encoding="ascii"`, tested on Windows from an accented folder, and
`test_text_files_opened_as_utf8.py` flags `read_text` / `write_text` without an encoding.
