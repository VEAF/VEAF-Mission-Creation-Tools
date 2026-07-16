# FEAT-MCP-MISSION-EDITOR-033 — Human-coordinate input on placement actions

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `add_trigger_zone.py`, `composites.py`, `veaf_mission_mcp/` (shared position parser), `test/python/`

## What to build

Let every placement action accept a `position` given in **lat/long** in addition to DCS `x/y`. A
shared helper normalizes a position dict to `{x, y}` before insertion, using the mission's theatre
(via ticket 031):

- `{x, y}` — unchanged (backward compatible; the default).
- `{lat, lon}` — decimal degrees.

Applies to `add_group`, `add_trigger_zone`, and the wave-8 composites (`create_combat_zone`,
`create_qra`, `create_cap_mission`) — anywhere a `position` is taken today. Routes/waypoints accept
the same forms. (MGRS out of scope — see ticket 031.)

## Acceptance criteria

- [ ] Each accepted form (`x/y`, `lat/lon`) places a group/zone at the same spot on the
      fixture theatre (verified by re-reading and comparing x/y within tolerance).
- [ ] Existing `{x,y}` callers are unaffected (regression tests still pass unchanged).
- [ ] Ambiguous/partial position (e.g. `lat` without `lon`) → clear error.
- [ ] TDD per form + theatre-mismatch handling; ruff + mypy clean (full-tree). Any worker touched
      here that still sits under the mypy `ignore_errors` list is dropped from it (quality ratchet).

## Blocked by

FEAT-MCP-MISSION-EDITOR-031 (conversions).
