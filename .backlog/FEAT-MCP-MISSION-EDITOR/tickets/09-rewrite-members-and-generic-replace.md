# FEAT-MCP-MISSION-EDITOR-009 — Brick + generic search-replace

Status: ✅ done
Type: feat
Files: `mission_tools/miz_tools.py`, `veaf_mission_mcp/`, `test/python/`

## What to build

- Brick in `miz_tools.py`: `rewrite_miz_members(miz_path, {arcname: bytes})` (copies the
  archive verbatim, swaps only named members — no Lua-table re-serialization), plus
  `list_members` / `read_member`.
- Action `replace_in_mission_files(search, replace, files="*.lua", regex=False)` — text or
  regex search-replace **restricted to `l10n/DEFAULT/**/*.lua`** (glob matched on the path
  relative to `l10n/DEFAULT/`; only `.lua` members ever eligible). Backed up first; returns
  `{files_changed, total_replacements}`.

## Acceptance criteria

- [x] Only `l10n/DEFAULT/**/*.lua` members are touched — never `mission`/`options`/binaries.
- [x] Untouched members stay byte-identical (no normalization).
- [x] Text and regex (with backrefs) modes; no-match = no change, no backup.
- [x] Invalid regex → clear error. TDD; ruff + mypy clean.
