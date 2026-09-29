# 03 — every first-level radio menu in capitals

Status: ✅ done

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

## Closed (2026-09-29)

- **Enumerated from the code:** 15 first-level menus (every `veafRadio.addMenu`, and every
  `addSubMenu` without a parent — Skynet's per coalition) plus 2 first-level commands (veafAssist's
  confirm / skip the step). **14 menus were already in capitals** in `veafI18n.lua`; only
  `Assistance` and the two commands were not.
- Applied once, in `RadioMenuBuilder:_buildSubtree`, to the display label of every child of the
  root — menus and commands, on every "Next page" of the root too (the 17 entries overflow the first
  page). The logical titles stay as written, since modules find their entries again by title.
- `veafRadio.toUpperCase` also upper-cases UTF-8 accented letters (à..þ, œ), which `string.upper`
  leaves alone ("Météo" would have become "MéTéO").
- Tests: `TestVeafRadioFirstLevelCapitals` renders the real first-level keys in French and English
  plus a lower-case module registered after them, and checks deeper levels are untouched.
- Docs: the pilot guide and README, the scripts index and the veafAssist page (FR+EN) quote the
  first-level names in capitals; the veafAssist page now shows the real labels of its two commands
  ("Valider cette étape" was not what the game shows).
- **Also fixed, at David's request:** the French pages quoted English labels — `ASSETS` for `MOYENS`,
  `CARRIER OPS` for `OPS PORTE-AVIONS`, and `veafAssets.md` claimed its commands were in English
  when they are translated (*Réapparition de*, *Infos sur*, *Retirer*). The pilot guide's diagram
  showed a first-level `Aide` / `Help` the code does not create (removed), and hung the carrier menu
  off F10 instead of VEAF. The carrier start command itself is hard-coded in English in
  `veafCarrierOperations.lua`, so the French index keeps quoting it that way.
