# 03 — The wizard follows the same tree

Status: ⬜ ready
Type: refactor
Files: `src/python/veaf-tools/veaf_libs/tui.py`, translation files

## Tasks

- [ ] Replace the four `GROUP_*` constants with ticket 01's tree; headings and order come from there.
- [ ] Re-file the commands the audit moved: `validate` leaves `config` for `mission`; `export` leaves
      `extraction` for `mission`; every `extract-*` / `inject-*` pair meets in `content`;
      `about`, `ask` and `user-config` leave `config` for the root.
- [ ] The wizard shows five groups where it showed four, and the largest holds 6 entries instead of
      10 — that reduction **is** the deliverable, so assert it rather than eyeballing it.
- [ ] Translations for the new group labels and descriptions, French and English.

## Acceptance criteria

- [ ] No group holds more than a third of the commands.
- [ ] `extract-waypoints` and `inject-waypoints` are adjacent in the menu, and likewise for
      aircraft-groups — defect 2 in the PRD is what this lot exists for.
