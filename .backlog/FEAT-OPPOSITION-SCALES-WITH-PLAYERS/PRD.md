# FEAT-OPPOSITION-SCALES-WITH-PLAYERS — the opposition sized to the number of players

Status: 🔄 in-progress — ticket 05 (count the players on CAP) after Kolkhida mission 1; tickets 01–04 merged (#1100), R46 checks them in game

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
| [01](tickets/01-qra-tiers-right.md) | The QRA's tiers: the biggest that fits, every group when asked, rearm while occupied | ✅ |
| [02](tickets/02-opposition-level.md) | An opposition level, set at generation, changed in flight, or followed automatically | ✅ on the mocks, R46 in game |
| [03](tickets/03-campaign-and-claude.md) | Campaigns and Claude size the opposition, and the briefing says it | ✅ |
| [04](tickets/04-assault-convoys.md) | Assault convoys: the campaign attacks and counter-attacks in flight | ✅ on the mocks, R46 in game |
| [05](tickets/05-count-the-cap.md) | Count the players flying CAP, and set the level in one click | 🔄 |

## Decided before writing

- **What scales is the air opposition** (QRA tiers, on-demand CAP), not the campaign's ground garrisons: those are the campaign's books — reserves, losses, repairs — and sizing them to tonight's attendance would make the campaign's state depend on who came.
- **Measured, not supposed**: every number the scaling uses (players connected, aircraft airborne, aircraft in a zone) is counted from DCS at the moment, the way the QRA counts its zone.

## Decided with David, 2026-10-08

- **The level is a number of player aircraft**, in the unit of a QRA's `enemy_count`; a QRA following it takes the tier of max(level, intruders in its zone). The trigger stays on the zone.
- **Hysteresis**: re-read every 60 s, a rise taken at once, a drop once the lower count has held `lower_after` (300 s).
- **Combat missions**: an "Auto scale" entry per skill, scale = ⌈level / 2⌉ within the scales offered — one enemy group per two players, an estimate of mine, not sourced.
- **Campaigns**: `players: 5-7` or `--players 6` write `opposition: {level: <most expected>, follow: players}` — sized for the squadron, followed down to who came.
- **Assault convoys** (ticket 04): a neutral zone is the target of each side bordering it, the convoy leaving after a delay the opposition level shortens; the convoy that takes a zone becomes its garrison; survivors still on the road at the end go back to the reserve; blue both by rule and from the radio menu.
