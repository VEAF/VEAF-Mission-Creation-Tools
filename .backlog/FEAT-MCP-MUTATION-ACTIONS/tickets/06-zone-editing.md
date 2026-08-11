# 06 — Zone editing, including polygons

Status: ⬜ ready
Type: feat
Files: `veaf_mission_mcp/add_trigger_zone.py` (or a sibling), `actions.py`, the catalogue doc, tests

## Why

`add_trigger_zone` creates a **circular** zone and nothing edits one afterwards. The
[triage](../PRD.md) keeps 6 of the 11 zone verbs, and the one that matters most is the one we cannot
express at all:

> *"Make that zone a polygon along the ridge, and have it follow the carrier."*

A VEAF combat zone is a trigger zone, so a zone that cannot be reshaped or moved is a combat zone that
has to be deleted and rebuilt to be adjusted.

## Behaviour

Kept verbs and their intent:

| Verb | The sentence |
|---|---|
| `zone-set-vertices` | *"Follow the ridge line rather than a circle"* — a quad/polygon zone |
| `zone-set-pos` | *"Move the combat zone 3 km north"* |
| `zone-set-radius` | *"Make the QRA trigger zone bigger"* |
| `zone-set-name` | *"Rename it to the VEAF convention"* |
| `zone-set-link` | *"Have the zone follow the carrier"* — a zone linked to a unit |
| `zone-remove` | *"Drop that zone"* |

Rejected as low value, and why: `zone-set-color` / `zone-set-hidden` are editor cosmetics — they change
how a zone looks to whoever opens the mission in the ME, not what it does in game.

## Decide before implementing

- **A quad zone is a different shape in the mission table**, not a circle with extra fields (`type`,
  `verticies` — note DCS's own spelling). Read a real polygon zone out of a `.miz` before writing
  anything, the way `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` read an upstream trigger rather than assuming its
  shape.
- **Does `veafCombatZone` support a polygon zone?** If the Lua side only handles circles, a polygon
  zone the MCP can create would be a zone the framework mishandles — worse than not offering it. Check
  the runtime before shipping the write.
- `zone-set-link` needs the linked unit to exist; decide what happens when it does not (refuse, or warn
  and leave unlinked).

## Tasks

- [ ] Read a real quad/polygon zone from a `.miz` and record its exact shape in this ticket.
- [ ] Confirm `veafCombatZone` handles a non-circular zone, or scope the action to what it handles.
- [ ] One `edit_zone` action covering the six kept verbs, backup-before-write like its siblings.
- [ ] Catalogue doc updated in the same ticket (lockstep).
- [ ] Tests: circle → polygon, move, resize, rename, link, remove; and the DCS Mission Editor opens the
      result — a golden-file assertion at minimum.

## Acceptance criteria

- [ ] A zone can be reshaped, moved, renamed, linked and removed without deleting and recreating it.
- [ ] A polygon zone the action creates is one `veafCombatZone` actually handles.
- [ ] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.
