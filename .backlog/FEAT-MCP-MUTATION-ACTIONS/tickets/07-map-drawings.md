# 07 — F10 map drawings

Status: ⬜ ready
Type: feat
Files: a new `veaf_mission_mcp/map_drawings.py`, `actions.py`, the catalogue doc, tests

## Why

The [triage](../PRD.md) keeps 13 of the 19 drawing verbs, because the sentence is real and recurring:

> *"Draw the FSCL and label the ingress corridor on the F10 map."*

Nothing in VMCT touches F10 drawings today. A briefing line, a corridor, a target ring, a no-fly box —
all of it is currently drawn by hand in the Mission Editor, and lost the moment a mission is
regenerated from its folder.

That last part is the argument for having it here rather than leaving it to the editor: **a drawing
placed by hand does not survive a rebuild**, while one an agent can place is part of the recipe.

## Behaviour

One action taking a **shape** parameter rather than nine `create-*` verbs — the triage rule is one action
per intent:

| Shape | Kept from |
|---|---|
| line, arrow, chevron | `drawing-create-line/arrow/chevron` |
| circle, oval, rect, polygon | `drawing-create-circle/oval/rect/polygon` |
| textbox, icon | `drawing-create-textbox/icon` |

Plus `drawing-remove`, `drawing-set-pos`, `drawing-set-text`, `drawing-set-name`.

Rejected as low value: `drawing-set-angle/color/fill-color/thickness` — styling, which a caller can pass
at creation. Add one later if a mission maker asks; never speculatively.

## Decide before implementing

- **Where do drawings live in the mission table?** `drawingLayers`, with per-coalition layers (Common,
  Red, Blue, Neutral, and the author layer). A drawing on the wrong layer is invisible to the pilots who
  need it and visible to the ones who should not see it — so the layer is a first-class parameter, not a
  default. Read a real `.miz` with drawings on several layers before writing.
- **Coordinates.** Drawings are positioned in mission-table `{x, y}` — read
  `docs/agents/dcs-coordinates.md` first, since a drawing at `y = altitude` lands a hundred kilometres
  away and nothing errors.
- **Does the editor prune what it does not recognise?** `FIX-MAPRESOURCE-KEY` and
  `FIX-COMMUNITY-SOUNDS-PRUNED` are both "the write looked right and the editor disagreed". Open the
  result in the real ME before calling this done.

## Tasks

- [ ] Read a `.miz` carrying drawings on at least two layers; record the exact shape in this ticket.
- [ ] One `add_map_drawing` action with a shape parameter and an explicit layer.
- [ ] Remove, move, retitle and rename an existing drawing.
- [ ] Catalogue doc updated in the same ticket (lockstep).
- [ ] Tests per shape, plus one asserting a drawing survives a folder → `.miz` rebuild.

## Acceptance criteria

- [ ] A drawing placed through the action appears on the intended coalition's F10 map.
- [ ] It survives a rebuild, which is the whole reason it is not left to the editor.
- [ ] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.
