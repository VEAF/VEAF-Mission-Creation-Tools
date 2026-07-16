# FEAT-MCP-MISSION-EDITOR-012 — Comment-preserving `mission.yaml` editor (brick)

Status: ⬜ ready
Type: feat
Files: `pyproject.toml`, `mission_tools/mission_yaml_editor.py`, `test/python/`

## What to build

The reusable primitive every wave-4 VMCT action goes through: load and save the **source**
`mission.yaml` **without losing comments, key order or formatting**.

The rest of the codebase loads `mission.yaml` with PyYAML `yaml.safe_load`, which discards
all comments on a round-trip. `mission.yaml` is a heavily-commented source file edited by
hand (and the shipped default is kept in lockstep with generated output), so a lossy
round-trip is unacceptable. Use **`ruamel.yaml` in round-trip mode** instead.

- Add the `ruamel.yaml` dependency to `pyproject.toml` (and lock).
- New module `mission_tools/mission_yaml_editor.py`:
  - `load_yaml(path: Path) -> CommentedMap` — round-trip load.
  - `save_yaml(path: Path, data: CommentedMap) -> None` — round-trip dump, backed up first.
  - A `backup_before_write`-style timestamped backup of the `.yaml` (reuse the wave-1
    helper's scheme if it generalizes, else a sibling of it).

## Acceptance criteria

- [ ] A `load_yaml` → `save_yaml` round-trip with no mutation leaves the file **byte-stable**
      (comments, blank lines, key order, indentation all preserved).
- [ ] Editing a single scalar value changes only that value's rendering, not unrelated lines.
- [ ] The `.yaml` is backed up (timestamped sibling) before every save.
- [ ] TDD; ruff + mypy clean. Coverage gate bumped per the ratchet policy.

## Note

Per the CLAUDE.md quality ratchet: this adds a new dependency — keep it a **required** dep
(not an optional extra) since the MCP server always needs it. New module ships fully typed;
do not add it to the mypy `ignore_errors` list.

## Blocked by

None (foundation for tickets 13-14).
