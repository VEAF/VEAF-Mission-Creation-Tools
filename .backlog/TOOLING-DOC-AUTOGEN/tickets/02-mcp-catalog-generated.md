# 02 — Generate the MCP catalogue reference from `list_catalog`

Status: ⬜ ready
Type: feat
Files: `veaf_build/` generator, mission-maker catalogue doc, `test/python/`

## Why it is worth more than ticket 01

It retires a standing trap. Today, adding an MCP action means **remembering** to update the
mission-maker catalogue doc by hand, and an action missing from that doc is invisible to the agent
that needs it — the catalogue is how discovery works. That obligation is currently carried by human
memory.

`list_catalog()` already returns every action's full spec (`veaf_mission_mcp/server.py`), so the doc is
derivable and the obligation can be deleted rather than restated.

## Behaviour

- Generate the catalogue page from `CATALOG.list_catalog()` — names, descriptions, parameters.
- **Do not import the whole MCP server** to do it if that pulls in a heavy dependency chain; read the
  catalogue definition directly if that is cleaner. The generator must be cheap enough to run in the
  freshness gate.
- Keep whatever hand-written framing the page has around the generated table — an intro explaining what
  the catalogue is for is prose and should survive. Generate the **table**, between clear begin/end
  markers, not the whole file.

## Tasks

- [ ] Generator implemented, emitting between markers so the surrounding prose survives.
- [ ] Diff reviewed against the current hand-maintained table; anything the doc says that the specs do
      not is either moved into the action's spec (a better description belongs next to the code) or kept
      as prose outside the markers — decided per case, not in bulk.
- [ ] Whatever documents the manual lockstep obligation is updated to say it is automatic now.
- [ ] Tests on the rendering.

## Acceptance criteria

- [ ] Regenerating produces no diff.
- [ ] Adding a throwaway action makes the gate fail until the doc is regenerated — proven, not assumed.
- [ ] `docs-check` clean; `ruff` / `mypy` / `pytest` green over the whole tree.
