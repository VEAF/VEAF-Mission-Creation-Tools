# 03 — Kneeboard: priority highlight, colour, grey headers

Status: ✅ done
Depends on: 01

## Scope

Render the new channel attributes and drop the coloured radio headers:

- **priority**: right-aligned `Pn` marker in the Name cell + orange background on
  the Name & Freq cells.
- **color**: fill the CH cell background with the resolved colour
  (`ImageColor.getrgb`, unknown → `WARNING` + uncoloured); channel-number text
  auto-contrasted (white/black) by background luminance.
- **grey headers**: replace the red/green/orange `radio_colors` radio title bars
  with grey (matching the existing column-header row).

## Acceptance

- A `priority: 3` channel shows `P3` + orange Name/Freq cells.
- A `color: "#000080"` channel shows a navy CH cell with white number text.
- A `color: green` channel shows a green CH cell.
- All radio title bars render grey; no red/green/orange remains.

## Tests

- `test_presets_image*`: presence of `Pn`, orange cells, CH-cell colour,
  contrast branch, grey header colour.
