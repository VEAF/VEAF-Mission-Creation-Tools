# 03 — F10 drawings from the map's data

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/` (the renderer of ticket 01, `map_drawings.py`), tests, AI catalogue doc

## Origin

Prompt §4.13 asks for the same overlays as F10 drawings, each on the layer of the side that must see
it. Caucasus-v6 generated 38 `add_map_drawing` calls from its map script's data
(`tools/gen_15_dessins.py`): front line on `Common`; sanctuary, blue race-tracks and zone labels on
`Blue`; red race-tracks on `Red`. GermanyCW-v6 placed 38 objects separately from its map.

## Measured

- `add_map_drawing` refuses a name already used on the layer (`map_drawings.py:144`), so the
  generator cannot be re-run after a change: it stops at the first drawing it wrote before, and
  updating the view means removing the 38 objects one by one with `edit_map_drawing` first.

## Done when

- One option of ticket 01's command (or a sibling action) writes the drawings from the same data the
  picture uses, so the map and the F10 view can never disagree.
- It replaces the drawings it wrote before (a name prefix or a dedicated layer tag), and leaves the
  maker's own drawings alone.
- Which overlay goes on which layer is a documented default, overridable in `mission.yaml`.
