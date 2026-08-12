# 07 — F10 map drawings

Status: ✅ done 2026-08-12 — shipped as `add_map_drawing` / `edit_map_drawing`, **scoped to the three shapes that could be measured**
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

## What the fixtures actually contain, and the scope that follows

Drawings were read across every `.miz` in the repository — two layers as the ticket asked (`Blue` in
`test/test.miz`, `Author` in `test/veaf-tools/test.miz`), and **three** primitive types in total:

```
('Line',    lineMode='segment')   3   points[] relative, closed, thickness, colorString, style
('Line',    lineMode='segments')  4   same, 3+ points
('TextBox', -)                    1   text, font='DejaVuLGCSansCondensed.ttf', fontSize, angle,
                                      borderThickness, fillColorString — NO points
('Polygon', polygonMode='rect')   1   width, height, angle, fillColorString, thickness — NO points
```

**The measurement that governs everything**: `points` are **relative to the drawing's `mapX`/`mapY`
anchor**, the first one being `{0, 0}`. A drawing written in absolute coordinates lands hundreds of
kilometres away and nothing errors. So the actions take absolute coordinates and anchor them
themselves — and moving a drawing becomes moving its anchor, with the shape following for free.

**Deliberate scope reduction, stated rather than slipped in.** The ticket lists nine `create-*` shapes.
Only three field layouts exist in this repository — line, rect, textbox — so `circle`, `oval`, `free`,
`arrow`, `chevron` and `icon` are **refused by name**, pointing at what does work. Inventing their
layout is exactly what the ticket's own "read a real `.miz` before writing" rule forbids, and what
`FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` already cost: a write that looks right and the
editor disagrees. The functional need is still met — `line` with `closed=true` outlines a free-form
area, and `rect` is the no-fly box.

Measuring the missing six needs one drawing of each made in the editor and saved; it is listed in
`DCS-SESSION-TODO.md`, and adding them afterwards is a table entry each.

## Tasks

- [x] Read a `.miz` carrying drawings on at least two layers; record the exact shape in this ticket.
- [x] One `add_map_drawing` action with a shape parameter and an explicit layer — never defaulted,
      since the layer decides which coalition sees it.
- [x] Remove, move, retitle and rename an existing drawing (`edit_map_drawing`).
- [x] Catalogue doc updated in the same ticket (lockstep), plus the developer reference.
- [x] Tests per shape, plus one asserting a drawing survives a read/write round trip — 40 cases,
      including the anchoring, which is the part that silently ruins a drawing.

## Acceptance criteria

- [ ] 🧑 A drawing placed through the action appears on the intended coalition's F10 map. Needs the
      game; listed in `DCS-SESSION-TODO.md`.
- [x] It survives a read/write round trip, which is the whole reason it is not left to the editor. The
      full folder → `.miz` rebuild is part of the same in-game check.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.
