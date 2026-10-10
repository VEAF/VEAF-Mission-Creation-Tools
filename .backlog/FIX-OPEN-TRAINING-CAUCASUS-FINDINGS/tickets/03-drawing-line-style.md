# 03 — add_map_drawing takes a line style

Status: ⬜ ready

Files: `veaf_mission_mcp/map_drawings.py`, `veaf_mission_mcp/actions.py` (schema and description), the authoring skill if it lists the shapes, tests.

## What happened

`map_drawings.py` writes `"style": "solid"` on every line and polygon (lines 375, 428, 474, 526, 574 on `develop` 364b26ff), and the action has no parameter for it.
The Caucasus OT v6 arena is a dashed circle on the briefing map; on the F10 map it had to be a solid one, which reads like any other zone.

DCS's own list, in `MissionEditor/data/NewMap/images/draw/lines.lua`: `solid`, `solid2`, `dot`, `dot2`, `dotdash`, `dash`, `cross`, `square`, `strongpoint`, `triangle`, `wirefence`, `boundry1` to `boundry5`.
Unknown, to measure before writing the code: whether a mission stores anything beyond `style` for a non-solid line. The editor also sets `mapData.file` to the style's texture when one is picked (`me_draw_panel.lua:489`); save a dashed circle from the editor and read the `drawings` table to know.

## Done when

- `add_map_drawing` takes `style`, one of DCS's sixteen, `solid` by default; anything else is refused with the list.
- It applies to `line`, `rect`, `circle`, `oval` and `free`; a `textbox` refuses it.
- A dashed circle built by the action loads in the editor and shows dashed on the F10 map in game.
- Tests: default, a valid style, an unknown style refused, a textbox refused.
