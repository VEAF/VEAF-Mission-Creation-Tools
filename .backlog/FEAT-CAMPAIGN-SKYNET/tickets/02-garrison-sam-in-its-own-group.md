# 02 — A garrison's SAM in a group of its own

Status: 🧑 waiting-human (in-game check)
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

## Done

- `VeafCampaignZone:separateSam()` moves a SAM's pieces from the main group `<zone> garrison` into `<zone> SAM`, appended to the garrison; called by `drawGarrison` (a fresh draw, at start or after a capture) and by `veafCampaign.initialize` for a garrison already recorded (a loaded save, or a data table's). Idempotent: a main group with no such SAM is left alone, and a save already split is not touched.
- **Choice: DCS's unit attributes (`dcsUnits.DcsUnitsDatabase[type].attribute`)**, not Skynet's database. `SkynetIADS.database` is loaded only when the module is on, and calls the Roland ADS a "complex" SAM although this ticket keeps it in the main group; the attributes are always loaded (`veafCampaign.reserveCategory` reads them already). The rule:
  - a group holds such a SAM when one of its units is a **launcher that needs another vehicle's radar** (`SAM LL` without `SAM TR`: Hawk ln, Kub ln, NASAMS ln, Patriot ln);
  - then its pieces move: those launchers, every **radar with no weapon** (`SAM SR` or `SAM TR` without `AA_missile` or `AA_flak`: Hawk sr, tr, cwar) and every **command post** (`SAM CC`: Hawk pcp);
  - the launcher condition is what keeps a lone acquisition radar where it is: the red groups' Dog Ear radar (levels 1 to 5) and BLUE-4's Roland Radar beside its Roland ADS are radars with no weapon, and pulling them out alone would have put an EWR under Skynet in every red zone, which the lot excludes. Measured on `veaf-units.yaml`: of the garrison air defence templates, only `generateAirDefenseGroup-BLUE-5` splits.
- Each unit record moves as it is (type, x, z, heading, alive, missiles): `unitIndex` is rebuilt at spawn from the new indices, a loss is recorded against the SAM group, the price (`garrisonPrice`, by type) is unchanged, `[CAMPAIGN AIRDEF]` walks every group, and the kill payment pays by the killed unit's type, not its group. The next save writes the split back (it writes `entry.garrison`).
- Wake order: `startSpawning` puts every group whose name ends in `SAM` last (the pattern was `-range SAM`), whole: "a group is never split" holds.
- Tests (`TestVeafCampaignSamGroup`): the attribute rule on the types concerned; a fresh BLUE-5-like garrison split and spawned as two DCS groups; a garrison with a Dog Ear or a Roland left in one group; a loaded save split with its dead, positions and headings, same price, units indexed under the new group; a loss in the SAM group; a save already split left alone; the SAM group waking after a group bought later (checked to fail with the old pattern).
