# 03 — checklist image generator

**Status:** ⬜ ready — depends on 02.

Python side. For each activated checklist, render **one PNG per progress state** and embed them in the
`.miz` as resources the engine can display.

Pillow is already a dependency, and
[presets_manager.py](../../../src/python/veaf-tools/presets_injector/presets_manager.py) already draws
kneeboard images with fonts and colours — follow that pattern rather than inventing a second one.

## What gets rendered

For a checklist of N steps: **N+1 images**, state `k` showing the first `k` lines ticked, line `k+1`
marked as current, the rest pending. State `N` is the completed checklist.

Each line: a **drawn** box (rectangle, plus a tick made of two strokes) — *not* the characters `☐` and
`✓`. Arial does not guarantee those glyphs and a missing glyph renders as a blank or a tofu box. Same
reasoning for the current-step marker: draw it.

Resolve `title` and each `label` through the i18n layer at generation time, in the mission's language, so
the text baked into the image matches what the pilot's messages will say.

## Naming and embedding

One resource per state, named deterministically (`assist-<id>-<k>.png`), embedded through the same
resource-key path the build already uses for scripts — see
[FIX-MAPRESOURCE-KEY](../../FIX-MAPRESOURCE-KEY/PRD.md) for the trap that lot fixed: the key has to land
in the right table or the resource resolves to nothing, silently, and the failure only shows in game.

**Emit the resource names into the Lua data** so the engine displays state `k` without reconstructing a
filename by string concatenation.

## Cost control

Render only the checklists the mission activates (ticket 02 already restricts emission to those). Log the
count and total size of generated images at build time — a mission maker adding a sixty-step checklist
should see what it costs rather than discover a fatter `.miz`.

Flat text on a plain background: save as **indexed PNG** (`optimize=True`, a small palette), which is
what keeps a state around 10-20 KB rather than 100.

## Tests

`test/python/…/test_checklist_images.py`: N steps produce N+1 files; the tick count per state is right
(assert on the drawn geometry or on a small pixel sample, not on a full image comparison — a font
difference across machines would make a golden-image test flap); resource names are deterministic;
labels are resolved through i18n, not emitted as raw keys.

## Definition of done

- Generator + tests green, quality gate clean, coverage floor bumped.
- A generated image **looked at by a human** at the size it will appear in game. Legibility is the point
  of this ticket and no assertion covers it. Note the chosen alignment and size values — ticket 05 needs
  them, and `TheUniversalMission`'s `(1, 1, 25, 1)` is a starting point, not a validated setting.
