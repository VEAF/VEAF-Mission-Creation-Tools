# Lot FIX-UPDATER-PAUSE-HANG — plugin bootstrap / scaffold hang on the updater's pause

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/updater-pause-hang` → PR → `feature/mcp-mission-editor`

## Context

Testing the `veaf-mission-editor` plugin end-to-end, the bootstrap / `scaffold_mission` flow
**hung** — two `veaf-tools-updater.exe` at ~0 % CPU, nothing appearing in the folder. Two Explore
agents + inspecting the installed state established the real cause (not the `prepare` prompt the
test-session LLM blamed).

## Root cause

- `veaf-tools-updater` ends with `input(PAUSE_MESSAGE)` gated by `_is_double_clicked()`
  (`veaf-tools-updater.py:782,788`). That heuristic returns True whenever a real console is
  attached — a double-click, **or** the hook's detached `Start-Process -WindowStyle Hidden`
  (a hidden window is still a real console). Launched from the SessionStart hook, the updater
  reached `input()` and **blocked forever** (no key possible), keeping its exe locked so the
  deferred self-update (`apply-update.cmd`, single 2 s wait + one `ren`) failed and gave up.
- Aggravator: `scaffold._run` ran subprocesses with no `timeout` and no dedicated `stdin`, so any
  blocked child hung indefinitely and silently (output captured).
- Aggravator (operational, not code): two concurrent plugin installs (`-veaf` rc1 ✅ + `-inline`
  6.9.2) → two hooks → two updaters. The `-veaf` bootstrap worked and honoured
  `VEAF_MCP_UPDATER_TAG`; the mechanism is sound.

`prepare` is NOT the cause: `scaffold.py` passes `--force` and the overwrite prompt is TTY-guarded.

## Change

- `veaf_tools/helpers.py` — new `should_auto_pause()`: `False` when `VEAF_UPDATER_NO_PAUSE` is set,
  else delegates to `_is_double_clicked()`. Single testable decision point.
- `veaf-tools-updater.py` — `auto_pause` now uses `should_auto_pause()` (env-gated), so a
  programmatic caller never blocks on the exit pause. Interactive double-click unchanged.
- `veaf_mission_mcp/scaffold.py` — `_run` gains a `timeout` (updater 600 s, prepare 180 s) and
  passes `stdin=subprocess.DEVNULL`; a timeout surfaces as a clear `RuntimeError` naming the step.
  The updater is launched with `env` carrying `VEAF_UPDATER_NO_PAUSE=1`.
- `plugin/scripts/bootstrap.ps1` — exports `$env:VEAF_UPDATER_NO_PAUSE = "1"` before running the
  updater (both the synchronous first-launch and the detached refresh).
- Tests: `should_auto_pause` (env forces no-pause / delegates otherwise); `scaffold._run` closes
  stdin + bounds timeout, and the updater env carries `VEAF_UPDATER_NO_PAUSE`.

## Out of Scope

- The deferred self-update's single-attempt `ren` (no retry) — harmless once the pause hang is
  gone (the updater exits promptly); follow-up only if it proves flaky.
- Removing the concurrent `-inline` plugin install — operational, done on David's machine.
