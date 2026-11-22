# 02 — A garrison's SAM in a group of its own

Status: ⬜ ready
Type: feature

## To do

- First, failing tests (Lua): a composed garrison whose air defence template holds a SAM made of separate radars and launchers (today only `generateAirDefenseGroup-BLUE-5`, the Hawk: sr, cwar, tr, pcp, ln) puts those units in a group of their own, named so the briefings, the wake order and `[CAMPAIGN AIRDEF]` can tell it (e.g. `Hatay SAM`); the self-contained vehicles (Gepard, Avenger, Stinger, Chaparral, Roland ADS, Tor, Tunguska, Strela, Osa…) stay in the main group.
- Decide which types count as "a SAM of separate pieces" from data, not a hand list if one exists (Skynet's own database of SAM types, `veafSkynet.iadsSamUnitsTypes`, or `dcsUnits` attributes); say which in the ticket.
- **Saves already on the server**: at load, a garrison group holding such a SAM is split the same way (the save keeps each unit's type, position, heading and alive flag). `veafCampaign.unitIndex`, the kill payment, the garrison price and `[CAMPAIGN AIRDEF]` still find every unit; the split is written back at the next save. Hatay's Hawk and any other blue level-5 zone work without a redraw.
- Keep the wake rule "a group is never split" (`veafCampaign.lua` around line 1100): the new SAM group wakes whole, like the batteries.
- Tests: compose with and without such a SAM; a loaded save split, its units indexed and paid as before; a save already split left alone; the price unchanged.
- Docs: CHANGELOG entry; the campaign page if it describes a garrison's groups.

## Done when

No multi-unit SAM shares a group with a garrison's short-range weapons, in a fresh garrison or a loaded save; with tests.

## In-game check

On the Campagne server: `Hatay SAM` (or the chosen name) listed as its own group, and Hatay's main group still firing its Gepard and Avenger.
