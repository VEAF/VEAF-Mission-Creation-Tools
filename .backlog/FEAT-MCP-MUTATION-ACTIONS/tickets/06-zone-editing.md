# 06 — Zone editing, including polygons

Status: ✅ done 2026-08-12 — shipped as `edit_zone`; `veafCombatZone` **does** handle a polygon, measured in its source
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

## The two measurements this ticket demanded

**A polygon zone's exact shape**, read out of `test/veaf-tools/demo-mission/veaf-demo-mission.miz`
(`czBatumi`):

```
{ name = "czBatumi", type = 2, zoneId = 670,
  x = -356734.48, y = 617270.72, radius = 4572,
  verticies = { {x = -359753.86, y = 614918.84}, {x = -355602.86, y = 622688.92},
                {x = -352849.44, y = 617192.50}, {x = -358731.76, y = 614282.63} },
  color = {1, 1, 1, 0.15}, hidden = false, properties = {} }
```

Two things follow. The list is spelled **`verticies`** — DCS's own typo, kept verbatim, because
"correcting" it writes a field DCS ignores. And `x`, `y` and `radius` **stay present** on a polygon, so
a polygon is not a circle with extra fields and reshaping does not strip the rest.

**`veafCombatZone` does handle a polygon.** `veafCombatZone.lua:1506-1510` branches on the zone type:
`0` → `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. But there is **no
`else`**: a zone of any other type leaves `units` empty and the combat zone finds nobody, silently.
That is worse than not offering the shape, so the action writes only types 0 and 2 — the answer to the
ticket's "or scope the action to what it handles".

**David's call on the vertex count (2026-08-12)**: accept three or more, since "follow the ridge line"
is the actual use case and mist handles any polygon — but **warn** whenever the count is not four,
because the DCS editor only draws quads and whether it preserves more is an in-game question.

## Tasks

- [x] Read a real quad/polygon zone from a `.miz` and record its exact shape in this ticket (above).
- [x] Confirm `veafCombatZone` handles a non-circular zone — it does, for type 2 only, and the action
      is scoped to that.
- [x] One `edit_zone` action covering the six kept verbs, backup-before-write like its siblings.
- [x] Catalogue doc updated in the same ticket (lockstep), plus the developer reference.
- [x] Tests: circle → polygon, move, resize, rename, link, remove — 31 cases, each asserting what
      landed **in the written archive** rather than in memory.

## Two open questions, decided

- **`zone-set-link` when the unit does not exist**: *refused*, not warned. A zone linked to nothing
  never follows anything, in silence, and the mission maker would be left inspecting the zone instead
  of the link. DCS links by `unitId`, so the id is resolved from the name here.
- **Renaming**: refused on a **collision** (zones are referenced by name from `mission.yaml`), and it
  **warns that references do not follow** — the combat zone's own entry and its member groups' name
  prefix both need doing by hand. Nothing here can see those references.

## Acceptance criteria

- [x] A zone can be reshaped, moved, renamed, linked and removed without deleting and recreating it.
      Moving a polygon carries its vertices, or the shape would stay behind while the centre moved.
- [x] A polygon zone the action creates is one `veafCombatZone` actually handles (type 2, via mist).
- [ ] 🧑 One editor check that a **non-quad** polygon survives a save, since the ME has no UI for it.
      Listed in `DCS-SESSION-TODO.md`.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.
