# FEAT-MCP-MISSION-EDITOR-010 — VMCT config edits (veaf-config.lua)

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/edit_veaf_config.py`, `test/python/`

## What to build

Semantic edits of a built mission's `l10n/DEFAULT/veaf-config.lua`, without a rebuild.
Each **replaces** the target line if present, else **inserts** it near the top (before the
modules initialise). Backed up first.

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (validated against the 5 levels).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <lua scalar>` (key must be a bare id).

## Acceptance criteria

- [x] Replace-if-present, insert-if-absent for each action.
- [x] `set_module_enabled` only touches the targeted module's line.
- [x] Scalars rendered as Lua literals (bool/int/float/string).
- [x] Clear error when the mission has no `veaf-config.lua`. TDD; ruff + mypy clean.

## Note

Security **password hashes** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — a
multi-line add/remove case — are **not** covered here; only the `SecurityDisabled` flag is.
Flagged to David at the wave-3 checkpoint for a follow-up if wanted.

## Blocked by

FEAT-MCP-MISSION-EDITOR-009 (the `rewrite_miz_members` brick).
