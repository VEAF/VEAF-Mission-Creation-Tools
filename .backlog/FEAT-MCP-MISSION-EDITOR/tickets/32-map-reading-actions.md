# FEAT-MCP-MISSION-EDITOR-032 — `describe_map` + `resolve_coordinates` actions

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/map_tools.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_map_tools.py`

## What to build

Two read/utility MCP actions giving the LLM map awareness design-time (no DCS running):

- **`describe_map`** (read): from the mission's `.miz`/folder, return the **theatre** name, the
  **bullseye(s)** (per coalition, from `mission.coalition.*.bullseye`), and the existing **trigger
  zones and groups** as reference points (reuse `describe_mission`). Lets the LLM orient itself and
  express positions relative to known anchors.
- **`resolve_coordinates`** (utility): convert a position between `{x,y}` and `{lat,lon}` for the
  mission's theatre, using the ticket-031 conversions. Reads the theatre from the mission so the
  caller never supplies projection parameters. (MGRS out of scope — see ticket 031.)

## Acceptance criteria

- [ ] `describe_map` returns theatre + bullseye(s) + reference zones/groups from a real fixture.
- [ ] `resolve_coordinates` round-trips `{x,y}` ↔ `{lat,lon}` for the fixture's theatre.
- [ ] Both registered in the catalog; `describe_action` returns their schemas.
- [ ] TDD against a real mission fixture; ruff + mypy clean (full-tree).

## Blocked by

FEAT-MCP-MISSION-EDITOR-031 (conversions).
