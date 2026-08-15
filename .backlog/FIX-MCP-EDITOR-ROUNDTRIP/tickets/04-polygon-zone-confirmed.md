# 04 — The 6-vertex zone survives the editor: say so, and stop hedging

Status: ✅ done 2026-08-15 — warning reworded to a measured limitation; no refusal above four
Type: docs
Files: `src/python/veaf-tools/veaf_mission_mcp/zone_editing.py` (the warning text), the mission-maker
action catalogue (both languages), tests

## The open question, now closed

`edit_zone` has shipped this warning since `FEAT-MCP-MUTATION-ACTIONS` ticket 06:

> 6 vertices: the VEAF runtime handles any polygon (mist.getUnitsInPolygon), but the DCS Mission
> Editor only draws 4-point quad zones — open the mission in the editor and save it once to confirm it
> keeps the shape

`DCS-SESSION-TODO.md` item 2 spelled out the stake: *"If it flattens it, the action should refuse
above four rather than warn."*

**It does not flatten it.** `czCrossKobuleti-1` was reshaped into a hexagon, opened in the editor and
saved on 2026-08-15; all six vertices came back unchanged, and so did `type: 2`. So the editor has no
UI for drawing a non-quad zone but preserves one it is given.

## What to change

- The action keeps writing any polygon, and **must not** start refusing above four.
- The warning stops asking for a confirmation that has been done. It should still say something —
  a maker who opens the zone in the editor cannot *edit* its shape there — but as a known limitation
  rather than an unknown risk.
- The catalogue says the same, in both languages.

## Careful

What is measured is that the editor **preserves the vertices through a save**. Not measured: what the
editor's UI shows for such a zone, nor whether dragging it in the editor rewrites the shape. Say what
was tested; a maker who drags the zone is outside it.

## TDD

- The warning text asserted, so the next reword keeps the meaning (a test already pins the vertex
  count warning — update it rather than adding a second).

## Acceptance criteria

- [ ] The warning states a measured limitation instead of asking for a round-trip.
- [ ] No refusal is introduced above four vertices.
- [ ] Catalogue updated in both languages; full Python gate green.
