# 10 — Air defence costs more

Status: 🧑 waiting-human — implemented, the prices to tune after an evening
Type: fix

## Found

`veafCampaign.UNIT_PRICES` dates from 2026-11-16 and was never tuned on a server: `sam_short = 8`, `sam_long = 15`, `aaa = 4`, next to a tank at 6 and a SEAD sortie at 200.
For red, a lost Tor was worth about a BMP, and one SEAD sortie as much as 25 Tor.
David, 2026-11-19: "je veux effectivement qu'on augmente le prix des SAM". Added on his decision, relayed by the controlling session.

## Decided (an estimate, to tune after an evening)

`sam_short` 8 → 25, `sam_long` 15 → 40 (per unit), `aaa` 4 → 8.

## Implemented (2026-11-19)

The three values in `veafCampaign.UNIT_PRICES`. The same table prices the garrison draws, the reinforcements (ticket 09 and the network), the enemy's spawns paid from resources and the players' VEAF spawns paid in credits (`credits_per_point`): a `-sam` costs the players about three times as many credits.
Test: `test_a_unit_is_priced_by_what_it_is` (`test_veafCampaignV15.lua`) pins the new prices, a Tor included.

Nothing becomes unpayable at the start, measured on 200 draws of each default size class with the real generators (`composeGarrison`, defence 3 and 5, one air defence group since ticket 08):

| Garrison | old prices, mean / max | new prices, mean / max |
|---|---|---|
| outpost (size 1, defence 3, armour 1) | 73 / 115 | 128 / 214 |
| airfield (size 1, defence 5, armour 2) | 98 / 166 | 192 / 368 |

Mission 1's garrisons are drawn free; a captured zone's garrison is paid from 1,000 points at the start, and one the side cannot pay is replaced by a token garrison (`payGarrison`). A long-range SAM battery, drawn with a zone that has `long_range_sam`, is the dearest item (several elements at 40).

## To check

After an evening: the red stock in the `CAMPAIGN STATUS` lines, the SEAD sorties against the air defence lost, and how often a captured zone gets a token garrison.
