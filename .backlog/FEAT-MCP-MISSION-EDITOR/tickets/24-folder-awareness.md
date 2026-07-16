# FEAT-MCP-MISSION-EDITOR-024 — Mission-folder awareness (extract/build round-trip)

Status: ⬜ ready
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

## Design decision to settle (flag at implementation)

Two viable models for "edit the `.miz` side of a folder":
1. **Edit `src/mission/` directly** (the exploded mission), then `build`.
2. **Build → edit the `.miz` (editor-parity) → extract back** (the `mission_promoter` round-trip).

Prefer (1) if the exploded `src/mission/mission` is straightforward to mutate with the existing
`read_miz`/`write_miz`-style helpers; else (2) reusing `promote_mission_to_v6`. Confirm with David
before committing the composite builders to one model.

## Acceptance criteria

- [ ] `mission_folder` resolves `mission.yaml` + the exploded mission for a given folder path.
- [ ] A build (folder → `.miz`) can be triggered programmatically, reusing the existing worker.
- [ ] The editor-parity primitives can target the folder's mission (chosen model), backed up first.
- [ ] TDD; ruff + mypy clean.

## Blocked by

None (reuses `mission_builder`/`mission_extractor`/`mission_promoter`).
