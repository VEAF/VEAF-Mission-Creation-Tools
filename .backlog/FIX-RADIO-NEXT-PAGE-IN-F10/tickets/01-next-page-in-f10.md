# 01 — "Next page" always in F10

Status: ⬜ ready
Type: fix

## Read

David, 2026-11-22: several radio menus show "Page suivante" in F9, and another entry in F10. `veafRadio` paginates at render time (`MENU_PAGE_SIZE = 10`, a full page = 9 entries + "Next page", `veafRadio.lua` lines 36, 971, 1036-1041), so "Next page" should always be the tenth. Which menus are concerned is not known.

## To do

- First, reproduce: build the campaign mission (or a test mission with the same modules), and list every radio menu with more than 9 entries for a blue pilot, with each entry's position (the bridge, or a test walking the rendered tree). Write which menus show the defect and which entry lands after "Next page".
- Find why: an entry added after the page was laid out (a later `addCommand` to a menu already rendered), an entry added straight with `missionCommands` outside `veafRadio`, or a capacity off by one. Fix that cause, with a failing test first.
- The rule that comes out: "Next page" is the last entry of a page, F10, whatever adds to the menu and when.
- Docs: CHANGELOG entry.

## Done when

No radio menu has an entry after "Next page"; with tests.

## Flight check

On the Campagne server: the long menus (Campagne, the shop, VEAF) show "Page suivante" in F10.
