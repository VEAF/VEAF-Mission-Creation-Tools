# FIX-CAMPAIGN-SECOND-SERVER-FLIGHT — what the second evening on the server taught

Status: 🧑 waiting-human

The persistent campaign "Bouclier de l'Oronte" (Northern Syria) flown on the Campagne server (`foothold2`) on 2026-11-17, 20:06–22:00 UTC, about ten players.
Everything below was measured in that evening's `dcs.log` (copied whole during the flight) or reported by the players through David; the minute-by-minute notes are kept in the session notes of that evening.
The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it for the whole lot (`dynamic-campaign-integration-branch`).

## The evening in figures

- Blue took **Menagh** (20:42, an AH-64D landed) and **Afrin** (21:07, an OH-58D landed): 6 → 8 zones; red kept 10.
- 51 red units destroyed, 4 blue losses (the AWACS to friendly fire, three aircraft to Strela).
- Players' credits 500 → 1915. Red's stock 1000 → about 250: it could no longer pay a raid at 21:57.
- No VEAF script error all evening; every `ERROR` came from DCS itself (radio speech, sound, `EDCORE`, the invisible FARP model).

## What went wrong

Red ruined itself more than the players ruined it — about 880 points of aircraft that never took off at Taftanaz — and the players' strikes did not hold, because the supply network revived the garrisons every few minutes.
One ticket per defect; the decisions already taken are in [`FEAT-DYNAMIC-CAMPAIGN`](../FEAT-DYNAMIC-CAMPAIGN/PRD.md) (the depot's buildings, decided 2026-11-17).

| # | Ticket | Weight |
|---|---|---|
| 01 | [Red aircraft never take off from Taftanaz](tickets/01-no-take-off-from-taftanaz.md) | ruins red's stock |
| 02 | [A depot is a set of buildings to destroy](tickets/02-depot-buildings.md) | decided by David |
| 03 | [A delivery brings back what it paid, not a whole group](tickets/03-delivery-restores-what-it-paid.md) | the strikes do not hold |
| 04 | [AI helicopters never reach Afrin, and red repeats what fails](tickets/04-helicopters-to-afrin-and-repeated-failures.md) | 4 of 4 tonight, 2 of 2 on 11-16 |
| 05 | [Assault convoys never arrive, and turn back under fire](tickets/05-assault-convoys-never-arrive.md) | 4 of 4 tonight |
| 06 | [A zone waking up freezes the server](tickets/06-wake-freeze.md) | felt by every player |
| 07 | [Garrison units on roofs](tickets/07-garrison-on-buildings.md) | seen at Aleppo |
| 08 | [The garrison of a helicopter capture is not a token one](tickets/08-helicopter-capture-garrison.md) | 14 and 24 units |
| 09 | [Log lines that say the wrong thing](tickets/09-misleading-log-lines.md) | misleads the debrief |
| 10 | [What each pilot earns is not recorded](tickets/10-credits-per-pilot.md) | asked by David |
| 11 | [The Campaign menu's admin commands sort last](tickets/11-admin-commands-sort-last.md) | the #1293 fix was inert |
| 12 | [The air defence of a zone is too light](tickets/12-air-defence-levels.md) | asked by David |
| 13 | [The theatre dossier's PDF legend is black](tickets/13-pdf-legend-colours.md) | cosmetic |

## Open questions (not tickets)

- **The AWACS once destroyed** comes back free from F10 → VEAF → MOYENS, at its Mission Editor orbit, and `veafSupport` places it again (first real use of #1293's respawn detection: to check). Should a persistent campaign charge for it, or bring it back on its own after a delay? Reco: free and manual as today until an evening shows it abused.
- **FARP zone kind**: still "To decide" in `FEAT-DYNAMIC-CAMPAIGN`.
- **A sitac like Foothold's** (David, 2026-11-17): a situation picture of the campaign; its own lot once the support is chosen (F10 marks, web page, Discord image).

## Out of scope

The friendly fire on the AWACS (a player's identification, nothing in the tools), and the `Corrupt damage model` lines on the AH-64D and the Su-25 (DCS, at a unit's birth).
