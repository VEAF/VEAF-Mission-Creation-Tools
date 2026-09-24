# 13 — The MCP exposes the known limitations, always up to date

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/known-limitations.yaml` (new), `veaf_mission_mcp`
(new action + `actions.py` catalogue), `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`,
`plugin/skills/veaf-mission-authoring/SKILL.md`, `CLAUDE.md` (lot rule), tests

Asked by David on 2026-09-24, through the GermanyCW-v6 session.

## The need

The tools' traps must not live in prompts or skills, where they go stale. They belong **in the MCP,
always reachable, matching the installed version**. The "build an Open Training" mission prompt will
open with: "Read the known limitations (`describe_known_limitations`) and take them into account".

## What ships

- A read-only MCP action `describe_known_limitations` returning, for the running `veaf-tools`
  version, each known limitation: an id, the area (pipeline, MCP action, runtime), the observable
  symptom, the recommended workaround, and the version that fixed it when there is one. A fixed
  limitation is no longer returned.
- **One source**: a versioned data file in the repository (YAML, next to the other `veaf_libs/data/`
  files), read by the action, the doc and the skill — no list copied by hand into three places. It
  must ship in the executable (`_veaf_tools_extra_data`).
- A lot rule, in CLAUDE.md or the Definition of Done: a lot that finds a limitation without fixing it
  adds it to the file; a lot that fixes one marks it fixed.
- First content: whatever this lot leaves unfixed at delivery (ideally nothing), plus what is real and
  out of scope — e.g. no parking data outside Caucasus / Persian Gulf / Syria, so no runway or ramp
  start through the MCP there.
- The `veaf-mission-authoring` skill (ticket 11) points to the action instead of listing traps.

## Done when

- The action is in the catalogue and in AI_ASSISTANT_CATALOG (FR/EN)
- A test loads the file and checks every entry has its fields, and one that a fixed entry is not
  returned
- The skill cites the action
