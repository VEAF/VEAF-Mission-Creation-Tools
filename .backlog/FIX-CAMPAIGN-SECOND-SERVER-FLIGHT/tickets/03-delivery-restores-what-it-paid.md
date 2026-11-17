# 03 — A delivery brings back what it paid, not a whole group

Status: ⬜ ready
Type: fix

## Found

"Les groupes reviennent très très vite" at Aleppo, where a player's helicopter was engaging the garrison.
Saraqib delivered Aleppo every 5 minutes (`there in 300 s`: orders 20:55:41, 21:05:11, 21:10:21, …; reinforcements 21:00:41, 21:10:11, 21:15:21, …), and a supply helicopter added its own.
`VeafCampaignZone:reinforce` brings back **every dead unit of the first damaged group** (`alive = true` for all, then `spawnGroup`), whatever the delivery is worth: 2 points brought back a Shilka and the lorries at Saraqib. A garrison drawn as one large group is whole again after each delivery.

## Decisions — recos, to apply unless David says otherwise

- **a.** A delivery brings back units up to the points it carries, priced as the reserve prices them (`veafCampaign.unitPrice` / the category prices), cheapest first or in the group's order; what it cannot pay stays dead. Reco: yes — it is what makes a strike last.
- **b.** No reinforcement of a zone within N minutes of a loss there (it is under fire). Reco: yes, 10 minutes, a setting; the ordered delivery waits instead of being lost.
- **c.** Longer hops (`hop_seconds`) or a slower supply beat. Reco: not alone — a whole group would still come back, only later; revisit after a and b are flown.

## Done when

Tests show a 2-point delivery bringing back at most 2 points of units, and no reinforcement of a zone that lost a unit within the delay; the next evening's check (a destroyed Shilka stays destroyed while the zone is attacked) is written.
