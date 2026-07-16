# FEAT-MCP-MISSION-EDITOR-022 — Source-side config parity (`mission.yaml`)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/edit_mission_yaml.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

Every VEAF config setting that today can only be edited on the **built** `veaf-config.lua`
(wave 3) gets its **source** `mission.yaml` counterpart, so both targets are reachable. Uses the
comment-preserving `mission_yaml_editor` brick, backed up first.

Mapping (confirmed in `veaf_libs/lua_config_generator`):

- **`set_mission_log_level(level)`** → top-level `global_log_level: <level>` (↔ built `set_log_level`).
- **`set_mission_security(disabled, password_hashes?, password_mm_hashes?)`** → the `security:`
  block (↔ built `set_security_disabled` — and covers the password hashes the built side does not).
- **`set_mission_setting(key, value)`** → `settings.<key>` (↔ built `set_veaf_config`, which sets
  `veaf.config.<key>`).

Module enable already has both targets (`set_module_enabled` built, `set_mission_module` source),
so it is not re-done here.

## Design note

Shipped as **separate source-side actions** (naming consistent with the wave-4 `set_mission_module`),
not a `target:` parameter on the built-side actions — the wave-4 split already established the
one-action-per-target pattern, and a param would collide with it. Parity (David's point 1) is about
coverage, achieved either way.

## Acceptance criteria

- [x] Each setter edits the correct `mission.yaml` key/block, comments preserved, backed up first.
- [x] `set_mission_log_level` validates the level against the 5 levels.
- [x] `set_mission_security` sets `disabled` and, when given, the hash lists; leaves other keys intact.
- [x] `set_mission_setting` inserts/updates `settings.<key>` (creates `settings:` if absent).
- [x] All registered as actions; `run_action` dispatches them. TDD (5 tests); ruff + mypy clean.
- [x] Mission-maker catalogue updated (FR/EN) — "Modules & settings" now "Recipe + built".

## Blocked by

None (builds on the wave-4 `mission_yaml_editor` brick).
