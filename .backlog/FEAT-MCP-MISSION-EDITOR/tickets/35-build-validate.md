# FEAT-MCP-MISSION-EDITOR-035 — `validate_mission` + `build_mission` actions

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/build_tools.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_build_tools.py`

## What to build

Close the authoring loop so the MCP produces a playable `.miz` without leaving the assistant.

- **`validate_mission(folder_path)`** — call `veaf_libs.mission_validator.validate_mission_folder`
  **in-process**; return `{folder, ok, errors: [msg], warnings: [msg]}` (`ok` = no errors).
- **`build_mission(folder_path)`** — drive `veaf-tools build` via **subprocess** with `cwd=folder`
  (build orchestration lives in the CLI command). Resolve the folder's `veaf-tools[.exe]` (installed
  by `scaffold_mission`), else fall back to `veaf-tools` on PATH. Return `{folder, ok, message}`; a
  non-zero exit is surfaced as a clear `RuntimeError`.

Both registered in the catalog with schemas.

## Acceptance criteria

- [ ] `validate_mission` on a real folder fixture returns errors/warnings correctly (`ok` reflects errors).
- [ ] `build_mission` builds via `veaf-tools build` in the folder (subprocess mocked in tests: asserts
      command, `cwd`, binary resolution, and the non-zero-exit failure path).
- [ ] Both registered; `describe_action` returns their schemas.
- [ ] ruff + mypy clean (new module typed, no exclusion).
