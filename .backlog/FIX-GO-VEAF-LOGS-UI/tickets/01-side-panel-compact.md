# 01 — The filters panel keeps its groups compact

Status: ✅ done — 2026-10-24

## What

- Each group (*Niveaux*, *Sources*, *Bruit*) is pinned to the height of its title, its buttons and its rows, recomputed when its categories change (`stateGroup.fit`); the spacer under the groups takes the rest, at the bottom.
- As in the Python viewer, the title sits on its own line and the three buttons keep their width on the left (40, 64 and 40 px at 96 DPI) instead of spreading to the right of the title.
- The smoke mode checks the layout: a group laid out taller or shorter than its content makes `--smoke` exit with code 4. The Go CI runs it on `testdata/smoke/short.log`, a journal with few categories, where the defect shows.

## Measured

- Short journal: before, *Niveaux* 328 px high for 118 px of content; after, 118 px, the three groups stacked at the top.
- `fuzz-1.log`: unchanged look, the panel scrolls.
- The check fails both ways: 328 px for 118 with the J3 layout, 63 px for 118 with a group pinned to its header only; it passes on the fix and on `mixed.log`.
