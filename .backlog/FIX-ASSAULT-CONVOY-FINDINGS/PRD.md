# FIX-ASSAULT-CONVOY-FINDINGS — the red assault convoy flees an infantryman and never drives on; a captured zone draws a garrison anyway; convoys without armour

Status: 🔄 in-progress

## Found

David, 2026-10-08, *Kolkhida* mission 1 run with time acceleration (about ×20, measured from the campaign's 10 s beat logged every 0.5 s), a screenshot of the red convoy stopped north-east of Poti: "tu peux regarder pourquoi le convoi rouge fait ça ?", then "donc 3 soucis : le convoi rouge s'arrête et ne repartira jamais (il attend un `_gc resume`) ; le convoi rouge a peur d'un fantassin… ouh les lâches ; la prise de POTI a spawné toute une garnison". On the convoys' composition: "c'était effectivement déjà comme ça dans tous les tests", and "n'oublie pas ton point 4".

Measured in `dcs.log` and in the running mission (read-only, through the fiddle hook):

```text
16:02:03 CAMPAIGN sendConvoy: blue assault convoy [Kobuleti - Poti assault] left [Kobuleti] for [Poti], 6 unit(s)
16:02:03 CAMPAIGN sendConvoy: red assault convoy [Senaki - Poti assault] left [Senaki] for [Poti], 7 unit(s)
16:05:41 CAMPAIGN checkCapture: neutral zone [Poti] held by blue (Kobuleti - Poti assault - SPAAA Gepard #1)
16:05:47 CAMPAIGN drawGarrison: zone [Poti]: garrison drawn, 24 unit(s)
16:05:47 CAMPAIGN capturedBy: zone [Poti] captured by blue
16:05:54 GROUNDAI engage: convoy Bison: contact with 1 enemies
16:06:29 GROUNDAI standDown: convoy Bison: no contact for 60 s, holding
```

- The red convoy's one threat: `Poti garrison #8`, a `Soldier M4 GRG`, `strength=inf`, seen at **3164 m**; `ConvoyUnitHandler.ENGAGEMENT_RANGE = 3000`, `WATCH_BASE_RADIUS = 5000`, `FIGHT_RATIO = 1.5`. The convoy's armed group: ZSU-23-4 Shilka (1, AAA), VAB Mephisto (3, IFV), ZSU-57-2 (1, AAA) — strength 5. Its handler state: `5` (`STATE_HOLDING`).
- The blue convoy record, after the capture: `ended=nil`, its 6 units alive **0 to 90 m from Poti's centre** (zone radius 2000 m), `absorbed` empty; Poti owned by blue with one garrison group — the 24 units drawn from blue's reserve.
- The convoys: blue Gepard ×2, M48 Chaparral, M6 Linebacker, M978 HEMTT, Land Rover; red Shilka, ZSU-57-2, VAB Mephisto, Strela-10M3, Strela-1, ATZ-5 ×2. No tank on either side. The SAM vehicles have strength 0, so the first contact detaches them with the trucks.

## Causes

1. **Holding forever.** `ConvoyUnitHandler:standDown` (`veafGroundAI.lua`): a convoy that fell back holds and waits for an order (Q4 of FEAT-CONVOY-UNDER-FIRE, so as not to drive back into the same ambush). Nobody gives that order on a side without players nor game master — red, in a campaign.
2. **Fleeing an infantryman.** `ConvoyUnitHandler:recordThreat`: an enemy gets `strength = math.huge` unless it is a living ground unit within `ENGAGEMENT_RANGE` — the rule meant for "an aircraft, or a gun firing from beyond the range the convoy can answer at", applied to a unit merely **seen** by the wide watch. One rifleman at 3164 m made a group of strength 5 fall back.
3. **A garrison drawn although the convoy took the zone.** `VeafCampaignZone:capturedBy` → `veafCampaign.absorbConvoy` returned false, so `drawGarrison` paid 24 units from blue's reserve. Measured after the fact, the convoy meets every condition of `absorbConvoy` (same side, not ended, units well inside the radius), the capture itself counted its units, the log shows no Lua error, and `test_a_convoy_that_takes_the_zone_becomes_its_garrison` passes on the mocks. **Cause not found.**
4. **Assault convoys without armour.** `veafCampaign.sendConvoy` calls `veafSpawn.spawnConvoy` with `defense = size.defense`, `ASSAULT_TRUCKS` trucks and `armor = size.armor`; what comes out is air defence and trucks. Already so in every test run, per David.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-hold-then-drive-on.md) | A convoy holding with nobody of its side to order it drives on by itself | ✅ |
| [02](tickets/02-a-seen-unit-counts-for-its-strength.md) | A ground unit seen beyond engagement range counts for its own strength | ✅ |
| [03](tickets/03-capture-absorbs-the-convoy.md) | The convoy that takes a zone becomes its garrison — find why it did not | ⬜ |
| [04](tickets/04-assault-convoys-with-armour.md) | Assault convoys made of armour | ✅ |

## Related

- `FEAT-CONVOY-UNDER-FIRE` (#1099, #1101): the convoy watch, the fall back and Q4.
- `FEAT-OPPOSITION-SCALES-WITH-PLAYERS` ticket 04 (#1100): the assault convoys.
- `FEAT-CAMPAIGN-INTEL-DELAY` (#1106): the other side hears of a convoy later.
