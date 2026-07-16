# FEAT-MCP-MISSION-EDITOR-024 — Mission-folder awareness (extract/build round-trip)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/mission_folder.py`, `test/python/`

## What to build

The foundation for the composite builders: let the MCP operate on a **mission folder** (the
editable source: `mission.yaml` + `src/mission/` exploded `.miz`), not only a standalone built
`.miz`. A composite feature lives in **both worlds** (trigger zones/groups in `src/mission/`, the
module config in `mission.yaml`), so a one-pass builder must edit both and then realise it.

- A small `mission_folder` helper that resolves a folder's pieces: the `mission.yaml`, the
  exploded mission under `src/mission/`, and (re)builds a `.miz` from the folder via the existing
  CLI/worker (`veaf-tools build`, `MissionBuilderWorker`, `mission_promoter.promote_mission_to_v6`
  for the extract-back half).
- The wave-1/2 editor-parity primitives (`add_group`, `add_trigger_zone`) currently operate on a
  `.miz` zip; make them reusable against the folder's mission representation (edit `src/mission/`,
  or edit a built `.miz` then extract back — decide during implementation, see below).

## Design decision — settled (David, model 1)

Composites **edit the durable source**: the exploded `src/mission/` (zones/groups) + `mission.yaml`
(config). No build is triggered by the composite — a later `veaf-tools build` produces the `.miz`.
The exploded `mission` file is mutated with the existing pure-Python `luadata` parser via the new
`write_mission_folder` (sibling of the existing `read_mission_folder`) — no zip, no Lua execution.

## Acceptance criteria

- [x] `mission_folder` resolves both sides of a folder: `mission_yaml_path()` and the exploded
      mission (`load_folder_mission`).
- [x] `write_mission_folder` (in `mission_tools.miz_tools`) writes `mission_content` back to the
      loose `mission` file, leaving the rest of the folder intact.
- [x] `save_folder_mission` backs the `mission` file up first, then writes.
- [x] TDD (4 tests); ruff + mypy clean (full-tree, CI-exact). No auto-build (model 1).

## Blocked by

None (reuses `mission_builder`/`mission_extractor`/`mission_promoter`).
