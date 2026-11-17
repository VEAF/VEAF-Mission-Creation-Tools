# 07 — Garrison units on roofs

Status: ⬜ ready
Type: fix

## Found

"Un véhicule sur un bâtiment à Alep" (a player, ~21:17 UTC).
`veafCampaign.placeGarrisonGroup` draws a point with `veaf.findPointInZone`, places the group with `veafCasMission.placeGroup`, and only checks the **concrete** (`isOnConcrete`): nothing against buildings or trees.
The repository's scenery-aware placement (`veafUnits.settleGroup`, FIX-PLACEMENT-IGNORES-SCENERY ticket 12, small `Disposition` queries 25 m apart — see `docs/agents/dcs-runtime-traps.md`) is not used for campaign garrisons.
Positions are recorded in the state: the same vehicle comes back on the same roof at every reinforcement and every wake.

## To do

- Campaign garrisons settle through `settleGroup` when they are **drawn** (not at each respawn: the recorded positions then stay clear).
- A test on the draw path; the in-game check on an urban zone (Aleppo) written.
- The garrisons already recorded in the Oronte save keep their roofs until redrawn: say so in the release note, and redraw them with ticket 12's procedure.

## Done when

A garrison drawn in a town has no unit inside a building's footprint in the next evening's check.
