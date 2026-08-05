# Lot FEAT-MCP-ADD-GROUP-FOLDER — make `add_group` write durably to the mission folder

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `feat/mcp-add-group-folder-aware` → PR → `feature/mcp-mission-editor`

## Context

Real-usage feedback (David watching the plugin author a Syria mission): to place a **permanent**
SAM (a `#veafInterpreter["-samLR"]` carrier unit), the assistant needed `add_group` — but
`add_group` **only accepted a `.miz`** (`read_miz`/`write_miz`), while `scaffold --theatre` lays
down an **exploded** source (`src/mission/`, no `.miz`). So the only place it could write was the
**built** `.miz` (transient, lost on the next rebuild). The assistant correctly diagnosed this and
fell back to the built world, flagging it as non-durable.

The durable-write machinery already existed: the group-insertion **core** is factored out
(`insert_group_into_content`, no I/O) and the composite builders (`create_combat_zone`,
`create_qra`) apply it to `src/mission/` via `load_folder_mission`/`save_folder_mission`. Only a
**generic** "add an arbitrary group to the source" entry point was missing.

## Change

- `veaf_mission_mcp/add_group.py` — `add_group` is now **polymorphic** on its first arg (renamed
  `miz_path` → `target`): a **folder** → `load_folder_mission`/`save_folder_mission` (durable
  `src/mission/`); a **`.miz`** → `read_miz`/`write_miz` (transient, unchanged). Name validation
  drops the geometric combat-zone-trap check in folder mode (no single `.miz` to scan — like the
  composites); the result gains `durable: bool`.
- `actions.py` — the `add_group` action param `miz_path` → `target` with a description covering
  both worlds; the action description tells the LLM to target the folder for standing content (e.g.
  a permanent SAM). Only `add_group` changed; `describe_mission`/`add_trigger_zone`/
  `replace_in_mission_files` stay `.miz`-only (out of scope).
- `SKILL.md` — a `#veafInterpreter`/`#command` note now says to place either **durably** via
  `add_group` targeting the mission folder.
- Tests: `add_group` writes durably into `src/mission/` (`durable: true`); a `.miz` write reports
  `durable: false`.

## Out of Scope

- Making the other `.miz`-only actions folder-aware (only `add_group` was needed for the permanent
  SAM use case).
