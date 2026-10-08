# FEAT-OPPOSITION-SCALES-WITH-PLAYERS — the opposition sized to the number of players

Status: ⬜ ready

David, 2026-10-08, before flying *Kolkhida* mission 1 with 5 to 7 players: "tu penses que l'opposition est bien réglée ? ça serait pas mal d'avoir un truc un peu dynamique pour ça, en fonction du nombre de personnes (soit en générant la mission, soit au lancement via un menu ou une commande, soit automatiquement en fonction du nombre d'avions en l'air). je crois que Foothold fait un truc comme ça".

Checked the same evening:

- **Foothold does**: its `Director` (`zoneCommander.lua`, `_currentPackageMaximum(playerCount)`, `maxPackagePerPlayers`) raises the number of attack packages it launches with the players connected.
- **VEAF's QRA already half does**: `groups_by_enemy_count` picks the groups to scramble from the number of enemy aircraft in its zone when it triggers. *Kolkhida* mission 1 used it (1–2 blue aircraft: 2 MiG-29A; 3–4: + 2 Su-27; 5+: + 2 MiG-29S) — and that is how three defects were found, none of which a mission maker can see.

## The defects found on the way, measured

| # | Defect | Measured, 2026-10-08 |
|---|---|---|
| 1 | **`random_pick` draws WITH replacement** (`veafReactiveZone.pickGroups` calls `veaf.randomlyChooseFrom` n times): "2 of [MiG-29, Su-27]" can send the MiG-29 pair twice — that is, once. `mission.yaml` has no form that deploys every group of a tier: `groups_by_enemy_count` always goes through `setRandomGroupsToDeployByEnemyQuantity`. | Under the test mocks, the yaml-generated QRA sent the MiG-29 pair alone at every tier: 200 draws out of 200 short of the tier. |
| 2 | **The tier chosen is the last that fits in `pairs()` order, not the biggest** (`VeafQRACore:chooseGroupsToDeploy`, its variable is even named `biggestNumberLowerThanUnitsInZone`). | Lua 5.1: tiers inserted 1, 3, 5 iterate 1, 3, 5 (right by luck); inserted 5, 1, 3 they iterate 1, 5, 3 — 6 enemies would get tier 3. |
| 3 | **No `mission.yaml` key for `setNoNeedToLeaveZoneBeforeRearming`**: by default a dead QRA rearms only once its zone is clear of enemies — with several players over the target, almost never. | Read in `veafQraCore.lua` (the rearm branch); no key in `QRA_DEFINITION_KEYS`. |

*Kolkhida* mission 1 works around all three in its `mission-script.lua` (fixed tier lists set in ascending order, rearm with the zone occupied), checked offline: every tier sends exactly its groups, 200 out of 200.

## What the lot does

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-qra-tiers-right.md) | The QRA's tiers: the biggest that fits, every group when asked, rearm while occupied | ⬜ |
| [02](tickets/02-opposition-level.md) | An opposition level, set at generation, changed in flight, or followed automatically | ⬜ |
| [03](tickets/03-campaign-and-claude.md) | Campaigns and Claude size the opposition, and the briefing says it | ⬜ |

## Decided before writing

- **What scales is the air opposition** (QRA tiers, on-demand CAP), not the campaign's ground garrisons: those are the campaign's books — reserves, losses, repairs — and sizing them to tonight's attendance would make the campaign's state depend on who came.
- **Measured, not supposed**: every number the scaling uses (players connected, aircraft airborne, aircraft in a zone) is counted from DCS at the moment, the way the QRA counts its zone.
