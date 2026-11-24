# 01 — "Next page" always in F10

Status: ✅ done
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

## Done

Reproduced in `test/lua/test_veafRadio.lua` (`TestVeafRadioNextPageLast`), with a `missionCommands` mock that keeps the F10 menu as DCS shows it: one tree, each entry seen by everyone, a coalition or a group, and a menu's entries in the order they were created. A shop of 13 entries for everyone plus an escort for the caller's own group, rendered at mission start, then a pilot joins: his menu read `item01 … item08, Next page, Escort` — the symptom David saw.

**The cause.** Pagination is decided on the logical menu, but DCS orders a menu's entries by creation. An entry created on a page after that page's "Next page" link shows below it. Two ways it happens:

- A per-group entry rendered when its pilot joins, on a page whose link was rendered before (for everyone, a coalition, or another group). Per-group entries are: `USAGE_ForGroup` / `USAGE_ForUnit` commands, a secured command while security is on, a menu reserved to some groups (`addSubMenuForGroups`) or split per pilot (`addSubMenuPerPilot`).
- An entry recreated in place because its callback parameters changed (the incremental render removes and re-adds it).

**The menus concerned**, read from the code: any paginated menu with such an entry on a page that is not the last. On the campaign: Campagne (My earnings, split per pilot), the shop (the escort, `USAGE_ForGroup`) and the warehouse commands when the menu runs long; elsewhere Spawn (My spawns), and any paginated menu with secured commands. Not walked in a running campaign: the mock reproduces the mechanism, the flight check confirms the menus.

**The fix** (`veafRadio.lua`): `_render` records the DCS menus under which it created an entry; before rendering a page's "Next page", `_renewNextPageIfOvertaken` removes the link and the pages under it (children first, every id parked) when something was created on that page, and the link is rendered again after the page's entries. A page where nothing was created keeps its link and the pages after it untouched (tested), so the id-recycling rule holds: only what changes is touched. The cost: when a pilot joins, the pages after a page that gained his entries are recreated; a pilot reading one of those pages at that moment clicks a parked id, which does nothing.

Assumed, not measured: DCS orders entries of different audiences (everyone, coalition, group) by creation in a group's view. The flight check confirms it.
