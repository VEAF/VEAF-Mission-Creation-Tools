# 03 — A delivery brings back what it paid, not a whole group

Status: ✅ done
Type: fix

## Found

"Les groupes reviennent très très vite" at Aleppo, where a player's helicopter was engaging the garrison.
Saraqib delivered Aleppo every 5 minutes (`there in 300 s`: orders 20:55:41, 21:05:11, 21:10:21, …; reinforcements 21:00:41, 21:10:11, 21:15:21, …), and a supply helicopter added its own.
`VeafCampaignZone:reinforce` brings back **every dead unit of the first damaged group** (`alive = true` for all, then `spawnGroup`), whatever the delivery is worth: 2 points brought back a Shilka and the lorries at Saraqib. A garrison drawn as one large group is whole again after each delivery.

## Measured in Tacview (2026-11-18)

Each reinforcement **destroys and recreates the whole group**, alive units included: at Saraqib the 18 units of the garrison were all removed and spawned again at every delivery (21:25:54, 21:27:54, 21:32:54, 21:34:54, 21:38:24 in Paluche's recording) to replace one or two dead ones (a Shilka, then a Shilka and a lorry, then two ZSU-57, a BTR and a BMP, a ZSU-57). Aleppo: 150 objects over six spawns of its garrison. Beyond the gameplay, it costs a full group spawn every few minutes on the server; a delivery should add the units it brings back, not respawn the group.


## Decisions — recos, to apply unless David says otherwise

- **a.** A delivery brings back units up to the points it carries, priced as the reserve prices them (`veafCampaign.unitPrice` / the category prices), cheapest first or in the group's order; what it cannot pay stays dead. Reco: yes — it is what makes a strike last.
- **b.** No reinforcement of a zone within N minutes of a loss there (it is under fire). Reco: yes, 10 minutes, a setting; the ordered delivery waits instead of being lost.
- **c.** Longer hops (`hop_seconds`) or a slower supply beat. Reco: not alone — a whole group would still come back, only later; revisit after a and b are flown.

## Done when

Tests show a 2-point delivery bringing back at most 2 points of units, and no reinforcement of a zone that lost a unit within the delay; the next evening's check (a destroyed Shilka stays destroyed while the zone is attacked) is written.

## Done

- `VeafCampaignZone:reinforce(points)`: a delivery brings back dead units of the first damaged group **cheapest first, up to the points it paid** at the order (reco a); a unit killed since the order stays dead. What it does not spend goes back to the side's stock.
- The units brought back spawn as **a group of their own** (`<group> +N`), under their recorded unit names: the living units are no longer destroyed and spawned again. These groups leave with the zone's sleep and before a full respawn of its garrison.
  An air defence unit brought back respawns its whole group instead (review of #1310: a radar alone in a group of its own leaves its launchers blind), and a group whose cheapest dead unit costs more than the delivery leaves the points to the next damaged group.
- `network.under_fire_seconds` (600 s, reco b): a zone that lost a unit less than that ago is not reinforced; the delivery waits (logged once) instead of being lost.
- Reco c (longer hops) not applied, as written: to revisit after an evening with a and b.
- The players' own crates, troops and helicopters still bring the whole first damaged group back at once (unchanged, no price attached).
- Tests: a 2-point delivery brings back the 2-point unit only, cheapest first; the spawned group holds only the units brought back; a delivery waits while the zone is under fire; the reinforcement groups leave at the zone's sleep.

## In-game check

At a red zone under attack (a depot or Aleppo): a destroyed Shilka stays destroyed while the zone is attacked; `dcs.log` shows `the red supply for [X] waits: the zone lost a unit N s ago, under fire`, then 10 minutes after the last loss `group [X garrison] reinforced, n of m dead unit(s) back, p point(s)`.
In Tacview, the living units of the garrison are **not** removed and recreated at a delivery; a new group `X garrison +1` appears with the units brought back.
To measure: DCS accepts a new unit under the name of a dead one (expected: the dead unit is no longer a `Unit`).
