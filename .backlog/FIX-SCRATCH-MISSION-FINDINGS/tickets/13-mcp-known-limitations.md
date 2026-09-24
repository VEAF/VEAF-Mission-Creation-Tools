# 13 — The MCP exposes the known limitations, always up to date

Status: ✅ done (#996)
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

## Widened 2026-09-24: DCS behaviours too

`docs/agents/dcs-runtime-traps.md` holds the DCS behaviours that raise no error and are wrong anyway
(the mission clock on the theatre's fixed offset, a late-activated group answering `isExist()`,
`start_time` not delaying an air spawn, a SAM with no EWR permanently lit…). It lives in the
repository only: neither the exe nor the plugin ships it, so an agent working without a checkout
never sees it (checked 2026-09-24: the MCP code only cites it in two docstrings).

David agreed to put them in the same place:

- The data file carries **two kinds** of entry, told apart by a field: a limitation of the tools
  (fixed one day, then no longer returned) and a behaviour of DCS (never "fixed", always returned).
  DCS entries keep what the page records: the measured value, the date, what it broke.
- `describe_known_limitations` returns both.
- The entries of `dcs-runtime-traps.md` that matter to someone authoring a mission move into the
  file; the page becomes a pointer to it, or is generated from it — one source, not two.
- The lot rule covers both: a surprising DCS behaviour, measured, goes into the file.

Done when also: a test checks a DCS entry is returned whatever the version, and the page no longer
carries a copy of what the file says.

## Done when

- The action is in the catalogue and in AI_ASSISTANT_CATALOG (FR/EN)
- A test loads the file and checks every entry has its fields, and one that a fixed entry is not
  returned
- The skill cites the action

## Outcome (PR 5)

- Decision (David, 2026-09-24): the YAML is the only source; the MCP reads it from the exe, the
  `.md` is a generated view for readers of the repository, never shipped.
- `veaf_libs/data/known-limitations.yaml`: 9 `dcs` entries moved from the page (the ones that
  concern building a mission), 1 `tool` entry (no parking data outside Caucasus / Persian Gulf /
  Syria). The four script-development traps (Skynet activation, `net.load_mission`, scenery deaths,
  deferred `Group:destroy`) stay hand-written at the end of the page.
- `veaf_libs/known_limitations.py`: load, validate (fields, kind, dcs needs `measured` and cannot be
  `fixed_in`, unique ids), filter by version (an unreadable version hides nothing), render the page
  block; `python -m veaf_libs.known_limitations` regenerates it. A test fails when the page drifts or
  repeats an entry outside the generated block.
- MCP action `describe_known_limitations(kind?)`, bundled in the exe (`_veaf_tools_extra_data`),
  documented in AI_ASSISTANT_CATALOG and mission-editing-mcp (FR/EN).
- Lot rule: CLAUDE.md §9 item 8.
