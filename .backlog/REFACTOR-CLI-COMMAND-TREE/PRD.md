# REFACTOR-CLI-COMMAND-TREE — 25 commands, filed by subject instead of by verb

Status: ✅ done — 2026-08-10

Asked for by David on 2026-08-09: *"j'aimerais qu'on fasse une passe pour ranger les commandes
dans un arbre, par thème ; ça serait plus pratique pour le TUI, et aussi (dans une moindre mesure)
pour le CLI"*.

## What is already there, and why it is not enough

The TUI **already** groups its 21 commands — `build`, `extraction`, `config`, `assistance`. So the
question is not whether a tree is needed but whether this one works. Measured:

| Group | Commands | What is wrong |
|-------|---------:|---------------|
| `build` | 5 | holds the four `inject-*` |
| `extraction` | 4 | holds the matching `extract-*` |
| `config` | **10** | a catch-all: starting, converting, configuring — **and** `about` / `ask` |
| `assistance` | 3 | coherent (checklists + cockpit) |

Four concrete defects:

1. **`config` swallows half the menu** (10 of 21) and mixes four unrelated subjects. `ask`, the
   documentation chatbot, is filed as configuration. A group holding half the options narrows
   nothing, which is the whole job of a group.
2. **The split is by verb, not by subject.** `inject-waypoints` is under *build*, `extract-waypoints`
   under *extraction*: the two halves of one job live in different menus, so finding "waypoints"
   requires first knowing which direction you are going.
3. **`export` sits beside `extract`** though one writes a readable document and the other unpacks
   the archive — near-identical names, opposite intents.
4. **`validate` is under `config`** though it is the pre-build check; its natural neighbour is
   `build`.

The CLI has no tree at all: `veaf-tools --help` prints 25 flat entries.

## The tree

```
mission    prepare · validate · build · extract · export
convert    convert-v5 · convert-other · migrate-config · generate-config
content    extract-waypoints · inject-waypoints
           inject-presets
           inject-weather
           extract-aircraft-groups · inject-aircraft-groups
cockpit    resolve-checklist · verify-checklist · explore-cockpit
dcs        inject-bridge · capture-map · smoke-test
(root)     about · ask · user-config · mcp
```

All 25 are placed. The axis becomes the **subject**; `extract`/`inject` pairs end up adjacent; the
catch-all splits into two groups that mean something — `convert` is *getting a mission up to v6*,
and `dcs` is *this needs DCS running*, which is a constraint you must know **before** choosing, not
a theme.

A two-level `content` (`veaf-tools waypoints extract`) was considered and dropped: it reads well but
puts `presets` and `weather` in groups of one, and costs a third level of depth.

## Decisions taken (David, 2026-08-09)

- **a. The CLI carries the tree too**, not just the TUI. A tidy wizard beside a flat `--help` is two
  mental models for one tool, and `--help` stopped being readable at 25 entries.
- **b. Nothing breaks: hidden aliases.** Every command stays registered at the root with
  `hidden=True` (verified available in Typer 0.24.1). `veaf-tools build` keeps working for every
  existing script; `--help` shows only the tree. The aliases can be dropped at a v7.
- **c. Its own lot**, not a graft onto another: it touches `app.py`, the 22 files under `commands/`,
  `tui.py`, the TUI-completeness guard, and 40 documentation pages.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [One source of truth for the tree, and a guard against drift](tickets/01-tree-source-of-truth.md) | ✅ |
| 02 | [The CLI grows the tree, and breaks nothing](tickets/02-cli-subcommands.md) | ✅ |
| 03 | [The wizard follows the same tree](tickets/03-tui-groups.md) | ✅ |
| 04 | [Forty pages still name the flat commands](tickets/04-documentation.md) | ✅ |

Ticket 01 first: both 02 and 03 read from what it defines, and writing the map twice is how the
wizard and the CLI would drift apart again.

## What this lot will not do

- **Rename any command.** `extract` vs `extract-waypoints` is confusing (defect 3) and the tree
  separates them by group without touching either name. Renaming is a second, breaking decision.
- **Add or remove a command.** Placement only.
- **Drop the flat names.** They become hidden, not gone — that is decision (b).
