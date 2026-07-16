# FEAT-MCP-MISSION-EDITOR-029 — `scaffold_mission` (bootstrap an empty folder from GitHub)

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/scaffold.py`, `veaf_mission_mcp/actions.py`, `veaf_libs/platform_assets.py`, `test/python/veaf_mission_mcp/test_scaffold.py`

## What to build

A single MCP action that turns an **empty target folder** into a ready VEAF mission folder by
driving the **real VEAF binaries** (decision with David — not re-implementing the updater/prepare
logic in-process), faithful to a maker's own first-run experience.

Parameters:

- `target_folder` (required) — the folder to initialize.
- `template` (required) — `minimal` | `standard` | `full`. `custom` is rejected (its interactive
  TUI picker has no TTY under a subprocess). The template *question* is the calling LLM's job.
- `github_token` (optional) — relayed to the updater via `--token` (bypasses the API rate limit).
- `tag` (optional, default `published-latest`) — relayed to the updater via `--tag`.

Steps:

1. Resolve `target_folder` (create if missing). **Refuse a non-empty folder** with a clear error
   (never scaffold over an existing mission).
2. Resolve the updater asset name for the current OS (Windows: `veaf-tools-updater.exe`; Unix:
   `veaf-tools-updater-<os>-<arch>`), GET it from the **stable release-download URL**
   (`…/releases/download/<tag>/<asset>` — no GitHub API, no rate limit), write it into the folder,
   `chmod +x` on Unix.
3. `subprocess.run` the updater with `cwd=target_folder` (+ `--token`/`--tag` if given). Check the
   return code **and** that `veaf-tools[.exe]` and `published/` appeared.
4. `subprocess.run` `veaf-tools[.exe] prepare --template <template> --force` with `cwd=target_folder`.
   Check the return code.
5. Return a structured summary: `{folder, template, veaf_tools_version, files_installed}` + any
   warnings.

A small cross-OS helper in `platform_assets.py` returns the updater asset name **including Windows**
(`updater_asset_name()` currently returns `None` there — the mapping only covers Unix).

## Acceptance criteria

- [ ] `scaffold_mission` registered in the catalog; `describe_action` returns its schema.
- [ ] Empty folder → updater downloaded, updater run, `prepare` run — in that order, `cwd` = folder.
- [ ] Non-empty folder → refused with an explicit error, nothing downloaded/run.
- [ ] `template` outside `minimal`/`standard`/`full` → rejected before any download.
- [ ] A non-zero exit from the updater **or** from `prepare` surfaces as a clear error (not silent).
- [ ] TDD mocks the download + `subprocess.run` (asserts sequence, exe path, args, cwd, guards,
      failure paths); ruff + mypy clean (full-tree; `scaffold.py` typed from the start — no exclusion).

## Notes

- The action **downloads and executes binaries** — intended and faithful to the real workflow.
  Tests cover the orchestration only (mocked download + subprocess); the real end-to-end network
  run is a manual check by David in a real folder.
- On Windows the updater self-replaces via a deferred `.cmd` after it exits; that runs in the
  background and does not block the subsequent `prepare` (which uses the already-installed
  `veaf-tools.exe`).
