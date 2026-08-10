# 03 — The wizard follows the same tree

Status: ✅ done — 2026-08-10
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

## Done

Five headings instead of four, the largest holding 6 of 21 instead of 10, and the `extract`/`inject`
pairs adjacent. Asserted, not eyeballed.

`dcs` is in the tree but never rendered by the wizard: all three of its commands are machine-only.
`test_no_group_is_left_empty` could no longer mean what it said, so it now asserts what gets
*rendered*, with a companion test that the group is **skipped** rather than shown empty — and that
one says out loud it should be revisited rather than deleted if a `dcs` command ever becomes
wizard-drivable.
