# 03 — every first-level radio menu in capitals

Status: ⬜ ready

David, 2026-09-29: put every first-level radio menu in capitals.

## To settle while doing it

- **Enumerate** the first-level entries from the code (every module that adds a menu under the VEAF
  root), not from a screenshot.
- Where the capitals are applied: once, where the first level is built in `veafRadio.lua`, rather
  than in each module's title. That is the only way a module added later follows the rule, and it
  leaves the French and English titles in `veafI18n.lua` as they are.
- The mission-maker docs quote menu names: every page that shows a first-level entry changes with
  it, in both languages.

## Done when

- A test builds the radio menu with the real modules and asserts that every first-level title is in
  capitals, including one registered after the others.
