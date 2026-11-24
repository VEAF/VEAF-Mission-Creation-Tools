# FIX-GO-VEAF-LOGS-UI — the Go veaf-logs window, brought level with the Python one

Status: ✅ done — 2026-10-24 (#1185) · archived 2026-11-24

Origin: David, 2026-10-24, on a capture of the Go viewer opening a 59-line `dcs.log`: the filters panel spread its three groups over the whole height, the *tout / contexte / rien* buttons a hundred pixels tall and each category floating in an empty band.
The defect has been on `develop` since J3 (#1181); a journal with many categories fills the panel and hides it.
Part of the Go rewrite (FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL), toolkit walk (ADR 0022); the Python viewer and the release pipeline are not touched.

## Method

Each change is checked on screen against the Python viewer, both opened on the same journals with `APPDATA` pointed at a scratch folder, by capturing the window alone (`PrintWindow` from a throwaway DPI-aware helper, never the desktop).
Measured before and after on a short journal (2 levels, 1 source, 1 noise family) and on `testdata/corpus/fuzz-1.log` (8 levels, 25 sources).

## Root cause of ticket 01

A walk `CustomWidget` — what `painted.go` draws the categories and the group buttons with — always reports a greedy layout item, in both directions.
A box layout ignores a maximum across its direction (an `HBox` gives every growable child its full height), and a composite holding a greedy child is greedy itself.
So each group was greedy and unbounded, and the three shared all the room the panel had; the `VSpacer` meant to take it comes after greedy widgets in walk's order and got nothing.

## Tickets

- [01 — The filters panel keeps its groups compact](FIX-GO-VEAF-LOGS-UI.md) · ✅
- [02 — The rest of the window against the Python](FIX-GO-VEAF-LOGS-UI.md) · ✅ a–f and h fixed, g and i left (David)

## Tickets, in full

## 01 — The filters panel keeps its groups compact

Status: ✅ done — 2026-10-24

### What

- Each group (*Niveaux*, *Sources*, *Bruit*) is pinned to the height of its title, its buttons and its rows, recomputed when its categories change (`stateGroup.fit`); the spacer under the groups takes the rest, at the bottom.
- As in the Python viewer, the title sits on its own line and the three buttons keep their width on the left (40, 64 and 40 px at 96 DPI) instead of spreading to the right of the title.
- The smoke mode checks the layout: a group laid out taller or shorter than its content makes `--smoke` exit with code 4. The Go CI runs it on `testdata/smoke/short.log`, a journal with few categories, where the defect shows.

### Measured

- Short journal: before, *Niveaux* 328 px high for 118 px of content; after, 118 px, the three groups stacked at the top.
- `fuzz-1.log`: unchanged look, the panel scrolls.
- The check fails both ways: 328 px for 118 with the J3 layout, 63 px for 118 with a group pinned to its header only; it passes on the fix and on `mixed.log`.

## 02 — The rest of the window against the Python

Status: ✅ done — 2026-10-24

Both viewers captured side by side on the same journals (2026-10-24, same screen at 120 DPI, 1600 × 1000 window): profile bar, search bar, chips, tabs, table, status bar, the *Enregistrer le profil*, *Police du journal* and *Journal distant* dialogs.
David chose to fix a–f and h, and to leave g and i (2026-10-24).

### Findings

| # | Where | Go before | Python | Done |
|---|---|---|---|---|
| a | Every push button and edit field, the chips, the dialogs' OK / Annuler | A bright white 1 px frame (Win32 dark theme) | Flat, a dark grey frame | ✅ `dark.FlatButton` paints push buttons flat (lighter under the mouse, blue frame with the keyboard), `dark.FlatEdit` frames one-line fields in grey (blue with the keyboard); `dark.Controls` applies both once per control. The drawn buttons (*tout / contexte / rien*, ≠, Aa, A−, A+, the panel's toggle) get the same frame. |
| b | The number fields | A wide box, the value right-aligned; the search's ± read `±0 (0)` at zero | A narrow spin box; `(0)` at zero (S5) | ✅ Value on the left, narrower (80, 72 and 72 px at 96 DPI); the search's ± shows `(N)` at zero while it does not have the keyboard (`dark.Overlay`, Qt's special value text). |
| c | Filters toggle of the profile bar | `☰ Filtres`, filled bright blue while the panel shows | `Panneau des filtres`, a plain button | ✅ Same label; darker, as a pressed button, while the panel shows. |
| d | Height of the bar buttons | 36 px for the push buttons, 30 for the drawn ones | 28 px | ✅ 28 px: the bars are capped to 22 px at 96 DPI, and their push buttons may shrink to it (`barButton`). |
| e | Width of the filters panel | About 340 px, the width of its content; `sideWidth` declared and never used | 320 at 96 DPI (about 410 px), kept when the window grows | ✅ The panel's content is given `sideWidth`: the scroll view stays `HorizontalFixed`, which in walk lays it out at its content's width and reserves its vertical scroll bar (letting it grow instead put the bar over the rows' right edge, measured). Same width at 1600 and 2400 px, and after Ctrl+B (measured). As before, the handle does not widen it. |
| f | Table with few rows | The column separators ran down to the bottom of the empty area | Separators only on the rows | ✅ `dark.EmptyArea` paints the list view under its last row. |
| g | Table header | Titles on the left | Titles centred | Left as is (David). |
| h | *Police du journal* | The current font out of view when the dialog opened | Qt's font dialog | ✅ The list scrolls to it again once laid out. |
| i | Groups of the filters panel | No frame | A group box frame | Left as is (David). |

Not differences: "1 lignes affichées" and a file given on the command line opening a second tab when the session already reopened it behave the same in both viewers; the *Analyse* menu comes with J5 (#1183).
