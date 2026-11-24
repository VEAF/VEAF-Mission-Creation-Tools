# 08 — One air defence group per garrison, up to level 5

Status: 🧑 waiting-human — implemented; waits for the redraw of the Oronte red garrisons (live server, server empty, David's go), then the in-game check
Type: fix

## Found

Since FIX-CAMPAIGN-SECOND-SERVER-FLIGHT ticket 12, an airfield has defence level 5, and `veafCampaign.composeGarrison` drew `size.defense > 3 and 2 or 1` air defence groups.
Aleppo got two `generateAirDefenseGroup-RED-5` groups: the `[CAMPAIGN AIRDEF]` line at 21:24 UTC on 2026-11-19 lists 32 air defence units and 121 missiles, reach 12 km — Tor x2, Osa x4, Tunguska x4, Strela-10 x4, Igla x6, plus guns.
David, 2026-11-19: far too much. Decided (option b): keep level 5, so the airfields keep Tor, Osa and Tunguska, but a single group.
Added on David's decision, relayed by the controlling session on 2026-11-19.

## To do

A garrison draws one air defence group up to defence level 5, two only above (no size class goes above 5 today). No setting: the rule is the level, as in `generateCasGroup`.

## Implemented (2026-11-19)

`composeGarrison` draws `size.defense > 5 and 2 or 1` groups. Test: `TestVeafCampaignCompose` in `test_veafCampaign.lua` (a level-5 garrison draws exactly one group). Docs (`CAMPAIGN.md`, `.en.md`) and CHANGELOG updated.

## To check

1. **The Oronte red garrisons must be redrawn at the next redeploy**: a garrison already recorded in the save keeps its two groups until it is drawn again. The redraw is a server operation of the controlling session, not of this lot.
2. In game, after the redraw: `[CAMPAIGN AIRDEF]` for Aleppo lists about half the units and missiles of 2026-11-19 (one group of level 5).
