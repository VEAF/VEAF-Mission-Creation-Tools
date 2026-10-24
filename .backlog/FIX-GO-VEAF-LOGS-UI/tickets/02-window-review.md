# 02 — The rest of the window against the Python

Status: ✅ done — 2026-10-24

Both viewers captured side by side on the same journals (2026-10-24, same screen at 120 DPI, 1600 × 1000 window): profile bar, search bar, chips, tabs, table, status bar, the *Enregistrer le profil*, *Police du journal* and *Journal distant* dialogs.
David chose to fix a–f and h, and to leave g and i (2026-10-24).

## Findings

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
