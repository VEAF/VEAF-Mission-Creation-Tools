# Lot REFACTOR-CLI-COMMAND-TREE — 25 commands, filed by subject instead of by verb

Status: ✅ done — 2026-08-10

Asked for by David on 2026-08-09: *"j'aimerais qu'on fasse une passe pour ranger les commandes dans un
arbre, par thème ; ça serait plus pratique pour le TUI, et aussi (dans une moindre mesure) pour le CLI"*.

| # | Ticket | Status |
|---|--------|--------|
| 01 | One source of truth for the tree, and a guard against drift | ✅ |
| 02 | The CLI grows the tree, and breaks nothing | ✅ |
| 03 | The wizard follows the same tree | ✅ |
| 04 | Forty pages still name the flat commands | ✅ |

## The question was not "is a tree needed" but "does this one work"

The TUI **already** grouped its 21 commands. So the lot began by measuring that grouping, and the answer
was no:

| Group | Commands | What was wrong |
|-------|---------:|---------------|
| `build` | 5 | held the four `inject-*` |
| `extraction` | 4 | held the matching `extract-*` |
| `config` | **10** | starting, converting, configuring — **and** `about` / `ask` |
| `assistance` | 3 | coherent |

Four concrete defects: `config` swallowed **half the menu**, with the documentation chatbot filed as
configuration; the split was **by verb, not by subject**, so `inject-waypoints` and `extract-waypoints`
— the two halves of one job — sat in different menus and you had to know which direction you were going
before you could find either; `export` sat beside `extract` though one writes a readable document and
the other unpacks the archive; and `validate`, the pre-build check, was under `config` rather than next
to `build`.

The CLI had **no tree at all**.

## What shipped

Five groups instead of four, the largest down to **6 of 21**, `extract`/`inject` pairs adjacent, and
**nothing breaks**: every flat name stays registered with `hidden=True`, so `veaf-tools build` keeps
working while `--help` shows only the tree.

## Two findings on the way

- **The CLI↔TUI bridge really did break on the grouped form**, exactly as ticket 02 predicted it might.
- **The new `docs-check` coverage rule first passed while extracting *zero* command names** — anchored
  on `$` without MULTILINE. Once fixed it reported **16 of 30** commands missing from the guide's table.
  A rule that passes by matching nothing is worse than no rule.
