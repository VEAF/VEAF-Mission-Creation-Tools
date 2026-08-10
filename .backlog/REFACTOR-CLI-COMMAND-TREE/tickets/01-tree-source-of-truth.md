# 01 — One source of truth for the tree, and a guard against drift

Status: ✅ done — 2026-08-10
Type: refactor
Files: `src/python/veaf-tools/veaf_tools/command_tree.py` (new), `test/python/…`

## Why this cannot live in `tui.py`

`CommandSpec.group` already exists and would be the obvious home — except that the four
machine-only commands (`mcp`, `capture-map`, `inject-bridge`, `smoke-test`) are deliberately absent
from `COMMANDS`, since the wizard cannot drive them. The CLI needs a group for all 25; the wizard
needs prompts for 21. Neither list is a superset of the other, so the tree has to sit above both.

## Tasks

- [ ] A new module holding the tree: group id → ordered command names, plus each group's label and
      one-line description (both translatable — the CLI help and the wizard headings show them).
- [ ] `tui.py` derives `CommandSpec.group` from it instead of declaring its own constants.
      `GROUP_ORDER` becomes the tree's order.
- [ ] **The guard**: a test asserting every command registered on the Typer app appears in the tree
      exactly once, and that the tree names no command that does not exist. The existing
      TUI-completeness test (`test_tui.py:83`, built on `MACHINE_ONLY_COMMANDS`) is the shape to
      copy — this is the same idea one level up.
- [ ] Keep `MACHINE_ONLY_COMMANDS` as it is: it answers "can the wizard drive this?", a different
      question from "where does it live in the tree", and merging them would lose one of the two.

## Acceptance criteria

- [ ] Adding a command without placing it in the tree fails a test, naming the command.
- [ ] The wizard and the CLI cannot disagree about a group, because neither owns the answer.

## Done

`veaf_tools/command_tree.py` holds the placement; `tui.py` derives `CommandSpec.group` from it as a
property, and the 21 hand-written `group=` arguments are gone, so neither side owns the answer.
`MACHINE_ONLY_COMMANDS` is untouched, as the ticket asked — it answers a different question.

The guard fails on a registered command that is not placed, on a tree entry that no longer exists,
and on a command placed twice.

**One thing the wizard needed that the CLI did not**: it has no root, so every entry needs a
heading. `ROOT_GROUP_ID` gives the root commands one while the CLI keeps them at the top level —
the same placement, expressed the way each interface can express it.
