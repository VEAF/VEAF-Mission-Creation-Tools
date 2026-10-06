# 04 — The build exits 1 after succeeding when its output goes to `/dev/null`

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_tools/helpers.py` (`should_auto_pause`, `_is_double_clicked`), `veaf_tools/app.py` (l. 81-87), tests

## What happens

`veaf-tools.exe mission build … > /dev/null` from Git Bash: the `.miz` is written, then « Appuyez sur Entrée pour quitter... » and `EOFError` on the final `input()`, exit code 1.
`_is_double_clicked()` takes that launch for a double-click. A script or CI that tests the exit code reads a failed build.

## Measured

Demo mission folder, 2026-10-05: output redirected to a file, exit 0 (three builds); to `/dev/null`, exit 1 (two builds).

## Fix

- Never pause when stdin is not a TTY, and treat `EOFError` on the pause as "no one to press a key" (exit with the command's own code).
- Test: auto-pause on, stdin closed → exit code of the command, no traceback.

## Workaround meanwhile

`VEAF_UPDATER_NO_PAUSE=1`, or redirect to a file (the demo's `CLAUDE.md` says the latter).
